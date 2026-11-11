require File.expand_path('../../init.rb', __dir__)

describe "Baseline" do

  def baseline_path
    File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-baseline")
  end

  # Refused before any connection is attempted, so no database is needed
  it "refuses to run with neither --url nor --name" do
    TestUtils.in_test_repo do
      _, stderr, status = Open3.capture3(baseline_path, "--host", "sem-test.invalid")
      status.exitstatus.should == 3
      stderr.should include("ERROR: Missing database connection")
    end
  end

  it "accepts --set like sem-apply" do
    TestUtils.in_test_repo do
      _, stderr, status = Open3.capture3(baseline_path, "--set", "a=b", "--host", "sem-test.invalid")
      stderr.should_not include("is not accepted by this command")
      stderr.should include("ERROR: Missing database connection")
      status.exitstatus.should == 3
    end
  end

  it "records a pending script as run without applying it" do
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo_with_script(:sql_command => "create table tmp (id integer);\n") do
        SchemaEvolutionManager::Library.system_or_error([baseline_path, "--url", db.url])
        lambda {
          db.psql_command("select count(*) from tmp")
        }.should raise_error(RuntimeError)
        db.psql_command("select filename from schema_evolution_manager.scripts").strip.should == "20130318-105434.sql"
      end
    end
  end
end
