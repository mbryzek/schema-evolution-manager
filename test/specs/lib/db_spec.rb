load File.join(File.dirname(__FILE__), '../../init.rb')

describe Db do

  def random_name
    "schema_evolution_manager_test_db_%s" % [rand(100000)]
  end

  def create_config(opts={})
    name = opts.delete(:name) || random_name
    Preconditions.check_state(opts.empty?)
    Db.parse_command_line_config("--host localhost --name #{name} --user postgres")
  end

  it "Db.parse_command_line_config" do
    db = create_config(:name => "test")
    db.host.should == "localhost"
    db.name.should == "test"
    db.user.should == "postgres"
  end

  it "Db.schema_name" do
    Db.schema_name.should == "schema_evolution_manager"
  end

  it "to_pretty_string" do
    db = create_config(:name => 'test')
    db.to_pretty_string.should == "postgres@localhost/test"
  end

  it "psql_command" do
    TestUtils.with_db do |db|
      db.psql_command("select 10").should == "10"
    end
  end

  it "psql_file" do
    TestUtils.with_db do |db|
      Library.write_to_temp_file("select 10") do |path|
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
