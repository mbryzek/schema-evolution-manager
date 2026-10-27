require File.expand_path('../../init.rb', __dir__)

# Each example here starts bin/sem-info as its own process, which is what it
# covers: the dispatch, stdout vs stderr and the exit status. Tag arithmetic is
# lib/sem_info_spec's, so the process is started once per behaviour, not once
# per input.
describe "sem-info" do

  def sem_info(*args)
    Open3.capture3(File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info"), *args)
  end

  it "can display latest tag" do
    TestUtils.in_test_repo_with_commit do
      SchemaEvolutionManager::Library.git_create_tag("0.0.5")
      sem_info("tag", "latest").first.strip.should == "0.0.5"
      sem_info("tag", "next", "minor").first.strip.should == "0.1.0"

      SchemaEvolutionManager::SemInfo.tag(["next"]).should == "0.0.6"
      SchemaEvolutionManager::SemInfo.tag(["next", "micro"]).should == "0.0.6"
      SchemaEvolutionManager::SemInfo.tag(["next", "major"]).should == "1.0.0"

      SchemaEvolutionManager::Library.git_create_tag("1.3.6")
      sem_info("tag", "next").first.strip.should == "1.3.7"
      SchemaEvolutionManager::SemInfo.tag(["next", "micro"]).should == "1.3.7"
      SchemaEvolutionManager::SemInfo.tag(["next", "minor"]).should == "1.4.0"
      SchemaEvolutionManager::SemInfo.tag(["next", "major"]).should == "2.0.0"
    end
  end

  it "tag exists" do
    TestUtils.in_test_repo_with_commit do
      SchemaEvolutionManager::Library.git_create_tag("0.0.5")
      sem_info("tag", "exists", "9.1.2").first.strip.should == "false"
      sem_info("tag", "exists", "0.0.5").first.strip.should == "true"
    end
  end

  it "version" do
    sem_info("version").first.strip.should == SchemaEvolutionManager::SemVersion::VERSION
  end

  it "version matches the VERSION file the release was cut from" do
    SchemaEvolutionManager::SemVersion::VERSION.should == IO.read(File.join(SchemaEvolutionManager::Library.base_dir, "VERSION")).strip
  end

  it "--version on every command prints the version and exits" do
    %w(sem-apply sem-baseline sem-init sem-dist).each do |cmd|
      path = File.join(SchemaEvolutionManager::Library.base_dir, "bin", cmd)
      output, status = Open3.capture2e(path, "--version")
      status.exitstatus.should == 0
      output.strip.should == SchemaEvolutionManager::SemVersion::VERSION
    end
  end

  it "db version errors clearly when no connection is provided" do
    _, stderr, status = sem_info("db", "version")
    status.exitstatus.should_not == 0
    stderr.should match(/Missing database connection/)
    stderr.should_not match(/\.rb:\d+/)   # no ruby backtrace
  end

  it "db version gives a friendly, actionable error for a bare-name --url" do
    _, stderr, status = sem_info("db", "version", "--url", "platformdb")
    status.exitstatus.should_not == 0
    stderr.should match(/--name platformdb/)                        # actionable hint
    stderr.should_not match(/RuntimeError|parse_url|\.rb:\d+/)      # no ruby backtrace
  end

  # One bootstrapped database serves every example below: bootstrapping is a
  # psql process per script, and none of these examples changes the schema.
  # Each starts from no recorded version and no applied script.
  describe "against a database" do

    before(:all) do
      @superdb = SchemaEvolutionManager::Db.new(TestUtils.server_url("postgres"))
      @name = TestUtils.random_db_name
      @superdb.psql_command("create database #{@name}")
      @db = SchemaEvolutionManager::Db.new(TestUtils.server_url(@name))
      @db.bootstrap!
    end

    after(:all) do
      @superdb.psql_command("drop database if exists #{@name}") if @name
    end

    before(:each) do
      @db.psql_command("delete from schema_evolution_manager.versions; delete from schema_evolution_manager.scripts")
    end

    it "db version prints the latest recorded version" do
      SchemaEvolutionManager::Versions.new(@db).record!("3.1.4")
      sem_info("db", "version", "--url", @db.url).first.strip.should == "3.1.4"
    end

    it "db version reports clearly when nothing is recorded" do
      stdout, stderr, _ = sem_info("db", "version", "--url", @db.url)
      stdout.strip.should == ""                                 # stdout stays clean for scripting
      stderr.strip.should == "No deployed version recorded"     # but the user sees a message
    end

    it "db scripts lists applied script filenames" do
      @db.psql_command("insert into schema_evolution_manager.scripts (filename) values ('20200101-000000.sql')")
      stdout = sem_info("db", "scripts", "--url", @db.url).first
      stdout.split("\n").map(&:strip).should include("20200101-000000.sql")
    end

  end

end
