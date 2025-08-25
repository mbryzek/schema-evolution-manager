load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::ScriptError do

  it "can raise" do
    begin
      db = TestUtils.create_db_config(:name => "test")
      raise SchemaEvolutionManager::ScriptError.new(db, "20130318-105434.sql", "scripts/20130318-105434.sql", "test")
    rescue SchemaEvolutionManager::ScriptError => e
      # OK
    end
  end

  it "dml" do
    db = TestUtils.create_db_config(:name => "test")
    e = SchemaEvolutionManager::ScriptError.new(db, "20130318-105434.sql", "scripts/20130318-105434.sql", "test")
    e.dml.empty?.should be false
  end

  it "dml does not expose passwords in URL" do
    # Test with password in URL
    db = SchemaEvolutionManager::Db.new("postgres://user:secret123@localhost:5432/testdb")
    e = SchemaEvolutionManager::ScriptError.new(db, "20130318-105434.sql", "scripts/20130318-105434.sql", "test")
    dml_output = e.dml
    dml_output.should_not include("secret123")
    dml_output.should include("user:[REDACTED]@localhost:5432/testdb")
  end

end
