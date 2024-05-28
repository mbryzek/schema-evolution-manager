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
                                      Attribute::ATTRIBUTES.map { |a| a.name }.join(" ")])

        Preconditions.check_state(@attribute.valid_values.include?(@value),
                                  "Attribute[%s] - Invalid value[%s]. Must be one of: %s" %
                                  [@attribute.name, @value, @attribute.valid_values.join(" ")])
      end

    end

    unless defined?(DEFAULTS)
      DEFAULTS = [AttributeValue.new("transaction", "single")]
    end

    attr_reader :path, :attribute_values

    def initialize(path)
      @path = path
      Preconditions.check_state(File.exist?(@path), "File[#{@path}] does not exist")
      @attribute_values = parse_attribute_values
    end

    private

    # Returns a list of AttributeValues from the file itself,
    # including all defaults set by SEM. AttributeValues are defined
    # in comments in the file.
    def parse_attribute_values
      values = []
      each_property do |name, value|
        values << AttributeValue.new(name, value)
      end

      DEFAULTS.each do |default|
        if values.find { |v| v.attribute.name == default.attribute.name }.nil?
          values << default
        end
      end

      values
    end

    # Parse properties from the comments. Looks for this pattern:
    #
    # -- sem.attribute.name = value
    #
    # and yields each matching row with |name, value|
    def each_property
      IO.readlines(path).each do |l|
        stripped = l.strip
        if stripped.match(/^\-\-\s+sem\.attribute\./)
          stripped.sub!(/^\-\-\s+sem\.attribute\./, '')
          name, value = stripped.split(/\=/, 2).map(&:strip)
          yield name, value
        end
      end
    end

  end

end
