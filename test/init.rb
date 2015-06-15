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
    SchemaEvolutionManager::Db.parse_command_line_config("--url postgresql://localhost:5432:#{name}")
  end

  def TestUtils.with_db
    superdb = SchemaEvolutionManager::Db.new("postgresql://localhost:5432:postgres")
    name = "schema_evolution_manager_test_db_%s" % [rand(100000)]
    db = SchemaEvolutionManager::Db.parse_command_line_config("--host localhost --name #{name} --user postgres")
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
