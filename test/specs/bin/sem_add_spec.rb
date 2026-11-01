require File.expand_path('../../init.rb', __dir__)

# Each example starts bin/sem-add once: a process start is most of what
# this spec costs, so an example checks everything one run can show
describe "Add" do

  def sem_add(file)
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    SchemaEvolutionManager::Library.system_or_error([path, file])
  end

  def write_script(path, sql)
    File.open(path, "w") { |out| out << sql }
  end

  it "moves and stages a file, from a directory whose path a shell would split" do
    TestUtils.in_test_repo(:dirname => TestUtils::AWKWARD_DIRNAME) do
      file = "new script's.sql"
      write_script(file, "select 1")
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 0
      sem_add(file)
      File.exist?(file).should be false
      scripts = SchemaEvolutionManager::Scripts.all("scripts")
      scripts.size.should == 1
      IO.read(scripts.first).should == "select 1"
      SchemaEvolutionManager::Library.system_or_error(["git", "diff", "--cached", "--name-only"]).should == scripts.first
    end
  end

  # The scripts already present hold this second and the next, so the
  # added one has to step past both whenever it runs within them: the
  # same collision three sem-adds inside one second would meet
  it "steps past seconds that already hold a script, keeping names unique and in order" do
    TestUtils.in_test_repo do
      FileUtils.mkdir("scripts")
      now = Time.now.utc
      [now, now + 1].each_with_index do |stamp, i|
        write_script("scripts/#{stamp.strftime('%Y%m%d-%H%M%S')}.sql", "select #{i + 1}")
      end
      write_script("new.sql", "select 3")
      sem_add("./new.sql")

      scripts = SchemaEvolutionManager::Scripts.all("scripts")
      scripts.size.should == 3
      scripts.uniq.size.should == 3
      scripts.sort.map { |s| IO.read(s) }.should == ["select 1", "select 2", "select 3"]
    end
  end

  it "adds into the scripts_dir named by .sem, from a subdirectory" do
    TestUtils.in_test_repo do
      File.open(".sem", "w") { |out| out << "sem.config.scripts_dir = schema/scripts\n" }
      FileUtils.mkdir_p("app/sub")
      Dir.chdir("app/sub") do
        write_script("new.sql", "select 1")
        sem_add("./new.sql")
      end
      File.exist?("scripts").should be false
      SchemaEvolutionManager::Scripts.all("schema/scripts").size.should == 1
    end
  end

end
