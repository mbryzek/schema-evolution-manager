module SchemaEvolutionManager

  class ApplyUtil

    def initialize(db, opts={})
      @dry_run = opts.delete(:dry_run)
      if @dry_run.nil?
        @dry_run = true
      end

      @non_interactive = opts.delete(:non_interactive)
      if @non_interactive.nil?
        @non_interactive = false
      end

      @db = Preconditions.assert_class(db, Db)
      @scripts = Scripts.new(@db, Scripts::SCRIPTS)
    end

    def dry_run?
      @dry_run
    end

    def non_interactive?
      @non_interactive
    end

    # Applies scripts in order, returning number of scripts applied
    def apply!(dir)
      Preconditions.check_state(File.directory?(dir),
                                "Dir[%s] does not exist" % dir)

      pending_scripts = []
      @scripts.each_pending(dir) do |filename, path|
        pending_scripts << [filename, path]
      end

      if pending_scripts.size > 1 && !dry_run? && !non_interactive?
        puts "Please confirm that you would like to apply all (#{pending_scripts.size}) of the pending scripts:"
        pending_scripts.each do |filename, path|
          puts "  #{filename}"
        end
        continue = SchemaEvolutionManager::Ask.for_boolean("Continue?")
        if !continue
          return 0
        end
      end

      pending_scripts.each do |filename, path|
        if @dry_run
          puts "[DRY RUN] Applying #{filename}"
          puts path
          puts ""
        else
          print "Applying #{filename}"
          @db.psql_file(filename, path)
          @scripts.record_as_run!(filename)
          puts " Done"
        end
      end
      pending_scripts.size
    end

  end
end
