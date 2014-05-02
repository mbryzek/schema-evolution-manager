load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::SemInfo do

  describe "tag" do

    it "latest" do
      SchemaEvolutionManager::SemInfo.tag(["latest"]).should == SchemaEvolutionManager::Library.latest_tag.to_version_string
    end

    it "next" do
      SchemaEvolutionManager::SemInfo.tag(["next"]).should == SchemaEvolutionManager::Library.latest_tag.next_micro.to_version_string
    end

    it "next micro" do
      SchemaEvolutionManager::SemInfo.tag(["next", "micro"]).should == SchemaEvolutionManager::Library.latest_tag.next_micro.to_version_string
    end

    it "next minor" do
      SchemaEvolutionManager::SemInfo.tag(["next", "minor"]).should == SchemaEvolutionManager::Library.latest_tag.next_minor.to_version_string
    end

    it "next major" do
      SchemaEvolutionManager::SemInfo.tag(["next", "major"]).should == SchemaEvolutionManager::Library.latest_tag.next_major.to_version_string
    end

  end


end
