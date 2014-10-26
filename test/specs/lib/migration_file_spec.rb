load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::MigrationFile do

  def test_repo_with_script(opts={})
    sql_command = opts.delete(:sql_command) || "select 1"
    filename = opts.delete(:filename) || "20130318-105434.sql"
    SchemaEvolutionManager::Preconditions.assert_empty_opts(opts)

    TestUtils.in_test_repo do
      FileUtils.mkdir("scripts")
      path = "scripts/%s" % filename
      File.open(path, "w") { |out| out << sql_command }
      yield path
    end
  end

  describe "AttributeValue" do

    it "accepts single" do
      av = SchemaEvolutionManager::MigrationFile::AttributeValue.new("transaction", "single")
      av.attribute.name.should == "transaction"
      av.value.should == "single"
    end

    it "accepts none" do
      av = SchemaEvolutionManager::MigrationFile::AttributeValue.new("transaction", "none")
      av.attribute.name.should == "transaction"
      av.value.should == "none"
    end

    it "raises error for invalid attribute name" do
      ["", "multiple", "foo"].each do |name|
        lambda {
          SchemaEvolutionManager::MigrationFile::AttributeValue.new(name, "value")
        }.should raise_error(RuntimeError, "Attribute with name[#{name}] not found. Must be one of: transaction")
      end
    end

    it "raises error for invalid values" do
      ["", "multiple", "foo"].each do |value|
        lambda {
          SchemaEvolutionManager::MigrationFile::AttributeValue.new("transaction", value)
        }.should raise_error(RuntimeError, "Attribute[transaction] - Invalid value[#{value}]. Must be one of: single none")
      end
    end

  end

  it "for a valid file" do
    test_repo_with_script do |path|
      SchemaEvolutionManager::MigrationFile.new(path).path.should == path
    end
  end

  it "for a file that does not exist" do
    lambda {
      SchemaEvolutionManager::MigrationFile.new("scripts/foo.sql")
    }.should raise_error(RuntimeError, "File[scripts/foo.sql] does not exist")
  end

  def verify_transaction_value(values, value)
    values.size.should == 1
    values.first.attribute.name.should == "transaction"
    values.first.value.should == value
  end

  it "default attributes" do
    test_repo_with_script do |path|
      verify_transaction_value(SchemaEvolutionManager::MigrationFile.new(path).attribute_values, "single")
    end
  end

  it "attribute transaction explicitly enabled" do
    command = <<-eos
# attribute.transaction=single
select 1
    eos
    test_repo_with_script(:sql_command => command) do |path|
      verify_transaction_value(SchemaEvolutionManager::MigrationFile.new(path).attribute_values, "single")
    end
  end

  it "attribute transaction explicitly enabled" do
    command = <<-eos
# attribute.transaction=none
select 1
    eos
    test_repo_with_script(:sql_command => command) do |path|
      verify_transaction_value(SchemaEvolutionManager::MigrationFile.new(path).attribute_values, "none")
    end
  end

end
