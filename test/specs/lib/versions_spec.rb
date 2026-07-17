load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Versions do

  it "validate_version! accepts a normal version" do
    SchemaEvolutionManager::Versions.validate_version!("0.4.63").should == "0.4.63"
  end

  it "validate_version! rejects blank" do
    lambda {
      SchemaEvolutionManager::Versions.validate_version!("  ")
    }.should raise_error(RuntimeError, /cannot be blank/)
  end

  it "validate_version! rejects over-length with an actionable message" do
    long = "9" * (SchemaEvolutionManager::Versions::MAX_VERSION_LENGTH + 1)
    lambda {
      SchemaEvolutionManager::Versions.validate_version!(long)
    }.should raise_error(RuntimeError, /is 101 chars; max 100/)
  end

  it "validate_version! accepts a semver pre-release/build tag" do
    SchemaEvolutionManager::Versions.validate_version!("1.0.0-rc.1+build.5").should == "1.0.0-rc.1+build.5"
  end

  it "validate_version! strictly rejects disallowed characters" do
    ["1.0.0'", "1.0 .0", "1.0.0; drop table x", "v@1"].each do |bad|
      lambda {
        SchemaEvolutionManager::Versions.validate_version!(bad)
      }.should raise_error(RuntimeError, /is invalid/)
    end
  end

  it "record! inserts and latest reads it back" do
    TestUtils.with_bootstrapped_db do |db|
      versions = SchemaEvolutionManager::Versions.new(db)
      versions.latest.should be_nil
      versions.record!("1.0.0").should be true
      versions.latest.should == "1.0.0"
    end
  end

  it "record! is insert-on-change (no duplicate rows for unchanged version)" do
    TestUtils.with_bootstrapped_db do |db|
      versions = SchemaEvolutionManager::Versions.new(db)
      versions.record!("1.0.0").should be true
      versions.record!("1.0.0").should be false
      db.psql_command("select count(*) from schema_evolution_manager.versions").to_i.should == 1
      versions.record!("1.0.1").should be true
      versions.latest.should == "1.0.1"
      db.psql_command("select count(*) from schema_evolution_manager.versions").to_i.should == 2
    end
  end
end
