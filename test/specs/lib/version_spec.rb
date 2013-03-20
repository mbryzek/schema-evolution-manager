load File.join(File.dirname(__FILE__), '../../init.rb')

describe Version do

  VALID = ["0.0.0", "0.0.1", "0.1.0", "1.0.0", "10.12.492"]
  INVALID = ["0.1", "a.0.1", "-1.1.0", "r20121212.1"]

  describe "Version.is_valid?" do

    it "valid versions" do
      VALID.each do |string|
        Version.is_valid?(string).should be_true
      end
    end

    it "invalid versions" do
      INVALID.each do |string|
        Version.is_valid?(string).should be_false
      end
    end

  end

  describe "Version.read" do

    it "valid versions" do
      VALID.each do |string|
        Version.new(string).to_version_string.should == string
      end
    end

    it "invalid versions" do
      INVALID.each do |string|
        lambda {
          Version.new(string)
        }.should raise_error(RuntimeError)
      end
    end

  end

  it "to_version_string" do
    Version.new("1.2.3").to_version_string.should == "1.2.3"
  end

  it "sorts" do
    Version.new("0.0.1").<=>(Version.new("0.0.1")).should == 0
    Version.new("0.0.1").<=>(Version.new("0.0.2")).should == -1
    Version.new("0.0.2").<=>(Version.new("0.0.1")).should == 1

    Version.new("0.0.1").<=>(Version.new("0.1.1")).should == -1
    Version.new("0.1.1").<=>(Version.new("0.0.1")).should == 1

    Version.new("0.0.1").<=>(Version.new("1.0.1")).should == -1
    Version.new("2.0.1").<=>(Version.new("3.0.1")).should == -1
    Version.new("1.0.1").<=>(Version.new("0.0.1")).should == 1
    Version.new("2.0.1").<=>(Version.new("1.0.1")).should == 1
  end

  it "Version.read" do
    Version.read.nil?.should be_false
  end

  it "next_micro" do
    Version.new("0.0.1").next_micro.to_version_string.should == "0.0.2"
    Version.new("1.2.3").next_micro.to_version_string.should == "1.2.4"
    Version.new("1.2.9").next_micro.to_version_string.should == "1.2.10"
  end

  it "Version.write" do
    current = Version.read
    next_version = current.next_micro
    begin
      Version.write(next_version)
      Version.read.to_version_string.should == next_version.to_version_string
    ensure
      Version.write(current)
    end
  end

end
