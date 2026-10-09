load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Config do

  def in_temp_dir
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      FileUtils.mkdir_p(tmp)
      yield File.realpath(tmp)
    end
  end

  def write_config(dir, contents)
    path = File.join(dir, SchemaEvolutionManager::Config::FILENAME)
    File.open(path, "w") { |out| out << contents }
    path
  end

  it "defaults to ./scripts with no .sem" do
    in_temp_dir do |dir|
      config = SchemaEvolutionManager::Config.load(dir)
      config.path.should be_nil
      config.base_dir.should == dir
      config.scripts_dir.should == File.join(dir, "scripts")
    end
  end

  it "reads .sem in the start directory" do
    in_temp_dir do |dir|
      path = write_config(dir, "sem.config.scripts_dir = schema/scripts\n")
      config = SchemaEvolutionManager::Config.load(dir)
      config.path.should == path
      config.base_dir.should == dir
      config.scripts_dir.should == File.join(dir, "schema/scripts")
    end
  end

  it "finds .sem two levels up and resolves paths relative to it" do
    in_temp_dir do |dir|
      write_config(dir, "sem.config.scripts_dir = schema/scripts\n")
      nested = File.join(dir, "a", "b")
      FileUtils.mkdir_p(nested)
      config = SchemaEvolutionManager::Config.load(nested)
      config.base_dir.should == dir
      config.scripts_dir.should == File.join(dir, "schema/scripts")
    end
  end

  it "defaults to the current directory" do
    in_temp_dir do |dir|
      write_config(dir, "sem.config.scripts_dir = db\n")
      Dir.chdir(dir) do
        SchemaEvolutionManager::Config.load.scripts_dir.should == File.join(dir, "db")
      end
    end
  end

  it "normalizes relative paths" do
    in_temp_dir do |dir|
      write_config(dir, "sem.config.scripts_dir = ./schema/../db/scripts/\n")
      SchemaEvolutionManager::Config.load(dir).scripts_dir.should == File.join(dir, "db/scripts")
    end
  end

  it "keeps an absolute path" do
    in_temp_dir do |dir|
      write_config(dir, "sem.config.scripts_dir = /var/sem/scripts\n")
      SchemaEvolutionManager::Config.load(dir).scripts_dir.should == "/var/sem/scripts"
    end
  end

  it "ignores comments and blank lines" do
    in_temp_dir do |dir|
      write_config(dir, "# schema lives under schema/\n\n   \n  # indented comment\n  sem.config.scripts_dir   =   schema/scripts  \n\n")
      SchemaEvolutionManager::Config.load(dir).scripts_dir.should == File.join(dir, "schema/scripts")
    end
  end

  it "defaults scripts_dir when .sem sets nothing" do
    in_temp_dir do |dir|
      path = write_config(dir, "# nothing yet\n")
      config = SchemaEvolutionManager::Config.load(dir)
      config.path.should == path
      config.scripts_dir.should == File.join(dir, "scripts")
    end
  end

  it "raises on an unknown name" do
    in_temp_dir do |dir|
      path = write_config(dir, "# comment\nsem.config.foo = bar\n")
      lambda {
        SchemaEvolutionManager::Config.load(dir)
      }.should raise_error(RuntimeError, "File[#{path}] line 2: Config with name[foo] not found. Must be one of: scripts_dir")
    end
  end

  it "raises on a malformed line" do
    in_temp_dir do |dir|
      ["scripts_dir = schema/scripts", "sem.config.scripts_dir", "-- sem.config.scripts_dir = x"].each do |line|
        path = write_config(dir, "\n#{line}\n")
        lambda {
          SchemaEvolutionManager::Config.load(dir)
        }.should raise_error(RuntimeError, "File[#{path}] line 2: Invalid line[#{line}]. Expected sem.config.<name> = <value>")
      end
    end
  end

  it "raises on a blank value" do
    in_temp_dir do |dir|
      path = write_config(dir, "sem.config.scripts_dir =\n")
      lambda {
        SchemaEvolutionManager::Config.load(dir)
      }.should raise_error(RuntimeError, "File[#{path}] line 1: Config[scripts_dir] - value cannot be blank")
    end
  end

  it "raises on a repeated name" do
    in_temp_dir do |dir|
      path = write_config(dir, "sem.config.scripts_dir = a\nsem.config.scripts_dir = b\n")
      lambda {
        SchemaEvolutionManager::Config.load(dir)
      }.should raise_error(RuntimeError, "File[#{path}] line 2: Config[scripts_dir] is specified more than once")
    end
  end

end
