load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Dist" do

  it "can create a distribution" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")
    random_string = "random_string_%s" % [rand(100000)]

    TestUtils.in_test_repo do
      File.open("new.sql", "w") { |out| out << "select #{random_string}" }
      SchemaEvolutionManager::Library.system_or_error("#{add_path} ./new.sql")
      SchemaEvolutionManager::Library.system_or_error("git commit -m 'Testing'")
      SchemaEvolutionManager::Library.git_create_tag("1.0.0")
      SchemaEvolutionManager::Library.system_or_error("rm -rf dist")
      SchemaEvolutionManager::Library.system_or_error("#{dist_path} --tag '1.0.0'")
      SchemaEvolutionManager::Library.assert_dir_exists("dist")
      tarballs = Dir.glob("dist/*.tar.gz")
      tarballs.size.should == 1
      SchemaEvolutionManager::Library.system_or_error("mkdir tmp")
      Dir.chdir("tmp") do
        SchemaEvolutionManager::Library.system_or_error("tar xfz ../#{tarballs.first}")
        release_dir = Dir.glob("*tmp*").first
        changes = File.join(release_dir, "CHANGES")
        if !File.exist?(changes)
          fail("changes file[%s] not found" % [changes])
        end
        scripts = SchemaEvolutionManager::Scripts.all(File.join(release_dir, "scripts"))
        scripts.size.should == 1
        IO.read(scripts.first).index(random_string).should > 0
      end
    end
  end

end
