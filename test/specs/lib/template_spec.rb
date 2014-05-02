load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Template do

  it "parses simple template w/ no substitutions" do
    template = SchemaEvolutionManager::Template.new
    template.parse("test").should == "test"
  end

  it "parses simple template w/ single repeated substitutions" do
    template = SchemaEvolutionManager::Template.new
    template.add('value', "1")
    template.parse("test %%value%% %%value%%").should == "test 1 1"
  end

  it "parses simple template w/ multiple substitutions" do
    template = SchemaEvolutionManager::Template.new
    template.add('first', "Mike")
    template.add('last', "Bryzek")
    template.parse("Hello %%first%% %%last%%").should == "Hello Mike Bryzek"
  end

end
