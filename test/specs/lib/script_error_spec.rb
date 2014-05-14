load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::ScriptError do

  it "can raise" do
    begin
      db = TestUtils.create_db_config(:name => "test")
      raise SchemaEvolutionManager::ScriptError.new(db, "20130318-105434.sql")
    rescue SchemaEvolutionManager::ScriptError => e
      # OK
    end
  end

  it "dml" do
    db = TestUtils.create_db_config(:name => "test")
    e = SchemaEvolutionManager::ScriptError.new(db, "20130318-105434.sql")
    e.dml.empty?.should be_false
  end

end
