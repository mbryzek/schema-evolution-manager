load File.join(File.dirname(__FILE__), '../../init.rb')

describe Ask do

  it "Ask.for_string" do
    Ask.should_receive(:get_input).and_return("hello world")
    Ask.for_string("Testing").should == "hello world"
  end

  it "Ask.for_string trims input" do
    Ask.should_receive(:get_input).and_return("   Hello world  ")
    Ask.for_string("Testing").should == "Hello world"
  end

  it "Ask.for_string with default" do
    Ask.should_receive(:get_input).and_return("")
    Ask.for_string("Testing", :default => "  hello world  ").should == "hello world"
  end

  describe "Ask.for_boolean" do

    it "case insensitive" do
      Ask.should_receive(:get_input).and_return("Yes")
      Ask.for_boolean("Testing").should be_true
    end

    it "case insensitive" do
      Ask.should_receive(:get_input).and_return("y")
      Ask.for_boolean("Testing").should be_true
    end

    it "handles no case insensitive" do
      Ask.should_receive(:get_input).and_return("No")
      Ask.for_boolean("Testing").should be_false
    end

    it "handles n" do
      Ask.should_receive(:get_input).and_return("n")
      Ask.for_boolean("Testing").should be_false
    end

    it "assumes false for invalid input" do
      Ask.should_receive(:get_input).and_return("something else")
      Ask.for_boolean("Testing").should be_false
    end

  end

end
