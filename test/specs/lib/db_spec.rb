load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Db do

  it "SchemaEvolutionManager::Db.parse_command_line_config" do
    db = TestUtils.create_db_config(:name => "test")
    db.url.should == "postgresql://localhost:5432/test"
  end

  it "SchemaEvolutionManager::Db.schema_name" do
    SchemaEvolutionManager::Db.schema_name.should == "schema_evolution_manager"
  end

  describe "SchemaEvolutionManager::Db.attribute_values" do

    it "defaults" do
      TestUtils.in_test_repo_with_script do |path|
        SchemaEvolutionManager::Db.attribute_values(path).join(" ").should == "--quiet --no-align --tuples-only --single-transaction"
      end
    end

    it "with transaction=single" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.transaction=single") do |path|
        SchemaEvolutionManager::Db.attribute_values(path).join(" ").should == "--quiet --no-align --tuples-only --single-transaction"
      end
    end

    it "with transaction=none" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.transaction=none") do |path|
        SchemaEvolutionManager::Db.attribute_values(path).join(" ").should == "--quiet --no-align --tuples-only"
      end
    end

    it "reports error for invalid attribute name" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.foo=single") do |path|
        lambda {
          SchemaEvolutionManager::Db.attribute_values(path)
        }.should raise_error(RuntimeError, "Attribute with name[foo] not found. Must be one of: transaction")
      end
    end

    it "reports error for invalid attribute value" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.transaction=bar") do |path|
        lambda {
          SchemaEvolutionManager::Db.attribute_values(path)
        }.should raise_error(RuntimeError, "Attribute[transaction] - Invalid value[bar]. Must be one of: single none")
      end
    end
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

  describe "generate_pgpass_str" do

    it "should generate a valid pgpass with user and port " do
      db = SchemaEvolutionManager::Db.new("postgres://user1@db.com:5553/test_db")
      db.generate_pgpass_str("pass1").should == "db.com:5553:test_db:user1:pass1"
    end

    it "should generate a valid pgpass with user and no port " do
      db = SchemaEvolutionManager::Db.new("postgres://user1@db.com/test_db")
      db.generate_pgpass_str("pass1").should == "db.com:*:test_db:user1:pass1"
    end

    it "should generate a valid pgpass with no user and port " do
      db = SchemaEvolutionManager::Db.new("postgres://db.com:5443/test_db")
      db.generate_pgpass_str("pass1").should == "db.com:5443:test_db:*:pass1"
    end

    it "should generate a valid pgpass with no user and no port " do
      db = SchemaEvolutionManager::Db.new("postgres://db.com/test_db")
      db.generate_pgpass_str("pass1").should == "db.com:*:test_db:*:pass1"
    end

    it "should raise an error for invalid url" do
      url = "postgressss://db.com/test_db"
      db = SchemaEvolutionManager::Db.new(url)
      lambda {
        db.generate_pgpass_str("pass1")
      }.should raise_error(RuntimeError, "Invalid url #{url}, needs to be: \"postgres://user@host:port/db")
    end
  end
end
