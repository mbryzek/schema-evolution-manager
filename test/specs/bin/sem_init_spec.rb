load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Init" do

  it "basics" do
    init_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-init")

    TestUtils.with_bootstrapped_db do |db|
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        SchemaEvolutionManager::Library.system_or_error("git init #{tmp}")
        SchemaEvolutionManager::Library.system_or_error("#{init_path} --dir #{tmp} --url #{db.url}")
        File.exist?(File.join(tmp, ".sem")).should be false
        File.exist?(File.join(tmp, "scripts/.exists")).should be true
      end
    end
  end

  it "with --scripts_dir writes .sem and creates the directory" do
    init_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-init")

    TestUtils.with_bootstrapped_db do |db|
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        SchemaEvolutionManager::Library.system_or_error("git init #{tmp}")
        SchemaEvolutionManager::Library.system_or_error("#{init_path} --dir #{tmp} --url #{db.url} --scripts_dir schema/scripts")
        IO.read(File.join(tmp, ".sem")).should == "sem.config.scripts_dir = schema/scripts\n"
        File.exist?(File.join(tmp, "schema/scripts/.exists")).should be true
        File.exist?(File.join(tmp, "scripts")).should be false
        Dir.chdir(tmp) do
          SchemaEvolutionManager::Library.system_or_error("git status --porcelain -- .sem schema").should == ""
          SchemaEvolutionManager::Library.system_or_error("git ls-files .sem schema/scripts/.exists").split("\n").should == [".sem", "schema/scripts/.exists"]
          SchemaEvolutionManager::Config.load.scripts_dir.should == File.join(File.realpath(tmp), "schema/scripts")
        end
      end
    end
  end

end
