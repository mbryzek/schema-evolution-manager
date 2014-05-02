module SchemaEvolutionManager

  # Simple template parsing using regular expressions to substitute values.
  # See unit test for example usage at test/specs/lib/template_spec.rb
  class Template

    class Substitution

      attr_reader :pattern, :value

      def initialize(pattern, value)
        @pattern = Preconditions.check_not_blank(pattern)
        @value = Preconditions.check_not_blank(value)
      end

    end

    def initialize
      @subs = []
    end

    # add('first', 'Mike')
    # Will replace all instances of '%%first%%' with value when you call parse
    def add(pattern, value)
      @subs << Substitution.new(pattern, value)
    end

    def parse(contents)
      Preconditions.check_not_blank(contents)
      string = contents.dup
      @subs.each do |sub|
        string = string.gsub(/%%#{sub.pattern}%%/, sub.value)
      end
      string
    end

  end

end
