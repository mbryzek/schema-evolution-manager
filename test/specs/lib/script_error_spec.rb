load File.join(File.dirname(__FILE__), '../../init.rb')

describe ScriptError do

  it "dml" do
    db = create_config(:name => "test")
    e = ScriptError.new(db, "20130318-105434.sql")
    e.dml.should == "ADSF"
  end

end
