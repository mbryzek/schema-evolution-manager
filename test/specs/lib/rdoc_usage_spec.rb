require File.expand_path('../../init.rb', __dir__)

describe SchemaEvolutionManager::RdocUsage do

  it "RdocUsage.message" do
    msg = SchemaEvolutionManager::RdocUsage.message
    msg.size.should > 0
    msg.index("rspec").should >= 0
  end

end
