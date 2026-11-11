require File.expand_path('../../init.rb', __dir__)

describe SchemaEvolutionManager::ApplyUtil do

  it "dry_run?" do
    db = SchemaEvolutionManager::Db.new("postgres://postgres@localhost/test")
    SchemaEvolutionManager::ApplyUtil.new(db).dry_run?.should be true
    SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => nil).dry_run?.should be true
    SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => true).dry_run?.should be true
    SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => false).dry_run?.should be false
  end

  it "does not record script as run if there is an error" do
    TestUtils.with_sql_script("BAD") do |db|
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 0
      util = SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => false)
      begin
        util.apply!('./scripts')
        fail("No exception thrown when applying invalid script")
      rescue Exception => e
      end
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 0
    end
  end

  it "rolls back entire transaction if there is any error" do
    TestUtils.with_sql_script("insert into tmp (id) values (5);BAD") do |db|
      db.psql_command("create table tmp (id integer);")
      db.psql_command("select count(*) from tmp").to_i.should == 0
      util = SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => false)
      begin
        util.apply!('./scripts')
        fail("No exception thrown when applying invalid script")
      rescue Exception => e
      end
      db.psql_command("select count(*) from tmp").to_i.should == 0
    end
  end

  it "apply! with dry run" do
    TestUtils.with_sql_script("create table tmp (id integer);\ninsert into tmp (id) values (5);") do |db|
      util = SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => true)
      util.apply!('./scripts').should == 1
      util.apply!('./scripts').should == 1
    end
  end

  it "apply! for real" do
    TestUtils.with_sql_script("create table tmp (id integer);\ninsert into tmp (id) values (5);") do |db|
      util = SchemaEvolutionManager::ApplyUtil.new(db, :dry_run => false)
      util.apply!('./scripts').should == 1
      util.apply!('./scripts').should == 0
      db.psql_command("select count(*) from tmp").to_i.should == 1
    end
  end
end
