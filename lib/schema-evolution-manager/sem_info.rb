module SchemaEvolutionManager

  module SemInfo

    def SemInfo.version(args=nil)
      SchemaEvolutionManager::SemVersion::VERSION.dup
    end

    def SemInfo.db(args)
      valid = ['version', 'scripts']
      subcommand = args.shift.to_s.strip

      if subcommand.empty?
        RdocUsage.error!("Missing db subcommand. Must be one of: %s" % valid.join(", "), RdocUsage::MISSING_INPUT)
      elsif !valid.include?(subcommand)
        RdocUsage.error!("Invalid db subcommand[%s]. Must be one of: %s" % [subcommand, valid.join(", ")], RdocUsage::INVALID_INPUT)
      end

      db_args = SchemaEvolutionManager::Args.new(args, :optional => SchemaEvolutionManager::Db::CONNECTION_FLAGS)

      begin
        db = SchemaEvolutionManager::Db.from_command_line(db_args)
        if subcommand == "version"
          version = SchemaEvolutionManager::Versions.new(db).latest
          if version.nil?
            $stderr.puts "No deployed version recorded"
          else
            puts version
          end
        elsif subcommand == "scripts"
          applied = SchemaEvolutionManager::Scripts.new(db, SchemaEvolutionManager::Scripts::SCRIPTS).applied
          if applied.empty?
            $stderr.puts "No scripts recorded"
          else
            applied.each { |filename| puts filename }
          end
        end
      rescue => e
        # Surface a single clean line (e.g. bad url, unreachable host, missing
        # database) rather than a Ruby stack trace.
        RdocUsage.error!(e.message.to_s.split("\n").first, RdocUsage::FAILED)
      end
    end

    def SemInfo.tag(args)
      valid = ['exists', 'latest', 'next']

      subcommand = args.shift.to_s.strip

      if subcommand == "exists"
        tag = args.shift.to_s.strip
        if tag.empty?
          RdocUsage.error!("Missing tag.", RdocUsage::MISSING_INPUT)
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
        RdocUsage.error!("Missing tag subcommand. Must be one of: %s" % valid.join(", "), RdocUsage::MISSING_INPUT)

      else
        RdocUsage.error!("Invalid tag subcommand[%s]. Must be one of: %s" % [subcommand, valid.join(", ")], RdocUsage::INVALID_INPUT)
      end
    end

    module Tag

      def Tag.latest
        Library.latest_tag || Version.parse("0.0.0")
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
          RdocUsage.error!("Invalid component[%s]. Must be one of: %s" % [component, valid.join(", ")], RdocUsage::INVALID_INPUT)
        end
      end

    end

  end

end
