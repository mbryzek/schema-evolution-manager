require File.expand_path('../../init.rb', __dir__)

describe "Apply" do

  # Every script here is written into its scripts directory directly:
  # adding one through sem-add, .sem's scripts_dir included, is
  # sem_add_spec's subject, and a process start is most of what an
  # example in this spec costs
  def write_script(dir, filename, sql)
    FileUtils.mkdir_p(dir)
    File.open(File.join(dir, filename), "w") { |out| out << sql }
  end

  # A repository holding one pending script
  def with_script_setup(&block)
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo_with_script(:sql_command => "create table tmp (id integer);\ninsert into tmp (id) values (1);\n") do
        yield db
      end
    end
  end

  # One setup carries the dry run, the first apply and the version: each
  # step finds the state the one before it left, so a step that wrote
  # more than it should shows up in the next one's assertions. That a
  # re-apply records an unchanged version once is versions_spec's subject
  it "applies nothing with dry_run, then applies the script, then records the VERSION file on a re-apply" do
    with_script_setup do |db|
      apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
      File.open("VERSION", "w") { |out| out << "2.0.0" }
      TestUtils.sh("#{apply_path} --url #{db.url} --dry_run")
      lambda {
        db.psql_command("select count(*) from tmp")
      }.should raise_error(RuntimeError)
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 0
      db.psql_command("select count(*) from schema_evolution_manager.versions").to_i.should == 0

      File.delete("VERSION")
      TestUtils.sh("#{apply_path} --url #{db.url}")
      db.psql_command("select count(*) from tmp").to_i.should == 1
      db.psql_command("select count(*) from schema_evolution_manager.versions").to_i.should == 0

      File.open("VERSION", "w") { |out| out << "2.0.0" }
      TestUtils.sh("#{apply_path} --url #{db.url}")
      db.psql_command("select count(*) from tmp").to_i.should == 1
      db.psql_command("select version from schema_evolution_manager.versions").strip.should == "2.0.0"
    end
  end

  it "applies scripts from the scripts_dir named by .sem, from a subdirectory" do
    apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open(".sem", "w") { |out| out << "sem.config.scripts_dir = schema/scripts\n" }
        write_script("schema/scripts", "20130318-105434.sql", "create table tmp (id integer);\ninsert into tmp (id) values (1);\n")
        FileUtils.mkdir_p("nested")
        Dir.chdir("nested") do
          SchemaEvolutionManager::Library.system_or_error([apply_path, "--url", db.url])
        end
        db.psql_command("select count(*) from tmp").to_i.should == 1
      end
    end
  end

  it "reports a failing script with psql's error at the line in the source file" do
    apply_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-apply")
    output = status = script = nil

    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        write_script("scripts", "20130318-105434.sql", "create table tmp (id integer);\n\ninsert into no_such_table (id) values (1);\n")
        script = File.join(SchemaEvolutionManager::Config.load.scripts_dir, "20130318-105434.sql")
        output, status = Open3.capture2e(apply_path, "--url", db.url)
      end
    end

    status.exitstatus.should == 1
    output.should include("ERROR applying script: #{script}")
    output.should include("psql:#{script}:3: ERROR")
    output.should include("no_such_table")
  end
end
