load File.join(File.dirname(__FILE__), '../lib/schema-evolution-manager.rb')
require 'uri'

module TestUtils

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

  SERVER_URL_VARS = %w(SEM_TEST_DB_URL CONF_DB_DEV_URL)

  # URL of the server the DB-backed specs create throwaway databases on, with
  # the database name replaced by +name+. Read from SEM_TEST_DB_URL, else
  # CONF_DB_DEV_URL (the jdbc form `dev db session start` prints is accepted).
  # The role must be able to create databases; it defaults to postgres when
  # the URL names none. There is deliberately no default server.
  def TestUtils.server_url(name)
    var = SERVER_URL_VARS.find { |v| !ENV[v].to_s.strip.empty? }
    if var.nil?
      raise "DB-backed specs need a database server: set SEM_TEST_DB_URL (e.g. postgresql://postgres@localhost:<port>/postgres) " +
            "or CONF_DB_DEV_URL (as printed by `dev db session start --app platform`)"
    end
    TestUtils.parse_server_url(ENV[var].strip, name)
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
  def TestUtils.in_test_repo(&block)
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      SchemaEvolutionManager::Library.system_or_error("git init #{tmp}")
      Dir.chdir(tmp) do
        yield
      end
    end
  end

  def TestUtils.in_test_repo_with_commit(&block)
    TestUtils.in_test_repo do
      SchemaEvolutionManager::Library.system_or_error("echo 'test' > README.md")
      SchemaEvolutionManager::Library.system_or_error("git add README.md")
      SchemaEvolutionManager::Library.system_or_error("git commit -m 'test' README.md")
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
