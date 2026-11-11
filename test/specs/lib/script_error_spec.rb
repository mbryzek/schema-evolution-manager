require File.expand_path('../../init.rb', __dir__)

describe SchemaEvolutionManager::ScriptError do

  def script_error(db, table_name)
    scripts = SchemaEvolutionManager::Scripts.new(db, table_name)
    SchemaEvolutionManager::ScriptError.new(scripts, "20130318-105434.sql", "scripts/20130318-105434.sql", "test")
  end

  it "can raise" do
    begin
      db = TestUtils.create_db_config(:name => "test")
      raise script_error(db, SchemaEvolutionManager::Scripts::SCRIPTS)
    rescue SchemaEvolutionManager::ScriptError => e
      # OK
    end
  end

  it "applied? is false unless the script ran and only its record failed" do
    db = TestUtils.create_db_config(:name => "test")
    scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS)
    script_error(db, SchemaEvolutionManager::Scripts::SCRIPTS).applied?.should be false
    SchemaEvolutionManager::ScriptError.new(scripts, "20130318-105434.sql", "p", "o", :applied => true).applied?.should be true
  end

  it "dml" do
    db = TestUtils.create_db_config(:name => "test")
    script_error(db, SchemaEvolutionManager::Scripts::SCRIPTS).dml.empty?.should be false
  end

  it "dml does not expose passwords in URL" do
    db = SchemaEvolutionManager::Db.new("postgres://user:secret123@localhost:5432/testdb")
    dml_output = script_error(db, SchemaEvolutionManager::Scripts::SCRIPTS).dml
    dml_output.should_not include("secret123")
    dml_output.should include("postgres://user@localhost:5432/testdb")
  end

  it "dml records a bootstrap script in bootstrap_scripts" do
    db = SchemaEvolutionManager::Db.new("postgres://localhost:5432/testdb")
    dml = script_error(db, SchemaEvolutionManager::Scripts::BOOTSTRAP_SCRIPTS).dml
    dml.should include("schema_evolution_manager.bootstrap_scripts")
    dml.should_not include("schema_evolution_manager.scripts ")
  end

  it "dml runs the statement record_as_run! executes, with the db's psql options" do
    db = SchemaEvolutionManager::Db.new("postgres://localhost:5432/testdb", :set => ["foo=bar"])
    scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS)
    dml = SchemaEvolutionManager::ScriptError.new(scripts, "20130318-105434.sql", "p", "o").dml
    argv = Shellwords.split(dml)
    argv.first.should == "psql"
    argv.should include("--set", "foo=bar", "--no-psqlrc", "--no-password")
    argv[argv.index("--command") + 1].should == scripts.record_as_run_sql("20130318-105434.sql")
    argv.last.should == "postgres://localhost:5432/testdb"
  end

end
