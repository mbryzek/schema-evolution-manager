require File.expand_path('../../init.rb', __dir__)

describe SchemaEvolutionManager::Ask do

  describe "SchemaEvolutionManager::Ask.for_string" do

    it "works" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("hello world")
      SchemaEvolutionManager::Ask.for_string("Testing").should == "hello world"
    end

    it "trims input" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("   Hello world  ")
      SchemaEvolutionManager::Ask.for_string("Testing").should == "Hello world"
    end

    it "uses default" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("")
      SchemaEvolutionManager::Ask.for_string("Testing", :default => "  hello world  ").should == "hello world"
    end

    it "does not fail with no input" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return(nil)
      SchemaEvolutionManager::Ask.for_string("Testing", :default => "hello world").should == "hello world"
    end

    it "raises when standard input is closed and there is no default" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).once.and_return(nil)
      lambda {
        SchemaEvolutionManager::Ask.for_string("Password:")
      }.should raise_error(RuntimeError, /standard input is closed/)
    end

    it "asks again after a blank line that is not end of input" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).twice.and_return("\n", "second")
      SchemaEvolutionManager::Ask.for_string("Testing").should == "second"
    end

    it "accepts an explicit nil echo" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).with(nil).and_return("value")
      SchemaEvolutionManager::Ask.for_string("Testing", :echo => nil).should == "value"
    end

  end

  describe "SchemaEvolutionManager::Ask.for_boolean" do

    it "case insensitive" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("Yes")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be true
    end

    it "case insensitive" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("y")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be true
    end

    it "handles no case insensitive" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("No")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be false
    end

    it "handles n" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("n")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be false
    end

    it "assumes false for invalid input" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("something else")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be false
    end

  end

end
