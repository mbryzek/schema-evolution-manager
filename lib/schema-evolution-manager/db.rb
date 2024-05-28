module SchemaEvolutionManager

  class Db

    attr_reader :url

    def initialize(url)
      @url = Preconditions.check_not_blank(url, "url cannot be blank")
    end

    # Installs schema_evolution_manager. Automatically upgrades schema_evolution_manager.
    def bootstrap!
      scripts = Scripts.new(self, Scripts::BOOTSTRAP_SCRIPTS)
      dir = File.join(Library.base_dir, "scripts")
      scripts.each_pending(dir) do |filename, path|
        psql_file(path)
        scripts.record_as_run!(filename)
      end
    end

    # executes a simple sql command.
    def psql_command(sql_command)
      Preconditions.assert_class(sql_command, String)
      command = "psql --no-align --tuples-only --command \"%s\" %s" % [sql_command, @url]
      Library.system_or_error(command)
    end

    def Db.attribute_values(path)
      Preconditions.assert_class(path, String)

      options = []

      ['quiet', 'no-align', 'tuples-only'].each do |v|
        options << "--#{v}"
      end

      SchemaEvolutionManager::MigrationFile.new(path).attribute_values.map do |value|
        if value.attribute.name == "transaction"
          if value.value == "single"
            options << "--single-transaction"
          elsif value.value == "none"
            # No-op
          else
            raise "File[%s] - attribute[%s] unsupported value[%s]" % [path, value.attribute.name, value.value]
          end
        else
          raise "File[%s] - unsupported attribute named[%s]" % [path, value.attribute.name]
        end
      end

      options
    end

    # executes sql commands from a file in a single transaction
    def psql_file(path)
      Preconditions.assert_class(path, String)
      Preconditions.check_state(File.exist?(path), "File[%s] not found" % path)

      options = Db.attribute_values(path).join(" ")

      Library.with_temp_file(:prefix => File.basename(path)) do |tmp|
        File.open(tmp, "w") do |out|
          out << "\\set ON_ERROR_STOP true\n\n"
          out << IO.read(path)
        end

        command = "psql --file \"%s\" #{options} %s" % [tmp, @url]
        Library.system_or_error(command)
      end
    end

    # True if the specific schema exists; false otherwise
    def schema_schema_evolution_manager_exists?
      sql = "select count(*) from pg_namespace where nspname='%s'" % Db.schema_name
      psql_command(sql).to_i > 0
    end

    # Parses command line arguments returning an instance of
    # Db. Exists if invalid config.
    def Db.parse_command_line_config(arg_string)
      Preconditions.assert_class(arg_string, String)
      args = Args.new(arg_string, :optional => ['url', 'host', 'user', 'name'])
      Db.from_args(args)
    end

    def Db.from_args(args)
      Preconditions.assert_class(args, Args)
      if args.url
        Db.new(args.url)
      else
        base = "%s:%s/%s" % [args.host || "localhost", 5432, args.name]
        url = args.user ? "%s@%s" % [args.user, base] : base
        Db.new("postgres://" + url)
      end
    end

    # Returns the name of the schema_evolution_manager schema
    def Db.schema_name
      "schema_evolution_manager"
    end

  end

end
