load File.join(File.dirname(__FILE__), '../../init.rb')

describe "sem-info" do

  it "can display latest tag" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    TestUtils.in_test_repo_with_commit do
      SchemaEvolutionManager::Library.git_create_tag("0.0.5")
      `#{path} tag latest`.strip.should == "0.0.5"
      `#{path} tag next`.strip.should == "0.0.6"
      `#{path} tag next micro`.strip.should == "0.0.6"
      `#{path} tag next minor`.strip.should == "0.1.0"
      `#{path} tag next major`.strip.should == "1.0.0"

      SchemaEvolutionManager::Library.git_create_tag("1.3.6")
      `#{path} tag next`.strip.should == "1.3.7"
      `#{path} tag next micro`.strip.should == "1.3.7"
      `#{path} tag next minor`.strip.should == "1.4.0"
      `#{path} tag next major`.strip.should == "2.0.0"
    end
  end
  
  it "tag exists" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    TestUtils.in_test_repo_with_commit do
      SchemaEvolutionManager::Library.git_create_tag("0.0.5")
      `#{path} tag exists 9.1.2`.strip.should == "false"
      `#{path} tag exists 0.0.5`.strip.should == "true"
    end
  end

  it "version" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    TestUtils.in_test_repo_with_commit do
      `#{path} version`.strip.should == SchemaEvolutionManager::SemVersion::VERSION
    end
  end

  it "db version prints the latest recorded version" do
    info_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    output = nil
    TestUtils.with_bootstrapped_db do |db|
      SchemaEvolutionManager::Versions.new(db).record!("3.1.4")
      output = `#{info_path} db version --url #{db.url}`.strip
    end
    output.should == "3.1.4"
  end

  it "db version is blank when nothing recorded" do
    info_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    output = nil
    TestUtils.with_bootstrapped_db do |db|
      output = `#{info_path} db version --url #{db.url}`.strip
    end
    output.should == ""
  end

  it "db scripts lists applied script filenames" do
    info_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    output = nil
    TestUtils.with_bootstrapped_db do |db|
      db.psql_command("insert into schema_evolution_manager.scripts (filename) values ('20200101-000000.sql')")
      output = `#{info_path} db scripts --url #{db.url}`.strip
    end
    output.split("\n").map(&:strip).should include("20200101-000000.sql")
  end

end
