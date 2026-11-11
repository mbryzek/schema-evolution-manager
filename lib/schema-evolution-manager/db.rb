module SchemaEvolutionManager

  class Db

    # Every flag that names a database connection. A command that opens a
    # Db accepts these plus its own flags (dry_run, password, scripts_dir)
    CONNECTION_FLAGS = %w(url host port name user set) unless defined?(CONNECTION_FLAGS)

    # The connection flags do not name a database: neither --url nor
    # --name, or a --url that is not a connection string
    class InvalidConnection < RuntimeError; end

    # psql_args: the psql executable and its global options, as an argv
    attr_reader :url, :psql_args

    # Options every psql invocation carries. --no-psqlrc keeps the applying
    # user's ~/.psqlrc (and the system psqlrc) out of every command and
    # migration; --no-password makes a missing credential fail rather than
    # prompt, so an unattended apply can never hang.
    PSQL_ISOLATION_OPTIONS = ["--no-psqlrc", "--no-password"]

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
    #
    # @param dry_run: When true, prints each bootstrap script that would run
    # and writes nothing: the schema is neither created nor upgraded. The
    # pending-script reads answer for an absent schema, so a dry run of the
    # scripts that follow needs no bootstrap. Returns the number of
    # bootstrap scripts run (or, in a dry run, that would run).
    def bootstrap!(opts={})
      dry_run = opts.delete(:dry_run) || false
      Preconditions.assert_empty_opts(opts)

      scripts = Scripts.new(self, Scripts::BOOTSTRAP_SCRIPTS)
      dir = File.join(Library.base_dir, "scripts")
      count = 0
      scripts.each_pending(dir) do |filename, path|
        count += 1
        if dry_run
          puts "[DRY RUN] Bootstrapping #{filename}"
        else
          psql_file(filename, path)
          scripts.record_as_run!(filename)
        end
      end
      count
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

    # executes sql commands from a file in a single transaction.
    # psql reads the original file, so the line numbers and path in
    # any psql error match the file in git.
    def psql_file(filename, path)
      Preconditions.assert_class(path, String)
      Preconditions.check_state(File.exist?(path), "File[%s] not found" % path)

      command = psql_file_command(path)

      output, status = Open3.capture2e(*command)
      if !status.success?
        raise ScriptError.new(self, filename, path, output)
      end
    end

    # The psql argv psql_file runs. ON_ERROR_STOP is set on the
    # command line, after any --set the caller passed, so it is in
    # effect before the first line of the file is read.
    def psql_file_command(path)
      @psql_args + PSQL_ISOLATION_OPTIONS + ["--set", "ON_ERROR_STOP=1", "--file", path] + Db.attribute_values(path) + [@url]
    end

    # True if the specific schema exists; false otherwise. Once seen the
    # answer is kept: every pending-script check asks it, and nothing sem
    # runs drops the schema. An absent schema is asked again, since a
    # bootstrap or an upgrade script can create it mid-run
    def schema_schema_evolution_manager_exists?
      return true if @schema_exists
      sql = "select count(*) from pg_namespace where nspname='%s'" % Db.schema_name
      @schema_exists = psql_command(sql).to_i > 0
    end

    # Parses command line arguments returning an instance of
    # Db. Raises InvalidConnection if they name no database.
    def Db.parse_command_line_config(arg_string)
      Preconditions.assert_class(arg_string, String)
      args = Args.new(arg_string, :optional => CONNECTION_FLAGS)
      Db.from_args(args)
    end

    # The Db a command's connection flags name. Prompts for a password
    # when --password was given. A connection the flags do not name is
    # one ERROR line on stderr and exit 3.
    def Db.from_command_line(args)
      Preconditions.assert_class(args, Args)
      password = args.password ? Ask.for_password("Please enter your password: ") : nil
      begin
        Db.from_args(args, :password => password)
      rescue InvalidConnection => e
        $stderr.puts "ERROR: %s" % e.message
        exit(3)
      end
    end

    # @param password: Optional password to use when connecting to the database.
    # Raises InvalidConnection unless args name a database: a --url
    # that is a connection string, or a --name.
    def Db.from_args(args, opts={})
      Preconditions.assert_class(args, Args)
      password = opts.delete(:password)
      Preconditions.assert_empty_opts(opts)

      Db.new(Db.connection_url(args), :password => password, :set => args.set)
    end

    # The url args name: --url as given, else one built from --host,
    # --port, --name and --user
    def Db.connection_url(args)
      url = args.url.to_s.strip
      name = args.name.to_s.strip

      if !url.empty?
        # A bare database name passed to --url is the common mistake
        if !url.include?("://")
          raise InvalidConnection.new("--url must be a full connection string (e.g. postgres://localhost:5432/%s). To connect by database name, use --name %s." % [url, url])
        end
        url
      elsif name.empty?
        raise InvalidConnection.new("Missing database connection. Provide --url <postgres url> or --host/--name.")
      else
        base = "%s:%s/%s" % [args.host || "localhost", args.port || ConnectionData::DEFAULT_PORT, name]
        "postgres://" + (args.user ? "%s@%s" % [args.user, base] : base)
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
