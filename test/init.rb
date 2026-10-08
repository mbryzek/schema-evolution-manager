load File.join(File.dirname(__FILE__), '../lib/schema-evolution-manager.rb')

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

  def TestUtils.create_db_config(opts={})
    name = opts.delete(:name) || TestUtils.random_db_name
    SchemaEvolutionManager::Preconditions.check_state(opts.empty?)
    SchemaEvolutionManager::Db.parse_command_line_config("--url postgresql://localhost:5432/#{name}")
  end

  # The server the specs create their databases on. localhost:5432 unless
  # SEM_TEST_PGHOST / SEM_TEST_PGPORT say otherwise; ci/build.sh points them at
  # a container it starts for the run.
  def TestUtils.db_host
    ENV['SEM_TEST_PGHOST'].to_s.empty? ? "localhost" : ENV['SEM_TEST_PGHOST']
  end

  def TestUtils.db_port
    ENV['SEM_TEST_PGPORT'].to_s.empty? ? SchemaEvolutionManager::ConnectionData::DEFAULT_PORT : ENV['SEM_TEST_PGPORT'].to_i
  end


  def TestUtils.with_db
    superdb = SchemaEvolutionManager::Db.new("postgresql://postgres@#{TestUtils.db_host}:#{TestUtils.db_port}/postgres")
    name = "schema_evolution_manager_test_db_%s" % [rand(100000)]
    db = SchemaEvolutionManager::Db.parse_command_line_config("--host #{TestUtils.db_host} --port #{TestUtils.db_port} --name #{name} --user postgres")
    begin
      superdb.psql_command("create database #{name}")
      yield db
    ensure
      superdb.psql_command("drop database #{name}")
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
