load File.join(File.dirname(__FILE__), '../../init.rb')

describe SemInfo do

  describe "tag" do

    it "latest" do
      SemInfo.tag(["latest"]).should == Library.latest_tag.to_version_string
    end

    it "next" do
      SemInfo.tag(["next"]).should == Library.latest_tag.next_micro.to_version_string
    end

    it "next micro" do
      SemInfo.tag(["next", "micro"]).should == Library.latest_tag.next_micro.to_version_string
    end

    it "next minor" do
      SemInfo.tag(["next", "minor"]).should == Library.latest_tag.next_minor.to_version_string
    end

    it "next major" do
      SemInfo.tag(["next", "major"]).should == Library.latest_tag.next_major.to_version_string
    end

  end


end
