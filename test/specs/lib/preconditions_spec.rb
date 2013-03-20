load File.join(File.dirname(__FILE__), '../../init.rb')

describe Preconditions do

  def expect_exception(&block)
    begin
      block.call
    rescue Exception => e
      e.to_s.should == "Should be this"
    end
  end

  it "Preconditions.check_argument" do
    Preconditions.check_argument(true, "Noop")
    expect_exception {
      Preconditions.check_argument(false, "Should be this")
    }
  end

  it "Preconditions.check_state" do
    Preconditions.check_argument(1 > 0, "Noop")
    expect_exception {
      Preconditions.check_argument(1 < 0, "Should be this")
    }
  end

  it "Preconditions.check_not_null" do
    Preconditions.check_argument("", "Noop")
    expect_exception {
      Preconditions.check_argument(nil, "Should be this")
    }
  end

  it "Preconditions.check_not_blank" do
    expect_exception {
      Preconditions.check_not_blank(nil, "Should be this")
    }
    lambda {
      Preconditions.check_not_blank("")
    }.should raise_error(RuntimeError)
  end

  it "Preconditions.assert_empty_opts" do
    Preconditions.assert_empty_opts({})
    lambda {
      Preconditions.assert_empty_opts({ "a" => "b" })
    }.should raise_error(RuntimeError)
  end

  it "Preconditions.assert_class" do
    Preconditions.assert_class("string", String)
    Preconditions.assert_class(1, Integer)
    lambda {
      Preconditions.assert_class(1, String)
    }.should raise_error(RuntimeError)
  end

  it "Preconditions.assert_class_or_nil" do
    Preconditions.assert_class_or_nil("string", String)
    Preconditions.assert_class_or_nil(nil, String)
    Preconditions.assert_class_or_nil(1, Integer)
    lambda {
      Preconditions.assert_class_or_nil(1, String)
    }.should raise_error(RuntimeError)
  end

end
