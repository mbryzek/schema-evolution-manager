module SchemaEvolutionManager

  # Represents a single file to make a schema migration, typically
  # stored in the scripts subdirectory.
  class MigrationFile

    class Attribute

      attr_reader :name

      def initialize(name)
        @name = Preconditions.check_not_blank(name, "name cannot be blank")
      end

      unless defined?(IN_TRANSACTION)
        IN_TRANSACTION = Attribute.new("Run migration file in a single transaction")
      end

    end

    attr_reader :path

    def initialize(path)
      @path = path
      Preconditions.check_state(File.exists?(@path), "File[#{@path}] does not exist")
    end

    # Returns a list of attributes from the file itself. Attributes
    # are defined in comments at the top of the file.
    # @see Attribute
    def attributes
      [Attribute::IN_TRANSACTION]
    end

  end

end
