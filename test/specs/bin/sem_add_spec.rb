load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Add" do

  it "can add a file" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    TestUtils.in_test_repo do
      File.open("new.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 0
      SchemaEvolutionManager::Library.system_or_error([path, "./new.sql"])
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 1
    end
  end

  it "adds a file from a directory whose path a shell would split" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    TestUtils.in_test_repo(:dirname => TestUtils::AWKWARD_DIRNAME) do
      file = "new script's.sql"
      File.open(file, "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Library.system_or_error([path, file])
      File.exist?(file).should be false
      scripts = SchemaEvolutionManager::Scripts.all("scripts")
      scripts.size.should == 1
      SchemaEvolutionManager::Library.system_or_error(["git", "diff", "--cached", "--name-only"]).should == scripts.first
    end
  end

  it "adding multiple files quickly results in unique filenames" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    TestUtils.in_test_repo do
      File.open("new1.sql", "w") { |out| out << "select 1" }
      File.open("new2.sql", "w") { |out| out << "select 1" }
      File.open("new3.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 0
      ["./new1.sql", "./new2.sql", "./new3.sql"].each do |file|
        SchemaEvolutionManager::Library.system_or_error([path, file])
      end

      scripts = SchemaEvolutionManager::Scripts.all("scripts").map { |s|
        s.sub(/^scripts\//, '')
      }
      scripts.size.should == 3
      scripts.uniq.size.should == 3
    end
  end

end
