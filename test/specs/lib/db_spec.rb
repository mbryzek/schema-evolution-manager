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
        db.schema_schema_evolution_manager_exists?.should be false
      end
    end

    it "bootstrapped db" do
      TestUtils.with_bootstrapped_db do |db|
        db.schema_schema_evolution_manager_exists?.should be true
      end
    end
  end

  it "should raise an error for invalid url" do
    lambda {
      SchemaEvolutionManager::Db.new("postgres://test_db")
    }.should raise_error(RuntimeError, "Invalid url[postgres://test_db]. Missing database name")
  end

  it "set argument" do
    def setup(value)
      db = SchemaEvolutionManager::Db.parse_command_line_config("--url postgresql://localhost:5432/testdb #{value}")
      puts "DB: " + db.inspect
      db.psql_executable_with_options
    end

    setup("").should == "psql"
    setup("--set foo=bar").should == "psql --set foo=bar"
    setup("--set foo=bar --set a=b").should == "psql --set foo=bar --set a=b"
  end

  describe "sanitized_url" do
    it "removes password from URL with username:password format" do
      db = SchemaEvolutionManager::Db.new("postgres://user:secret123@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end

    it "preserves URL when no password is present" do
      db = SchemaEvolutionManager::Db.new("postgres://user@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end

    it "preserves URL when no username is present" do
      db = SchemaEvolutionManager::Db.new("postgres://localhost:5432/testdb")
      db.sanitized_url.should == "postgres://localhost:5432/testdb"
    end

    it "handles complex passwords with special characters" do
      db = SchemaEvolutionManager::Db.new("postgres://user:pa$$w0rd@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end

    it "handles URLs with port numbers and complex passwords" do
      db = SchemaEvolutionManager::Db.new("postgres://user:complex:password@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end
  end

end
