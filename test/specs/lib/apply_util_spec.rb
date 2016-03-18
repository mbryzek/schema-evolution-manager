load File.join(File.dirname(__FILE__), '../../init.rb')
require 'tempfile'
file = Tempfile.new("test")

describe SchemaEvolutionManager::ApplyUtil do


  def with_sql_script(sql)
    add = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open("new.sql", "w") { |out| out << sql }
        SchemaEvolutionManager::Library.system_or_error("#{add} ./new.sql")
        yield db
      end
    end

  end

  it "dry_run?" do
    db = SchemaEvolutionManager::Db.new("postgres://postgres@localhost/test")
    SchemaEvolutionManager::ApplyUtil.new(db, file).dry_run?.should be_true
    SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => nil).dry_run?.should be_true
    SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => true).dry_run?.should be_true
    SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => false).dry_run?.should be_false
  end

  it "does not record script as run if there is an error" do
    with_sql_script("BAD") do |db|
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 0
      util = SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => false)
      begin
        util.apply!('./scripts')
        fail("No exception thrown when applying invalid script")
      rescue Exception => e
      end
      db.psql_command("select count(*) from schema_evolution_manager.scripts").to_i.should == 0
    end
  end

  it "rolls back entire transaction if there is any error" do
    with_sql_script("insert into tmp (id) values (5);BAD") do |db|
      db.psql_command("create table tmp (id integer);")
      db.psql_command("select count(*) from tmp").to_i.should == 0
      util = SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => false)
      begin
        util.apply!('./scripts')
        fail("No exception thrown when applying invalid script")
      rescue Exception => e
      end
      db.psql_command("select count(*) from tmp").to_i.should == 0
    end
  end

  it "apply! with dry run" do
    with_sql_script("create table tmp (id integer);\ninsert into tmp (id) values (5);") do |db|
      util = SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => true)
      util.apply!('./scripts').should == 1
      util.apply!('./scripts').should == 1
    end
  end

  it "apply! for real" do
    with_sql_script("create table tmp (id integer);\ninsert into tmp (id) values (5);") do |db|
      util = SchemaEvolutionManager::ApplyUtil.new(db, file, :dry_run => false)
      util.apply!('./scripts').should == 1
      util.apply!('./scripts').should == 0
      db.psql_command("select count(*) from tmp").to_i.should == 1
    end
  end
end

describe "Pgpass" do
  it "should generate a and destory the pg_pass files" do
    TestUtils.with_bootstrapped_db do |db|
      tmpPath = file.path
      util = SchemaEvolutionManager::ApplyUtil.new(db, file)
      util.with_password_file("testPassword")
      pg_pass_string = db.generate_pgpass_str("testPassword")

      File.exists?(tmpPath).should == true
      file.read.should == pg_pass_string

      util.destroy_password_file
      File.exists?(tmpPath).should == false
    end
  end
end

