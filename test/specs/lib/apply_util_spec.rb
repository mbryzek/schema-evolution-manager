load File.join(File.dirname(__FILE__), '../../init.rb')

describe ApplyUtil do

  it "dry_run?" do
    db = Db.new("localhost", "test", "postgres")
    ApplyUtil.new(db).dry_run?.should be_true
    ApplyUtil.new(db, :dry_run => nil).dry_run?.should be_true
    ApplyUtil.new(db, :dry_run => true).dry_run?.should be_true
    ApplyUtil.new(db, :dry_run => false).dry_run?.should be_false
  end

  it "apply! with dry run" do
    add = File.join(Library.base_dir, "bin/sem-add")
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open("new.sql", "w") do |out|
          out << "create table tmp (id integer);\n"
          out << "insert into tmp (id) values (5);\n"
        end
        Library.system_or_error("#{add} ./new.sql")
        util = ApplyUtil.new(db, :dry_run => true)
        util.apply!('./scripts').should == 1
        util.apply!('./scripts').should == 1
      end
    end
  end

  it "apply! for real" do
    add = File.join(Library.base_dir, "bin/sem-add")
    TestUtils.with_bootstrapped_db do |db|
      TestUtils.in_test_repo do
        File.open("new.sql", "w") do |out|
          out << "create table tmp (id integer);\n"
          out << "insert into tmp (id) values (5);\n"
        end
        Library.system_or_error("#{add} ./new.sql")
        util = ApplyUtil.new(db, :dry_run => false)
        util.apply!('./scripts').should == 1
        util.apply!('./scripts').should == 0
      end
      db.psql_command("select count(*) from tmp").to_i.should == 1
    end
  end

end
