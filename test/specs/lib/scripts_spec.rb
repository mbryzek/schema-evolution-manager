require File.expand_path('../../init.rb', __dir__)

describe SchemaEvolutionManager::Scripts do

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

  # Creating, bootstrapping and dropping a database is most of the cost of a
  # DB-backed example, so these share one. Every psql call is a round trip, so
  # rather than emptying the scripts table before each example, each example
  # names scripts no other example records: the 20121113 to 20121116 dates
  # are each_pending's and the 20130319 and 20130320 dates record_as_run!'s.
  describe "against a bootstrapped database" do

    before(:all) { @db = TestUtils.create_bootstrapped_db }
    after(:all) { TestUtils.drop_db(@db) if @db }

    let(:scripts) { SchemaEvolutionManager::Scripts.new(@db, SchemaEvolutionManager::Scripts::SCRIPTS) }

    it "each_pending" do
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        SchemaEvolutionManager::Library.ensure_dir!(tmp)
        File.open(File.join(tmp, "20121113-150902.sql"), "w") { |out| out << "select 1" }
        File.open(File.join(tmp, "20121114-150902.sql"), "w") { |out| out << "select 1" }
        File.open(File.join(tmp, "20121114-150903.sql"), "w") { |out| out << "select 1" }

        found = []
        scripts.each_pending(tmp) do |name, path|
          found << name
        end
        found.sort.join(" ").should == "20121113-150902.sql 20121114-150902.sql 20121114-150903.sql"
      end
    end

    it "each_pending skips a script already recorded as run" do
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        SchemaEvolutionManager::Library.ensure_dir!(tmp)
        File.open(File.join(tmp, "20121115-150902.sql"), "w") { |out| out << "select 1" }
        File.open(File.join(tmp, "20121116-150902.sql"), "w") { |out| out << "select 1" }
        scripts.record_as_run!("20121115-150902.sql")

        found = []
        scripts.each_pending(tmp) { |name, _| found << name }
        found.should == ["20121116-150902.sql"]
      end
    end

    it "creates all scripts table" do
      tables = @db.psql_command("select table_name from information_schema.tables where table_schema ='%s'" % [SchemaEvolutionManager::Db.schema_name])
      tables.split("\n").map(&:strip).sort.join(" ").should == (SchemaEvolutionManager::Scripts::VALID_TABLE_NAMES + ["versions"]).sort.join(" ")
    end

    it "applies all bootstrap scripts" do
      bootstrap = SchemaEvolutionManager::Scripts.new(@db, SchemaEvolutionManager::Scripts::BOOTSTRAP_SCRIPTS)
      bootstrap.has_run?("20130318-105434.sql").should be true
      bootstrap.has_run?("20130318-105456.sql").should be true
    end

    describe "record_as_run!" do

      it "valid filename" do
        scripts.has_run?("20130319-123458.sql").should be false
        scripts.record_as_run!("20130319-123458.sql")
        scripts.has_run?("20130319-123458.sql").should be true
      end

      it "is idempotent" do
        scripts.record_as_run!("20130320-123458.sql")
        scripts.record_as_run!("20130320-123458.sql")
        scripts.applied.count("20130320-123458.sql").should == 1
      end

      it "invalid filename" do
        lambda {
          scripts.record_as_run!("2012-123456.sql")
        }.should raise_error(RuntimeError)
      end

    end

  end

end
