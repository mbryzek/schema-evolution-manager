load File.join(File.dirname(__FILE__), '../lib/schema-evolution-manager.rb')
require 'uri'

module TestUtils

  # A directory name a shell would split or unquote: commands built
  # from a path under it work only if every argument reaches its
  # program intact
  AWKWARD_DIRNAME = "sem repo's $HOME" unless defined?(AWKWARD_DIRNAME)

  # Runs a shell command line. Test-only: library code passes an argv
  # to Library.system_or_error and never reaches a shell
  def TestUtils.sh(command)
    SchemaEvolutionManager::Library.system_or_error(["/bin/sh", "-c", command])
  end

  def TestUtils.with_bootstrapped_db
    TestUtils.with_db do |db|
      db.bootstrap!
      yield db
    end
  end

  def TestUtils.random_db_name
    "schema_evolution_manager_test_db_%s" % [rand(100000)]
  end

  # Builds a config that is never connected to; the host cannot resolve, so
  # an accidental connection fails rather than reaching a local server.
  def TestUtils.create_db_config(opts={})
    name = opts.delete(:name) || TestUtils.random_db_name
    SchemaEvolutionManager::Preconditions.check_state(opts.empty?)
    SchemaEvolutionManager::Db.parse_command_line_config("--url postgresql://sem-test.invalid/#{name}")
  end

  # Variables holding a full server url, in order of precedence.
  SERVER_URL_VARS = %w(SEM_TEST_DB_URL SEM_TEST_SERVER_URL CONF_DB_DEV_URL)

  # Variables naming the server by host and port; ci/build.sh points them at
  # a container it starts for the run.
  SERVER_HOST_VARS = %w(SEM_TEST_PGHOST SEM_TEST_PGPORT)

  # URL of the server the DB-backed specs create throwaway databases on, with
  # the database name replaced by +name+. Read from SEM_TEST_DB_URL, else
  # SEM_TEST_SERVER_URL, else CONF_DB_DEV_URL (the jdbc form `dev db session
  # start` prints is accepted), else SEM_TEST_PGHOST / SEM_TEST_PGPORT (port
  # defaults to 5432). The role must be able to create databases; it defaults
  # to postgres when the URL names none. There is deliberately no default server.
  def TestUtils.server_url(name)
    var = SERVER_URL_VARS.find { |v| !ENV[v].to_s.strip.empty? }
    if var
      TestUtils.parse_server_url(ENV[var].strip, name)
    elsif !ENV["SEM_TEST_PGHOST"].to_s.strip.empty?
      port = ENV["SEM_TEST_PGPORT"].to_s.strip.empty? ? SchemaEvolutionManager::ConnectionData::DEFAULT_PORT : ENV["SEM_TEST_PGPORT"].strip
      TestUtils.parse_server_url("postgresql://postgres@#{ENV["SEM_TEST_PGHOST"].strip}:#{port}", name)
    else
      raise "DB-backed specs need a database server: set SEM_TEST_DB_URL (e.g. postgresql://postgres@localhost:<port>/postgres) " +
            "or CONF_DB_DEV_URL (as printed by `dev db session start --app platform`)"
    end
  end

  def TestUtils.parse_server_url(raw, name)
    uri = URI.parse(raw.sub(/\Ajdbc:/, ""))
    unless %w(postgres postgresql).include?(uri.scheme.to_s.downcase) && uri.host
      raise "Invalid database server url[%s]: expected postgresql://[user[:password]@]host[:port]/db" % raw.sub(/:[^:@\/]*@/, ":[REDACTED]@")
    end
    params = uri.query ? URI.decode_www_form(uri.query).to_h : {}
    user = uri.user || params["user"] || "postgres"
    password = uri.password || params["password"]
    userinfo = password ? "#{user}:#{password}" : user
    port = uri.port ? ":#{uri.port}" : ""
    "postgresql://#{userinfo}@#{uri.host}#{port}/#{name}"
  end

  def TestUtils.with_db
    superdb = SchemaEvolutionManager::Db.new(TestUtils.server_url("postgres"))
    name = TestUtils.random_db_name
    db = SchemaEvolutionManager::Db.new(TestUtils.server_url(name))
    begin
      superdb.psql_command("create database #{name}")
      yield db
    ensure
      superdb.psql_command("drop database if exists #{name}")
    end
  end

  # Creates a test repository for schema script
  # management. Initialized with a git repo.
  #
  # @param dirname: Optional name for the repository directory (see
  #        AWKWARD_DIRNAME)
  def TestUtils.in_test_repo(opts={}, &block)
    dirname = opts.delete(:dirname)
    SchemaEvolutionManager::Preconditions.assert_empty_opts(opts)

    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      repo = dirname ? File.join(tmp, dirname) : tmp
      FileUtils.mkdir_p(repo)
      SchemaEvolutionManager::Library.system_or_error(["git", "init", "--quiet", repo])
      Dir.chdir(repo) do
        yield
      end
    end
  end

  def TestUtils.in_test_repo_with_commit(&block)
    TestUtils.in_test_repo do
      File.open("README.md", "w") { |out| out << "test\n" }
      SchemaEvolutionManager::Library.system_or_error(["git", "add", "README.md"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "test", "README.md"])
      yield
    end
  end

  def TestUtils.in_test_repo_with_script(opts={})
    sql_command = opts.delete(:sql_command) || "select 1"
    filename = opts.delete(:filename) || "20130318-105434.sql"
    SchemaEvolutionManager::Preconditions.assert_empty_opts(opts)

    TestUtils.in_test_repo do
      FileUtils.mkdir("scripts")
      path = "scripts/%s" % filename
      File.open(path, "w") { |out| out << sql_command }
      yield path
    end
  end


end
