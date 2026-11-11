module SchemaEvolutionManager

  # Simple library to ask user for input, with easy mocakability for
  # testing
  class Ask

    TRUE_STRINGS = ['y', 'yes'] unless defined?(TRUE_STRINGS)

    # Asks the user a question. Expects a string back.
    #
    # @param default: A default value
    # @param echo: If true (the default), we echo what the user types
    #        to the screen. If false, we do NOT echo.
    def Ask.for_string(message, opts={})
      default = opts.delete(:default)
      echo = opts.has_key?(:echo) ? opts.delete(:echo) : true
      Preconditions.assert_empty_opts(opts)

      final_message = message.dup
      if default
        final_message << " [%s] " % default
      end

      value = nil
      while value.to_s == ""
        print final_message
        input = get_input(echo)
        value = input.to_s.strip
        if value.to_s == "" && default
          value = default.to_s.strip
        elsif input.nil?
          # Standard input is closed (a pipe, /dev/null, a CI job): asking
          # again reads nothing again, forever.
          puts ""
          raise "No input for[%s]: standard input is closed" % message.strip
        end
      end
      value
    end

    # Asks the user a question. Returns a boolean. Boolean is defined as
    # matching the strings 'y' or 'yes', case insensitive
    def Ask.for_boolean(message)
      value = Ask.for_string("%s (y/n) " % message)
      TRUE_STRINGS.include?(value.downcase)
    end

    def Ask.for_password(message)
      Ask.for_string(message, :echo => false)
    end

    # here to help with tests
    def Ask.get_input(echo)
      if echo
        STDIN.gets
      else
        settings = `stty -g`.strip
        begin
          `stty -echo`
          input = STDIN.gets
          puts ""
        ensure
          system("stty", settings)
        end
        input
      end
    end

  end

end
