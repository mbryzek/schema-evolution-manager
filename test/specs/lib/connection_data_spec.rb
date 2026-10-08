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

  it "ConnectionData.parse_url with a password" do
    data = SchemaEvolutionManager::ConnectionData.parse_url("postgres://user1:p@ss:w%25d@db.com:5553/test_db?sslmode=require")
    data.user.should == "user1"
    data.password.should == "p@ss:w%d"
    data.host.should == "db.com"
    data.port.should == 5553
    data.pgpass(data.password).should == "db.com:5553:test_db:user1:p@ss\\:w%d"
  end

  it "ConnectionData.strip_password" do
    SchemaEvolutionManager::ConnectionData.strip_password("postgres://user1:p@ss@db.com:5553/test_db").should == "postgres://user1@db.com:5553/test_db"
    SchemaEvolutionManager::ConnectionData.strip_password("postgres://user1@db.com/test_db").should == "postgres://user1@db.com/test_db"
    SchemaEvolutionManager::ConnectionData.strip_password("postgres://db.com/test_db").should == "postgres://db.com/test_db"
    SchemaEvolutionManager::ConnectionData.strip_password("postgres://:secret@db.com/test_db").should == "postgres://db.com/test_db"
  end

  it "ConnectionData.redact" do
    SchemaEvolutionManager::ConnectionData.redact("postgres://user1:secret@db.com/test_db").should == "postgres://user1:[REDACTED]@db.com/test_db"
    SchemaEvolutionManager::ConnectionData.redact("postgres://user1@db.com/test_db").should == "postgres://user1@db.com/test_db"
  end

  it "ConnectionData.parse_url errors never carry the password" do
    lambda {
      SchemaEvolutionManager::ConnectionData.parse_url("postgres://u:secret@db.com:abc/test_db")
    }.should raise_error(RuntimeError, "Invalid url[postgres://u:[REDACTED]@db.com:abc/test_db]. Expected database port[abc] to be an integer")
  end
    
end
