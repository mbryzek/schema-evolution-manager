module SchemaEvolutionManager
  # Adapter for what we need to remove dependency on RDoc which was removed in ruby 1.9
  class RdocUsage

    def RdocUsage.message
      path = Library.normalize_path(RdocUsage.program_name)

      lines = []

      IO.readlines(path).each do |line|
        if !line.match(/^\#/)
          break
        end
        if line.match(/^\#\!/)
          next
        end
        lines << line.sub(/^\#\s?/, '').sub(/\n$/, '')
      end
      lines << ""

      lines.join("\n")
    end

    def RdocUsage.printAndExit(exit_code=0)
      puts RdocUsage.message
      exit(exit_code)
    end

    # Exit codes for a command-line fault, one per kind of fault
    unless defined?(MISSING_INPUT)
      # A required argument, subcommand or connection was not given
      MISSING_INPUT = 3
      # An argument was given that the command does not accept
      INVALID_INPUT = 4
      # The input was well formed and running it failed
      FAILED = 1
    end

    # A command-line fault: one "ERROR: <message>" line on stderr, then
    # any detail lines (and the command's usage, with :usage => true),
    # then exit with exit_code. Never writes to stdout, so a wrapper that
    # captures stdout (TAG=$(sem-info tag next minor)) captures no error.
    def RdocUsage.error!(message, exit_code, opts={})
      details = opts.delete(:details) || []
      usage = opts.delete(:usage)
      Preconditions.assert_empty_opts(opts)
      Preconditions.check_state([MISSING_INPUT, INVALID_INPUT, FAILED].include?(exit_code), "Invalid exit_code[%s]" % exit_code)

      $stderr.puts "ERROR: %s" % message
      details.each { |line| $stderr.puts line }
      if usage
        $stderr.puts ""
        $stderr.puts RdocUsage.message
      end
      exit(exit_code)
    end

    private
    def RdocUsage.program_name
      $0
    end


  end

end
