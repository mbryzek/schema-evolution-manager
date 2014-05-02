load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Db do

  it "SchemaEvolutionManager::Db.parse_command_line_config" do
    db = TestUtils.create_db_config(:name => "test")
    db.host.should == "localhost"
    db.name.should == "test"
    db.user.should == "postgres"
  end

  it "SchemaEvolutionManager::Db.schema_name" do
    SchemaEvolutionManager::Db.schema_name.should == "schema_evolution_manager"
  end

  it "to_pretty_string" do
    db = TestUtils.create_db_config(:name => "test")
    db.to_pretty_string.should == "postgres@localhost/test"
  end

  it "psql_command" do
    TestUtils.with_db do |db|
      db.psql_command("select 10").should == "10"
    end
  end

  it "psql_file" do
    TestUtils.with_db do |db|
      SchemaEvolutionManager::Library.write_to_temp_file("select 10") do |path|
        db.psql_file(path).should == "10"
      end
    end
  end

  describe "schema_schema_evolution_manager_exists?" do

    it "new db" do
      TestUtils.with_db do |db|
        db.schema_schema_evolution_manager_exists?.should be_false
      end
    end

    it "bootstrapped db" do
      TestUtils.with_bootstrapped_db do |db|
        db.schema_schema_evolution_manager_exists?.should be_true
      end
    end
  end

end
