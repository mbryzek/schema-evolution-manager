module SchemaEvolutionManager

  module SemInfo

    def SemInfo.version(args=nil)
      SchemaEvolutionManager::SemVersion::VERSION.dup
    end

    def SemInfo.tag(args)
      valid = ['exists', 'latest', 'next']

      subcommand = args.shift.to_s.strip

      if subcommand == "exists"
        tag = args.shift.to_s.strip
        if tag.empty?
          puts "ERROR: Missing tag."
          exit(3)
        elsif ::SchemaEvolutionManager::Library.tag_exists?(tag)
          puts "true"
        else
          puts "false"
        end

      elsif subcommand == "latest"
        if latest = ::SchemaEvolutionManager::SemInfo::Tag.latest
          latest.to_version_string
        else
          nil
        end

      elsif subcommand == "next"
        ::SchemaEvolutionManager::SemInfo::Tag.next(args).to_version_string

      elsif subcommand.empty?
        puts "ERROR: Missing tag subcommand. Must be one of: %s" % valid.join(", ")
        exit(3)

      else
        puts "ERROR: Invalid tag subcommand[%s]. Must be one of: %s" % [subcommand, valid.join(", ")]
        exit(4)
      end
    end

    module Tag

      def Tag.latest
        Library.latest_tag || Version.new("0.0.0")
      end

      # @param component: One of major|minor|micro. Defaults to micro. Currently passed in as an array
      def Tag.next(args=nil)
        component = (args || []).first
        valid = ['micro', 'minor', 'major']

        if component.to_s.empty?
          component = "micro"
        end

        if valid.include?(component)
          latest.send("next_%s" % component)
        else
          puts "ERROR: Invalid component[%s]. Must be one of: %s" % [component, valid.join(", ")]
          exit(4)
        end
      end

    end

  end

end
