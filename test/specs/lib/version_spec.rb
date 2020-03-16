load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Version do

  VALID = ["0.0.0", "0.0.1", "0.1.0", "1.0.0", "10.12.492", "r1.2.3", "v1.2.3"]
  INVALID = ["0.1", "a.0.1", "-1.1.0", "r20121212.1"]

  describe "SchemaEvolutionManager::Version.is_valid?" do

    it "valid versions" do
      VALID.each do |string|
        SchemaEvolutionManager::Version.is_valid?(string).should be true
      end
    end

    it "invalid versions" do
      INVALID.each do |string|
        SchemaEvolutionManager::Version.is_valid?(string).should be false
      end
    end

  end

  describe "SchemaEvolutionManager::Version.read" do

    it "valid versions" do
      VALID.each do |string|
        SchemaEvolutionManager::Version.parse(string).to_version_string.should == string
      end
    end

    it "invalid versions" do
      INVALID.each do |string|
        lambda {
          SchemaEvolutionManager::Version.parse(string)
        }.should raise_error(RuntimeError)
      end
    end

  end

  it "to_version_string" do
    SchemaEvolutionManager::Version.parse("1.2.3").to_version_string.should == "1.2.3"
    SchemaEvolutionManager::Version.parse("v1.2.3").to_version_string.should == "v1.2.3"
  end

  it "sorts" do
    SchemaEvolutionManager::Version.parse("0.0.1").<=>(SchemaEvolutionManager::Version.parse("0.0.1")).should == 0
    SchemaEvolutionManager::Version.parse("0.0.1").<=>(SchemaEvolutionManager::Version.parse("0.0.2")).should == -1
    SchemaEvolutionManager::Version.parse("0.0.2").<=>(SchemaEvolutionManager::Version.parse("0.0.1")).should == 1

    SchemaEvolutionManager::Version.parse("0.0.1").<=>(SchemaEvolutionManager::Version.parse("0.1.1")).should == -1
    SchemaEvolutionManager::Version.parse("0.1.1").<=>(SchemaEvolutionManager::Version.parse("0.0.1")).should == 1

    SchemaEvolutionManager::Version.parse("0.0.1").<=>(SchemaEvolutionManager::Version.parse("1.0.1")).should == -1
    SchemaEvolutionManager::Version.parse("2.0.1").<=>(SchemaEvolutionManager::Version.parse("3.0.1")).should == -1
    SchemaEvolutionManager::Version.parse("1.0.1").<=>(SchemaEvolutionManager::Version.parse("0.0.1")).should == 1
    SchemaEvolutionManager::Version.parse("2.0.1").<=>(SchemaEvolutionManager::Version.parse("1.0.1")).should == 1
    SchemaEvolutionManager::Version.parse("v2.0.1").<=>(SchemaEvolutionManager::Version.parse("1.0.1")).should == 1
    SchemaEvolutionManager::Version.parse("2.0.1").<=>(SchemaEvolutionManager::Version.parse("r1.0.1")).should == 1
  end

  it "SchemaEvolutionManager::Version.read" do
    SchemaEvolutionManager::Version.read.nil?.should be false
  end

  it "next_major" do
    SchemaEvolutionManager::Version.parse("0.0.1").next_major.to_version_string.should == "1.0.0"
    SchemaEvolutionManager::Version.parse("1.2.3").next_major.to_version_string.should == "2.0.0"
    SchemaEvolutionManager::Version.parse("1.2.9").next_major.to_version_string.should == "2.0.0"
    SchemaEvolutionManager::Version.parse("1.3.9").next_major.to_version_string.should == "2.0.0"
    SchemaEvolutionManager::Version.parse("2.0.0").next_major.to_version_string.should == "3.0.0"
    SchemaEvolutionManager::Version.parse("2.3.9").next_major.to_version_string.should == "3.0.0"
    SchemaEvolutionManager::Version.parse("v2.3.9").next_major.to_version_string.should == "v3.0.0"
  end

  it "next_minor" do
    SchemaEvolutionManager::Version.parse("0.0.1").next_minor.to_version_string.should == "0.1.0"
    SchemaEvolutionManager::Version.parse("1.2.3").next_minor.to_version_string.should == "1.3.0"
    SchemaEvolutionManager::Version.parse("1.2.9").next_minor.to_version_string.should == "1.3.0"
    SchemaEvolutionManager::Version.parse("2.2.9").next_minor.to_version_string.should == "2.3.0"
    SchemaEvolutionManager::Version.parse("v2.2.9").next_minor.to_version_string.should == "v2.3.0"
  end

  it "next_micro" do
    SchemaEvolutionManager::Version.parse("0.0.1").next_micro.to_version_string.should == "0.0.2"
    SchemaEvolutionManager::Version.parse("1.2.3").next_micro.to_version_string.should == "1.2.4"
    SchemaEvolutionManager::Version.parse("1.2.9").next_micro.to_version_string.should == "1.2.10"
    SchemaEvolutionManager::Version.parse("v1.2.9").next_micro.to_version_string.should == "v1.2.10"
  end

  it "SchemaEvolutionManager::Version.write" do
    current = SchemaEvolutionManager::Version.read
    next_version = current.next_micro
    begin
      SchemaEvolutionManager::Version.write(next_version)
      SchemaEvolutionManager::Version.read.to_version_string.should == next_version.to_version_string
    ensure
      SchemaEvolutionManager::Version.write(current)
    end
  end

end
