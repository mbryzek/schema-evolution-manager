require File.expand_path('../../init.rb', __dir__)

describe SchemaEvolutionManager::BaselineUtil do

  it "dry_run?" do
    db = SchemaEvolutionManager::Db.new("postgres://postgres@localhost/test")
    SchemaEvolutionManager::BaselineUtil.new(db).dry_run?.should be true
    SchemaEvolutionManager::BaselineUtil.new(db, :dry_run => nil).dry_run?.should be true
    SchemaEvolutionManager::BaselineUtil.new(db, :dry_run => true).dry_run?.should be true
    SchemaEvolutionManager::BaselineUtil.new(db, :dry_run => false).dry_run?.should be false
  end

  it "apply! with dry run" do
    TestUtils.with_sql_script("create table tmp (id integer);\ninsert into tmp (id) values (5);") do |db|
      util = SchemaEvolutionManager::BaselineUtil.new(db, :dry_run => true)
      util.apply!('./scripts').should == 1
      util.apply!('./scripts').should == 1
    end
  end

  it "apply! for real" do
    TestUtils.with_sql_script("create table tmp (id integer);\ninsert into tmp (id) values (5);") do |db|
      util = SchemaEvolutionManager::BaselineUtil.new(db, :dry_run => false)
      util.apply!('./scripts').should == 1
      util.apply!('./scripts').should == 0
      expect {
        db.psql_command("select count(*) from tmp")
      }.to raise_error
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 1
    end
  end

end
