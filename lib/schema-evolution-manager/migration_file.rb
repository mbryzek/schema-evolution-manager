module SchemaEvolutionManager

  # Represents a single file to make a schema migration, typically
  # stored in the scripts subdirectory.
  class MigrationFile

    class Attribute

      attr_reader :name, :valid_values

      def initialize(name, valid_values)
        @name = Preconditions.check_not_blank(name, "name cannot be blank")
        @valid_values = Preconditions.assert_class(valid_values, Array)
      end

      unless defined?(ATTRIBUTES)
        ATTRIBUTES = [Attribute.new("transaction", ["single", "none"])]
      end

    end

    class AttributeValue

      attr_reader :attribute, :value

      def initialize(attribute_name, value)
        Preconditions.assert_class(attribute_name, String)
        @value = Preconditions.assert_class(value, String)

        @attribute = Attribute::ATTRIBUTES.find { |a| a.name == attribute_name }
        Preconditions.check_not_null(@attribute,
                                     "Attribute with name[%s] not found. Must be one of: %s" %
                                     [attribute_name, 
                                      Attribute::ATTRIBUTES.map(&:name).join(" ")])

        Preconditions.check_state(@attribute.valid_values.include?(@value),
                                  "Attribute[%s] - Invalid value[%s]. Must be one of: %s" %
                                  [@attribute.name, @value, @attribute.valid_values.join(" ")])
      end

    end

    attr_reader :path

    def initialize(path)
      @path = path
      Preconditions.check_state(File.exists?(@path), "File[#{@path}] does not exist")
    end

    # Returns a list of AttributeValues from the file
    # itself. AttributeValues are defined in comments at the top of
    # the file.
    # @see Attribute
    # @see AttributeValue
    def attribute_values
      [AttributeValue.new("transaction", "single")]
    end

  end

end
