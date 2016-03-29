load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::ConnectionData do
  
  it "ConnectionData.parse_url" do
    SchemaEvolutionManager::ConnectionData.parse_url("postgres://db.com/test_db").pgpass.should == "db.com:5432:test_db::"
    SchemaEvolutionManager::ConnectionData.parse_url("POSTGRES://db.com/test_db").pgpass.should == "db.com:5432:test_db::"
    SchemaEvolutionManager::ConnectionData.parse_url("postgres://api@db.com/test_db").pgpass.should == "db.com:5432:test_db:api:"
    SchemaEvolutionManager::ConnectionData.parse_url("postgres://api@db.com:5432/test_db").pgpass.should == "db.com:5432:test_db:api:"
    SchemaEvolutionManager::ConnectionData.parse_url("postgres://api@db.com:4978/test_db").pgpass.should == "db.com:4978:test_db:api:"
    SchemaEvolutionManager::ConnectionData.parse_url("postgres://user1@db.com:5553/test_db").pgpass.should == "db.com:5553:test_db:user1:"
    SchemaEvolutionManager::ConnectionData.parse_url("postgres://user1@db.com:5553/test_db").pgpass("foo").should == "db.com:5553:test_db:user1:foo"
  end
    
end
