load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Apply" do

  def with_script_setup(&block)
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    random_number = rand(100000)

    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open("new.sql", "w") do |out|
          out << "create table tmp (id integer);\n"
          out << "insert into tmp (id) values (%s);\n" % [random_number]
        end
        TestUtils.sh("#{add_path} ./new.sql")
        yield db
      end
    end
  end

  it "does not apply sql scripts with dry_run" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      TestUtils.sh("#{apply_path} --url #{db.url} --dry_run")
      lambda {
        db.psql_command("select count(*) from tmp")
      }.should raise_error(RuntimeError)
    end
  end

  it "applies sql scripts without dry_run" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      TestUtils.sh("#{apply_path} --url #{db.url}")
      db.psql_command("select count(*) from tmp").to_i.should == 1
    end
  end

  it "records the version from a VERSION file on apply" do
    recorded_version = nil
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      File.open("VERSION", "w") { |out| out << "2.0.0" }
      TestUtils.sh("#{apply_path} --url #{db.url}")
      recorded_version = db.psql_command("select version from schema_evolution_manager.versions order by id desc limit 1").strip
    end
    recorded_version.should == "2.0.0"
  end

  it "records nothing when no VERSION file is present" do
    version_count = nil
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      TestUtils.sh("#{apply_path} --url #{db.url}")
      version_count = db.psql_command("select count(*) from schema_evolution_manager.versions").to_i
    end
    version_count.should == 0
  end

  it "does not duplicate a version across re-applies" do
    version_count = nil
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      File.open("VERSION", "w") { |out| out << "2.0.0" }
      TestUtils.sh("#{apply_path} --url #{db.url}")
      TestUtils.sh("#{apply_path} --url #{db.url}")
      version_count = db.psql_command("select count(*) from schema_evolution_manager.versions").to_i
    end
    version_count.should == 1
  end

  it "applies scripts from the scripts_dir named by .sem" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open(".sem", "w") { |out| out << "sem.config.scripts_dir = schema/scripts\n" }
        File.open("new.sql", "w") { |out| out << "create table tmp (id integer);\ninsert into tmp (id) values (1);\n" }
        SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
        SchemaEvolutionManager::Scripts.all("schema/scripts").size.should == 1
        FileUtils.mkdir_p("nested")
        Dir.chdir("nested") do
          SchemaEvolutionManager::Library.system_or_error([apply_path, "--url", db.url])
        end
        db.psql_command("select count(*) from tmp").to_i.should == 1
      end
    end
  end
end
