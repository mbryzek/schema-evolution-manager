load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Db do

  it "SchemaEvolutionManager::Db.parse_command_line_config" do
    db = TestUtils.create_db_config(:name => "test")
    db.url.should == "postgresql://localhost:5432/test"
  end

  it "SchemaEvolutionManager::Db.schema_name" do
    SchemaEvolutionManager::Db.schema_name.should == "schema_evolution_manager"
  end

  describe "SchemaEvolutionManager::Db.attribute_values" do

    it "defaults" do
      TestUtils.in_test_repo_with_script do |path|
        SchemaEvolutionManager::Db.attribute_values(path).join(" ").should == "--quiet --no-align --tuples-only --single-transaction"
      end
    end

    it "with transaction=single" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.transaction=single") do |path|
        SchemaEvolutionManager::Db.attribute_values(path).join(" ").should == "--quiet --no-align --tuples-only --single-transaction"
      end
    end

    it "with transaction=none" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.transaction=none") do |path|
        SchemaEvolutionManager::Db.attribute_values(path).join(" ").should == "--quiet --no-align --tuples-only"
      end
    end

    it "reports error for invalid attribute name" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.foo=single") do |path|
        lambda {
          SchemaEvolutionManager::Db.attribute_values(path)
        }.should raise_error(RuntimeError, "Attribute with name[foo] not found. Must be one of: transaction")
      end
    end

    it "reports error for invalid attribute value" do
      TestUtils.in_test_repo_with_script(:sql_command => "-- sem.attribute.transaction=bar") do |path|
        lambda {
          SchemaEvolutionManager::Db.attribute_values(path)
        }.should raise_error(RuntimeError, "Attribute[transaction] - Invalid value[bar]. Must be one of: single none")
      end
    end
  end

  it "SchemaEvolutionManager::Db.quote_literal" do
    SchemaEvolutionManager::Db.quote_literal("abc").should == "'abc'"
    SchemaEvolutionManager::Db.quote_literal("a'b''c").should == "'a''b''''c'"
  end

  it "psql_command passes the sql to psql as one argument, never through the shell" do
    db = SchemaEvolutionManager::Db.new("postgresql://localhost:5432/unused")
    commands = []
    SchemaEvolutionManager::Library.stub(:system_or_error) { |command, _| commands << command; "" }
    sql = %q{select '"$(touch sem-pwned)"', `id`, $HOME, "quoted"}
    db.psql_command(sql)
    commands.size.should == 1
    argv = Shellwords.split(commands.first)
    argv[argv.index("--command") + 1].should == sql
  end

  it "psql_command" do
    TestUtils.with_db do |db|
      db.psql_command("select 10").should == "10"
    end
  end

  it "psql_file" do
    TestUtils.with_db do |db|
      sql = "create table psql_file_test (id integer); insert into psql_file_test (id) values (10);"
      SchemaEvolutionManager::Library.write_to_temp_file(sql) do |path|
        db.psql_file("20130318-105434.sql", path)
      end
      db.psql_command("select id from psql_file_test").should == "10"
    end
  end

  describe "psql isolation options" do

    it "psql_command passes --no-psqlrc and --no-password" do
      db = SchemaEvolutionManager::Db.new("postgres://localhost:5432/testdb")
      commands = []
      SchemaEvolutionManager::Library.should_receive(:system_or_error) { |command, _| commands << command; "" }
      db.psql_command("select 1")
      commands.size.should == 1
      commands.first.split.should include("--no-psqlrc", "--no-password")
    end

    it "psql_file passes --no-psqlrc and --no-password" do
      db = SchemaEvolutionManager::Db.new("postgres://localhost:5432/testdb")
      commands = []
      db.define_singleton_method(:`) do |command|
        commands << command
        system("true")
        ""
      end
      SchemaEvolutionManager::Library.write_to_temp_file("select 1;") do |path|
        db.psql_file("20130318-105434.sql", path)
      end
      commands.size.should == 1
      commands.first.split.should include("--no-psqlrc", "--no-password")
    end

  end

  describe "schema_schema_evolution_manager_exists?" do

    it "new db" do
      TestUtils.with_db do |db|
        db.schema_schema_evolution_manager_exists?.should be false
      end
    end

    it "bootstrapped db" do
      TestUtils.with_bootstrapped_db do |db|
        db.schema_schema_evolution_manager_exists?.should be true
      end
    end
  end

  it "should raise an error for invalid url" do
    lambda {
      SchemaEvolutionManager::Db.new("postgres://test_db")
    }.should raise_error(RuntimeError, "Invalid url[postgres://test_db]. Missing database name")
  end

  it "set argument" do
    def setup(value)
      db = SchemaEvolutionManager::Db.parse_command_line_config("--url postgresql://localhost:5432/testdb #{value}")
      puts "DB: " + db.inspect
      db.psql_args
    end

    setup("").should == ["psql"]
    setup("--set foo=bar").should == ["psql", "--set", "foo=bar"]
    setup("--set foo=bar --set a=b").should == ["psql", "--set", "foo=bar", "--set", "a=b"]
  end

  it "set argument keeps a value with shell metacharacters as one argument" do
    db = SchemaEvolutionManager::Db.new("postgresql://localhost:5432/testdb", :set => ["a=x y;$(id)"])
    db.psql_args.should == ["psql", "--set", "a=x y;$(id)"]
  end

  describe "sanitized_url" do
    it "removes password from URL with username:password format" do
      db = SchemaEvolutionManager::Db.new("postgres://user:secret123@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end

    it "preserves URL when no password is present" do
      db = SchemaEvolutionManager::Db.new("postgres://user@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end

    it "preserves URL when no username is present" do
      db = SchemaEvolutionManager::Db.new("postgres://localhost:5432/testdb")
      db.sanitized_url.should == "postgres://localhost:5432/testdb"
    end

    it "handles complex passwords with special characters" do
      db = SchemaEvolutionManager::Db.new("postgres://user:pa$$w0rd@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end

    it "handles URLs with port numbers and complex passwords" do
      db = SchemaEvolutionManager::Db.new("postgres://user:complex:password@localhost:5432/testdb")
      db.sanitized_url.should == "postgres://user@localhost:5432/testdb"
    end
  end

  describe "password in the url" do
    url = "postgres://user:s3cret@localhost:1/db"

    it "is removed from url" do
      SchemaEvolutionManager::Db.new(url).url.should == "postgres://user@localhost:1/db"
    end

    it "is written to the pgpass file" do
      SchemaEvolutionManager::Db.new(url)
      IO.read(ENV['PGPASSFILE']).should == "localhost:1:db:user:s3cret"
      (File.stat(ENV['PGPASSFILE']).mode & 0777).should == 0600
    end

    it "is percent-decoded and escaped in the pgpass file" do
      SchemaEvolutionManager::Db.new("postgres://user:p%40ss:w@localhost:1/db?sslmode=require")
      IO.read(ENV['PGPASSFILE']).should == "localhost:1:db:user:p@ss\\:w"
    end

    it "is overridden by an explicit password" do
      SchemaEvolutionManager::Db.new(url, :password => "other")
      IO.read(ENV['PGPASSFILE']).should == "localhost:1:db:user:other"
    end

    it "never reaches the psql command line, a log line or an error" do
      db = SchemaEvolutionManager::Db.new(url)
      commands = []
      backtick = SchemaEvolutionManager::Library.method(:`)
      SchemaEvolutionManager::Library.define_singleton_method(:`) do |cmd|
        commands << cmd
        backtick.call(cmd)
      end
      SchemaEvolutionManager::Library.set_verbose(true)
      begin
        error = nil
        output = capture_stdout do
          begin
            db.psql_command("select 1")
          rescue => e
            error = e
          end
        end
        error.should_not be_nil
        error.message.should include("postgres://user@localhost:1/db")
        error.message.should_not include("s3cret")
        output.should_not include("s3cret")
        commands.size.should == 1
        commands.first.should_not include("s3cret")
      ensure
        SchemaEvolutionManager::Library.set_verbose(false)
        SchemaEvolutionManager::Library.singleton_class.send(:remove_method, :`)
      end
    end

    it "is not in an invalid url error" do
      lambda {
        SchemaEvolutionManager::Db.new("postgres://user:s3cret@localhost")
      }.should raise_error(RuntimeError, "Invalid url[postgres://user:[REDACTED]@localhost]. Missing database name")
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  describe "Db.password_to_tempfile" do
    it "writes a 0600 file in the private temp dir that survives garbage collection" do
      path = SchemaEvolutionManager::Db.password_to_tempfile("localhost:5432:db:user:secret")
      GC.start
      File.exist?(path).should == true
      IO.read(path).should == "localhost:5432:db:user:secret"
      (File.stat(path).mode & 0777).should == 0600
      File.dirname(path).should == SchemaEvolutionManager::Library::TMPFILE_DIR
    end

    it "gives each call its own file" do
      a = SchemaEvolutionManager::Db.password_to_tempfile("a")
      b = SchemaEvolutionManager::Db.password_to_tempfile("b")
      a.should_not == b
      IO.read(a).should == "a"
    end
  end

end
