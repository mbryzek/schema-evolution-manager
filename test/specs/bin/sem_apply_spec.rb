require File.expand_path('../../init.rb', __dir__)

describe "Apply" do

  # A repository holding one pending script. The script is written into
  # scripts/ directly: adding it through sem-add is sem_add_spec's subject,
  # and the example below that names a scripts_dir still runs sem-add
  def with_script_setup(&block)
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo_with_script(:sql_command => "create table tmp (id integer);\ninsert into tmp (id) values (1);\n") do
        yield db
      end
    end
  end

  # The dry run and the real apply share one setup: the real apply then
  # finding the script still pending proves the dry run recorded nothing
  it "applies nothing with dry_run, then applies the script, recording no version when no VERSION file is present" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      TestUtils.sh("#{apply_path} --url #{db.url} --dry_run")
      lambda {
        db.psql_command("select count(*) from tmp")
      }.should raise_error(RuntimeError)
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 0

      TestUtils.sh("#{apply_path} --url #{db.url}")
      db.psql_command("select count(*) from tmp").to_i.should == 1
      db.psql_command("select count(*) from schema_evolution_manager.versions").to_i.should == 0
    end
  end

  it "records the version from a VERSION file on apply, once across re-applies" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      File.open("VERSION", "w") { |out| out << "2.0.0" }
      TestUtils.sh("#{apply_path} --url #{db.url}")
      db.psql_command("select version from schema_evolution_manager.versions order by id desc limit 1").strip.should == "2.0.0"
      TestUtils.sh("#{apply_path} --url #{db.url}")
      db.psql_command("select count(*) from schema_evolution_manager.versions").to_i.should == 1
    end
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

  it "reports a failing script with psql's error at the line in the source file" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
    output = status = script = nil

    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open("broken.sql", "w") do |out|
          out << "create table tmp (id integer);\n"
          out << "\n"
          out << "insert into no_such_table (id) values (1);\n"
        end
        SchemaEvolutionManager::Library.system_or_error([add_path, "./broken.sql"])
        script = File.join(SchemaEvolutionManager::Config.load.scripts_dir, File.basename(Dir.glob("scripts/*.sql").first))
        output, status = Open3.capture2e(apply_path, "--url", db.url)
      end
    end

    status.exitstatus.should == 1
    output.should include("ERROR applying script: #{script}")
    output.should include("psql:#{script}:3: ERROR")
    output.should include("no_such_table")
  end
end
