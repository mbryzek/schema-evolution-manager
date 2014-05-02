load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::ScriptError do

  it "dml" do
    db = TestUtils.create_db_config(:name => "test")
    e = SchemaEvolutionManager::ScriptError.new(db, "20130318-105434.sql")
    e.dml.empty?.should be_false
  end

end
