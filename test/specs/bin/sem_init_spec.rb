load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Init" do

  it "basics" do
    init_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-init")

    TestUtils.with_bootstrapped_db do |db|
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        TestUtils.sh("git init #{tmp}")
        TestUtils.sh("#{init_path} --dir #{tmp} --url #{db.url}")
      end
    end
  end

end
