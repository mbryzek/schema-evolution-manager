module SchemaEvolutionManager

  class Db

    attr_reader :url, :psql_executable_with_options

    def initialize(url, opts={})
      @url = Preconditions.check_not_blank(url, "url cannot be blank")
      password = opts.delete(:password)

      @psql_executable_with_options = "psql"
      (opts.delete(:set) || []).each do |arg|
        @psql_executable_with_options << " --set #{arg}"
      end

      Preconditions.assert_empty_opts(opts)
      connection_data = ConnectionData.parse_url(@url)

      if password
        ENV['PGPASSFILE'] = Db.password_to_tempfile(connection_data.pgpass(password))
      end
    end

    # Installs schema_evolution_manager. Automatically upgrades schema_evolution_manager.
    def bootstrap!
      scripts = Scripts.new(self, Scripts::BOOTSTRAP_SCRIPTS)
      dir = File.join(Library.base_dir, "scripts")
      scripts.each_pending(dir) do |filename, path|
        psql_file(filename, path)
        scripts.record_as_run!(filename)
      end
    end

    # executes a simple sql command.
    def psql_command(sql_command)
      Preconditions.assert_class(sql_command, String)
      command = "#{@psql_executable_with_options} --no-align --tuples-only --no-psqlrc --command \"%s\" %s" % [sql_command, @url]
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
    def psql_file(filename, path)
      Preconditions.assert_class(path, String)
      Preconditions.check_state(File.exist?(path), "File[%s] not found" % path)

      options = Db.attribute_values(path).join(" ")

      Library.with_temp_file(:prefix => File.basename(path)) do |tmp|
        File.open(tmp, "w") do |out|
          out << "\\set ON_ERROR_STOP true\n\n"
          out << IO.read(path)
        end

        command = "#{@psql_executable_with_options} --file \"%s\" #{options} %s" % [tmp, @url]

        Library.with_temp_file do |output|
          result = `#{command} > #{output} 2>&1`.strip
          status = $?
          if status.to_i > 0
            errors = File.exist?(output) ? IO.read(output) : result
            raise ScriptError.new(self, filename, path, errors)
          end
        end
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
      args = Args.new(arg_string, :optional => ['url', 'host', 'user', 'name', 'port', 'set'])
      Db.from_args(args)
    end

    # @param password: Optional password to use when connecting to the database.
    def Db.from_args(args, opts={})
      Preconditions.assert_class(args, Args)
      password = opts.delete(:password)
      Preconditions.assert_empty_opts(opts)

      options = { :password => password, :set => args.set }
      if args.url
        Db.new(args.url, options)
      else
        base = "%s:%s/%s" % [args.host || "localhost", args.port || ConnectionData::DEFAULT_PORT, args.name]
        url = args.user ? "%s@%s" % [args.user, base] : base
        Db.new("postgres://" + url, options)
      end
    end

    # Returns the name of the schema_evolution_manager schema
    def Db.schema_name
      "schema_evolution_manager"
    end

    def Db.password_to_tempfile(contents)
      file = Tempfile.new("sem-db")
      file.write(contents)
      file.rewind
      file.path
    end

    # Returns a sanitized version of the URL with the password removed
    # to prevent passwords from being logged or displayed in error messages
    def sanitized_url
      # Parse the URL to extract components
      if @url.include?("://")
        protocol, rest = @url.split("://", 2)
        lead, name = rest.split("/", 2)
        
        # Check if there's a username:password@ pattern
        if lead.include?("@")
          # Take the last element as host_part to handle passwords with @ symbols
          host_part = lead.split("@").last
          # Take everything before the last @ as user_part
          user_part = lead.split("@")[0..-2].join("@")
          
          if user_part.include?(":")
            # Remove password, keep only username (everything before the first colon)
            username = user_part.split(":", 2)[0]
            sanitized_lead = "#{username}@#{host_part}"
          else
            sanitized_lead = lead
          end
          "#{protocol}://#{sanitized_lead}/#{name}"
        else
          @url
        end
      else
        @url
      end
    end

  end

end
