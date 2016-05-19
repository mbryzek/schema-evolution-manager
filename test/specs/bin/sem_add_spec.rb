load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Add" do

  it "can add a file" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    TestUtils.in_test_repo do
      File.open("new.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 0
      SchemaEvolutionManager::Library.system_or_error("#{path} ./new.sql")
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 1
    end
  end

  it "adding multiple files quickly results in unique filenames" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    TestUtils.in_test_repo do
      File.open("new1.sql", "w") { |out| out << "select 1" }
      File.open("new2.sql", "w") { |out| out << "select 1" }
      File.open("new3.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Scripts.all("scripts").size.should == 0
      SchemaEvolutionManager::Library.system_or_error("#{path} ./new1.sql && #{path} ./new2.sql && #{path} ./new3.sql")

      scripts = SchemaEvolutionManager::Scripts.all("scripts").map { |s|
        s.sub(/^scripts\//, '')
      }
      scripts.size.should == 3
      scripts.uniq.size.should == 3
    end
  end

end
