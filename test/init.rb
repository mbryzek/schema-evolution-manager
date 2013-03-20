load File.join(File.dirname(__FILE__), '../lib/all.rb')

module TestUtils

  def TestUtils.with_bootstrapped_db
    TestUtils.with_db do |db|
      db.bootstrap!
      yield db
    end
  end


  def TestUtils.with_db
    superdb = Db.new("localhost", "postgres", "postgres")
    name = "schema_evolution_manager_test_db_%s" % [rand(100000)]
    db = Db.parse_command_line_config("--host localhost --name #{name} --user postgres")
    begin
      superdb.psql_command("create database #{db.name}")
      yield db
    ensure
      superdb.psql_command("drop database #{db.name}")
    end
  end

  def TestUtils.in_test_repo(&block)
    Library.with_temp_file do |tmp|
      Library.system_or_error("git init #{tmp}")
      Dir.chdir(tmp) do
        yield
      end
    end
  end

end
