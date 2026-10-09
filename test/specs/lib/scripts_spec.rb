load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Scripts do

  it "each_pending" do
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      SchemaEvolutionManager::Library.ensure_dir!(tmp)
      File.open(File.join(tmp, "20121113-150902.sql"), "w") { |out| out << "select 1" }
      File.open(File.join(tmp, "20121114-150902.sql"), "w") { |out| out << "select 1" }
      File.open(File.join(tmp, "20121114-150903.sql"), "w") { |out| out << "select 1" }

      TestUtils.with_bootstrapped_db do |db|
        scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS)
        found = []
        scripts.each_pending(tmp) do |name, path|
          found << name
        end
        found.sort.join(" ").should == "20121113-150902.sql 20121114-150902.sql 20121114-150903.sql"
      end
    end
  end

  describe "hostile script basenames" do

    let(:db) { SchemaEvolutionManager::Db.new("postgresql://localhost:5432/unused") }
    let(:scripts) { SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS) }

    [
      '20240101-000000"$(touch sem-pwned)".sql',
      "20240101-000000') or ('1'='1.sql",
      '20240101-000000".sql',
      "20240101-000000.sql\n20240101-000001.sql",
      "notes.sql"
    ].each do |name|
      it "each_pending raises naming #{name.inspect} before any psql call" do
        db.should_not_receive(:psql_command)
        db.should_not_receive(:psql_file)
        SchemaEvolutionManager::Library.with_temp_file do |tmp|
          SchemaEvolutionManager::Library.ensure_dir!(tmp)
          File.open(File.join(tmp, "20121113-150902.sql"), "w") { |out| out << "select 1" }
          File.open(File.join(tmp, name), "w") { |out| out << "select 1" }
          lambda {
            scripts.each_pending(tmp) { |_, _| raise "must not yield" }
          }.should raise_error(RuntimeError, "Invalid filename[#{name}]. Must be like: 20120503-173242.sql")
        end
      end

      it "has_run? and record_as_run! refuse #{name.inspect} before any psql call" do
        db.should_not_receive(:psql_command)
        lambda { scripts.has_run?(name) }.should raise_error(RuntimeError)
        lambda { scripts.record_as_run!(name) }.should raise_error(RuntimeError)
      end
    end

    it "queries with every valid basename as a quoted literal" do
      sql = []
      db.stub(:schema_schema_evolution_manager_exists?).and_return(true)
      db.stub(:psql_command) { |command| sql << command; "0" }
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        SchemaEvolutionManager::Library.ensure_dir!(tmp)
        File.open(File.join(tmp, "20121113-150902.sql"), "w") { |out| out << "select 1" }
        File.open(File.join(tmp, "20121114-150902.sql"), "w") { |out| out << "select 1" }
        found = []
        scripts.each_pending(tmp) { |name, _| found << name }
        found.should == ["20121113-150902.sql", "20121114-150902.sql"]
      end
      sql.first.should == "select filename from schema_evolution_manager.scripts where filename in ('20121113-150902.sql', '20121114-150902.sql')"
    end

  end

  it "SchemaEvolutionManager::Scripts.all(dir)" do
    dir = File.join(SchemaEvolutionManager::Library.base_dir, "scripts")
    files = SchemaEvolutionManager::Scripts.all(dir)
    names = files.map { |f| File.basename(f) }
    names.join(" ").should == "20130318-105434.sql 20130318-105456.sql 20260717-000000.sql"
  end

  it "creates all scripts table" do
    TestUtils.with_bootstrapped_db do |db|
      tables = db.psql_command("select table_name from information_schema.tables where table_schema ='%s'" % [SchemaEvolutionManager::Db.schema_name])
      tables.split("\n").map(&:strip).sort.join(" ").should == (SchemaEvolutionManager::Scripts::VALID_TABLE_NAMES + ["versions"]).sort.join(" ")
    end
  end

  it "applies all bootstrap scripts" do
    TestUtils.with_bootstrapped_db do |db|
      scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::BOOTSTRAP_SCRIPTS)
      scripts.has_run?("20130318-105434.sql").should be true
      scripts.has_run?("20130318-105456.sql").should be true
    end
  end

  describe "record_as_run!" do

    it "valid filename" do
      TestUtils.with_bootstrapped_db do |db|
        scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS)
        scripts.has_run?("20130318-123458.sql").should be false
        scripts.record_as_run!("20130318-123458.sql")
        scripts.has_run?("20130318-123458.sql").should be true
      end
    end

    it "is idempotent" do
      TestUtils.with_bootstrapped_db do |db|
        scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS)
        scripts.record_as_run!("20130318-123458.sql")
        scripts.record_as_run!("20130318-123458.sql")
        scripts.has_run?("20130318-123458.sql").should be true
      end
    end

    it "invalid filename" do
      TestUtils.with_bootstrapped_db do |db|
        scripts = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS)
        lambda {
          scripts.record_as_run!("2012-123456.sql")
        }.should raise_error(RuntimeError)
      end
    end

  end

end
