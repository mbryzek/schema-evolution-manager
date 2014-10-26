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
      yield
    end
  end

  it "for a valid file" do
    test_repo_with_script(:filename => "20130318-105434.sql") do
      SchemaEvolutionManager::MigrationFile.new("scripts/20130318-105434.sql").path.should == "scripts/20130318-105434.sql"
    end
  end

  it "for a file that does not exist" do
    lambda {
      SchemaEvolutionManager::MigrationFile.new("scripts/foo.sql")
    }.should raise_error(RuntimeError, "File[scripts/foo.sql] does not exist")
  end

end
