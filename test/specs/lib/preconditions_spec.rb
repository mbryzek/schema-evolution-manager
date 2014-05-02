load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Preconditions do

  def expect_exception(&block)
    begin
      block.call
    rescue Exception => e
      e.to_s.should == "Should be this"
    end
  end

  it "SchemaEvolutionManager::Preconditions.check_argument" do
    SchemaEvolutionManager::Preconditions.check_argument(true, "Noop")
    expect_exception {
      SchemaEvolutionManager::Preconditions.check_argument(false, "Should be this")
    }
  end

  it "SchemaEvolutionManager::Preconditions.check_state" do
    SchemaEvolutionManager::Preconditions.check_argument(1 > 0, "Noop")
    expect_exception {
      SchemaEvolutionManager::Preconditions.check_argument(1 < 0, "Should be this")
    }
  end

  it "SchemaEvolutionManager::Preconditions.check_not_null" do
    SchemaEvolutionManager::Preconditions.check_argument("", "Noop")
    expect_exception {
      SchemaEvolutionManager::Preconditions.check_argument(nil, "Should be this")
    }
  end

  it "SchemaEvolutionManager::Preconditions.check_not_blank" do
    expect_exception {
      SchemaEvolutionManager::Preconditions.check_not_blank(nil, "Should be this")
    }
    lambda {
      SchemaEvolutionManager::Preconditions.check_not_blank("")
    }.should raise_error(RuntimeError)
  end

  it "SchemaEvolutionManager::Preconditions.assert_empty_opts" do
    SchemaEvolutionManager::Preconditions.assert_empty_opts({})
    lambda {
      SchemaEvolutionManager::Preconditions.assert_empty_opts({ "a" => "b" })
    }.should raise_error(RuntimeError)
  end

  it "SchemaEvolutionManager::Preconditions.assert_class" do
    SchemaEvolutionManager::Preconditions.assert_class("string", String)
    SchemaEvolutionManager::Preconditions.assert_class(1, Integer)
    lambda {
      SchemaEvolutionManager::Preconditions.assert_class(1, String)
    }.should raise_error(RuntimeError)
  end

  it "SchemaEvolutionManager::Preconditions.assert_class_or_nil" do
    SchemaEvolutionManager::Preconditions.assert_class_or_nil("string", String)
    SchemaEvolutionManager::Preconditions.assert_class_or_nil(nil, String)
    SchemaEvolutionManager::Preconditions.assert_class_or_nil(1, Integer)
    lambda {
      SchemaEvolutionManager::Preconditions.assert_class_or_nil(1, String)
    }.should raise_error(RuntimeError)
  end

end
