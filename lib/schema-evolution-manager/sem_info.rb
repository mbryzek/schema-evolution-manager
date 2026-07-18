module SchemaEvolutionManager

  module SemInfo

    def SemInfo.version(args=nil)
      SchemaEvolutionManager::SemVersion::VERSION.dup
    end

    def SemInfo.db(args)
      valid = ['version', 'scripts']
      subcommand = args.shift.to_s.strip

      if !valid.include?(subcommand)
        if subcommand.empty?
          $stderr.puts "ERROR: Missing db subcommand. Must be one of: %s" % valid.join(", ")
        else
          $stderr.puts "ERROR: Invalid db subcommand[%s]. Must be one of: %s" % [subcommand, valid.join(", ")]
        end
        exit(4)
      end

      db_args = SchemaEvolutionManager::Args.new(args.join(" "), :optional => ['url', 'host', 'user', 'name', 'port', 'set'])

      if db_args.url.to_s.strip.empty? && db_args.name.to_s.strip.empty?
        $stderr.puts "ERROR: Missing database connection. Provide --url <postgres url> or --host/--name."
        exit(3)
      end

      # A common mistake is passing a bare database name to --url. Catch it with
      # an actionable hint instead of letting parse_url raise a raw backtrace.
      if db_args.url && !db_args.url.include?("://")
        $stderr.puts "ERROR: --url must be a full connection string (e.g. postgres://localhost:5432/%s). To connect by database name, use --name %s." % [db_args.url, db_args.url]
        exit(3)
      end

      begin
        db = SchemaEvolutionManager::Db.from_args(db_args)
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
        $stderr.puts "ERROR: %s" % e.message.to_s.split("\n").first
        exit(3)
      end
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
          puts "ERROR: Invalid component[%s]. Must be one of: %s" % [component, valid.join(", ")]
          exit(4)
        end
      end

    end

  end

end
