# Modeled after http://docs.guava-libraries.googlecode.com/git/javadoc/com/google/common/base/Preconditions.html
class Preconditions

  def Preconditions.check_argument(expression, error_message=nil)
    if !expression
      raise error_message || "check_argument failed"
    end
    nil
  end

  def Preconditions.check_state(expression, error_message=nil)
    if !expression
      raise error_message || "check_state failed"
    end
    nil
  end

  def Preconditions.check_not_null(reference, error_message=nil)
    if reference.nil?
      raise error_message || "argument cannot be nil"
    end
    reference
  end

  def Preconditions.check_not_blank(reference, error_message=nil)
    if reference.to_s.strip == ""
      raise error_message || "argument cannot be blank"
    end
    reference
  end

  # Throws an error if opts is not empty. Useful when parsing
  # arguments to a function
  def Preconditions.assert_empty_opts(opts)
    if !opts.empty?
      raise "Invalid opts: #{opts.keys.inspect}\n#{opts.inspect}"
    end
  end

  # Asserts that value is not nill and is_?(klass). Returns
  # value. Common use is
  #
  # amount = Preconditions.assert_class(amount, BigDecimal)
  def Preconditions.assert_class(value, klass)
    Preconditions.check_not_null(value, "Value cannot be nil")
    Preconditions.check_not_null(klass, "Klass cannot be nil")
    Preconditions.check_state(value.is_a?(klass),
                              "Value is of type[#{value.class}] - class[#{klass}] is required. value[#{value.inspect.to_s}]")
    value
  end

  def Preconditions.assert_class_or_nil(value, klass)
    if !value.nil?
      Preconditions.assert_class(value, klass)
    end
  end

end
