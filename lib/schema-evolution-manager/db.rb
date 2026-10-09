module SchemaEvolutionManager

  class Db

    # psql_args: the psql executable and its global options, as an argv
    attr_reader :url, :psql_args

    # Options every psql invocation carries. --no-psqlrc keeps the applying
    # user's ~/.psqlrc (and the system psqlrc) out of every command and
    # migration; --no-password makes a missing credential fail rather than
    # prompt, so an unattended apply can never hang.
    PSQL_ISOLATION_OPTIONS = ["--no-psqlrc", "--no-password"].freeze unless defined?(PSQL_ISOLATION_OPTIONS)

    # A password embedded in the url (postgres://user:pass@host/db) is moved
    # into a private pgpass file and @url keeps only the password-free form,
    # so the password never reaches a psql argv, a log line or an error.
    #
    # @param password: Optional password; takes precedence over one in the url
    def initialize(url, opts={})
      Preconditions.check_not_blank(url, "url cannot be blank")
      password = opts.delete(:password)

      @psql_args = ["psql"]
      (opts.delete(:set) || []).each do |arg|
        @psql_args += ["--set", arg]
      end

      Preconditions.assert_empty_opts(opts)
      connection_data = ConnectionData.parse_url(url)
      @url = ConnectionData.strip_password(url)

      password ||= connection_data.password
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
      command = @psql_args + PSQL_ISOLATION_OPTIONS + ["--no-align", "--tuples-only", "--command", sql_command]
      Library.system_or_error(command + [@url], :log => command + [sanitized_url])
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

      options = Db.attribute_values(path)

      Library.with_temp_file(:prefix => File.basename(path)) do |tmp|
        File.open(tmp, "w") do |out|
          out << "\\set ON_ERROR_STOP true\n\n"
          out << IO.read(path)
        end

        command = @psql_args + PSQL_ISOLATION_OPTIONS + ["--file", tmp] + options + [@url]

        output, status = Open3.capture2e(*command)
        if !status.success?
          raise ScriptError.new(self, filename, path, output)
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

    # Returns value as a SQL string literal, doubling any single quote.
    def Db.quote_literal(value)
      Preconditions.assert_class(value, String)
      "'" + value.gsub("'", "''") + "'"
    end

    # Returns the name of the schema_evolution_manager schema
    def Db.schema_name
      "schema_evolution_manager"
    end

    # Writes the pgpass contents to a file in Library::TMPFILE_DIR,
    # returning its path. The file is a plain file rather than a Tempfile so
    # that no finalizer can unlink it while psql still needs it; the
    # TMPFILE_DIR at_exit hook removes it. libpq ignores a pgpass file that
    # is group or world readable, so it is created mode 0600.
    def Db.password_to_tempfile(contents)
      path = File.join(Library::TMPFILE_DIR, "pgpass.%s" % SecureRandom.hex(8))
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) do |out|
        out.write(contents)
      end
      path
    end

    # The url for display. @url never carries a password (see initialize),
    # so this is @url itself; kept for callers that print the connection.
    def sanitized_url
      @url
    end

  end

end
