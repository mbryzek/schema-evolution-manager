class Db

  attr_reader :host, :user, :name

  def initialize(host, user, name)
    @host = Preconditions.check_not_blank(host, "host cannot be blank")
    @user = Preconditions.check_not_blank(user, "user cannot be blank")
    @name = Preconditions.check_not_blank(name, "name cannot be blank")
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
    command = "psql --host %s --no-align --tuples-only --username %s --command \"%s\" %s" % [@host, @user, sql_command, @name]
    Library.system_or_error(command)
  end

  # executes sql commands from a file
  def psql_file(path)
    Preconditions.assert_class(path, String)
    Preconditions.check_state(File.exists?(path), "File[%s] not found" % [path])

    command = "psql --host %s --no-align --tuples-only --username %s --single-transaction --file \"%s\" %s" % [@host, @user, path, @name]
    Library.system_or_error(command)
  end

  # True if the specific schema exists; false otherwise
  def schema_schema_evolution_manager_exists?
    sql = "select count(*) from pg_namespace where nspname='%s'" % [Db.schema_name]
    psql_command(sql).to_i > 0
  end

  def to_pretty_string
    "%s@%s/%s" % [@user, @host, @name]
  end

  # Parses command line arguments returning an instance of
  # Db. Exists if invalid config.
  def Db.parse_command_line_config(arg_string)
    Preconditions.assert_class(arg_string, String)
    args = Args.new(arg_string, :required => ['host', 'user', 'name'])
    Db.from_args(args)
  end

  def Db.from_args(args)
    Preconditions.assert_class(args, Args)
    Db.new(args.host, args.user, args.name)
  end

  # Returns the name of the schema_evolution_manager schema
  def Db.schema_name
    "schema_evolution_manager"
  end

end
