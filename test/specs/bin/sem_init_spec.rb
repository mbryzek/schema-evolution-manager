load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Init" do

  it "basics" do
    init_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-init")

    TestUtils.with_bootstrapped_db do |db|
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        SchemaEvolutionManager::Library.system_or_error("git init #{tmp}")
        SchemaEvolutionManager::Library.system_or_error("#{init_path} --dir #{tmp} --name test --user postgres")
      end
    end
  end

end
