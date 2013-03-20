load File.join(File.dirname(__FILE__), '../../init.rb')

describe RdocUsage do

  it "RdocUsage.message" do
    msg = RdocUsage.message
    msg.size.should > 0
    msg.index("rspec").should >= 0
  end

end
