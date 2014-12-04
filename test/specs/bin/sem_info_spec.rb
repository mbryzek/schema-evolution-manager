load File.join(File.dirname(__FILE__), '../../init.rb')

describe "sem-info" do

  it "can display latest tag" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    TestUtils.in_test_repo_with_commit do
      SchemaEvolutionManager::Library.git_create_tag("0.0.5")
      `#{path} tag latest`.strip.should == "0.0.5"
      `#{path} tag next`.strip.should == "0.0.6"
      `#{path} tag next micro`.strip.should == "0.0.6"
      `#{path} tag next minor`.strip.should == "0.1.0"
      `#{path} tag next major`.strip.should == "1.0.0"

      SchemaEvolutionManager::Library.git_create_tag("1.3.6")
      `#{path} tag next`.strip.should == "1.3.7"
      `#{path} tag next micro`.strip.should == "1.3.7"
      `#{path} tag next minor`.strip.should == "1.4.0"
      `#{path} tag next major`.strip.should == "2.0.0"
    end
  end

  it "version" do
    path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-info")
    TestUtils.in_test_repo_with_commit do
      `#{path} version`.strip.should == SchemaEvolutionManager::SemVersion::VERSION
    end
  end

end
