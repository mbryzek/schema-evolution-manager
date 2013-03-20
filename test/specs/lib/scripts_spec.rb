load File.join(File.dirname(__FILE__), '../../init.rb')

describe Scripts do

  it "Scripts.all(dir)" do
    dir = File.join(Library.base_dir, "scripts")
    files = Scripts.all(dir)
    names = files.map { |f| File.basename(f) }
    names.join(" ").should == "20130318-105434.sql 20130318-105456.sql"
  end

  it "creates all scripts table" do
    TestUtils.with_bootstrapped_db do |db|
      tables = db.psql_command("select table_name from information_schema.tables where table_schema ='%s'" % [Db.schema_name])
      tables.map(&:strip).sort.join(" ").should == Scripts::VALID_TABLE_NAMES.sort.join(" ")
    end
  end

  it "applies all bootstrap scripts" do
    TestUtils.with_bootstrapped_db do |db|
      scripts = Scripts.new(db, Scripts::BOOTSTRAP_SCRIPTS)
      scripts.has_run?("20130318-105434.sql").should be_true
      scripts.has_run?("20130318-105456.sql").should be_true
    end
  end

  describe "record_as_run!" do

    it "valid filename" do
      TestUtils.with_bootstrapped_db do |db|
        scripts = Scripts.new(db, Scripts::SCRIPTS)
        scripts.has_run?("20130318-123458.sql").should be_false
        scripts.record_as_run!("20130318-123458.sql")
        scripts.has_run?("20130318-123458.sql").should be_true
      end
    end

    it "is idempotent" do
      TestUtils.with_bootstrapped_db do |db|
        scripts = Scripts.new(db, Scripts::SCRIPTS)
        scripts.record_as_run!("20130318-123458.sql")
        scripts.record_as_run!("20130318-123458.sql")
        scripts.has_run?("20130318-123458.sql").should be_true
      end
    end

    it "invalid filename" do
      TestUtils.with_bootstrapped_db do |db|
        scripts = Scripts.new(db, Scripts::SCRIPTS)
        lambda {
          scripts.record_as_run!("2012-123456.sql")
        }.should raise_error(RuntimeError)
      end
    end

  end

end
