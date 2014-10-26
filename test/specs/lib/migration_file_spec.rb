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

  it "default attributes" do
    command = <<-eos
# ey
    eos
    test_repo_with_script(:sql_command => command) do |path|
      SchemaEvolutionManager::MigrationFile.new(path).attributes.should == [SchemaEvolutionManager::MigrationFile::Attribute::IN_TRANSACTION]
    end
  end

end
