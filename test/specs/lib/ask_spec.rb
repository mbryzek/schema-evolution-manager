load File.join(File.dirname(__FILE__), '../../init.rb')

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

  end

  describe "SchemaEvolutionManager::Ask.for_boolean" do

    it "case insensitive" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("Yes")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be_true
    end

    it "case insensitive" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("y")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be_true
    end

    it "handles no case insensitive" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("No")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be_false
    end

    it "handles n" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("n")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be_false
    end

    it "assumes false for invalid input" do
      SchemaEvolutionManager::Ask.should_receive(:get_input).and_return("something else")
      SchemaEvolutionManager::Ask.for_boolean("Testing").should be_false
    end

  end

end
