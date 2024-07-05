module SchemaEvolutionManager

  class ApplyUtil

    def initialize(db, opts={})
      @dry_run = opts.delete(:dry_run)
      if @dry_run.nil?
        @dry_run = true
      end

      @db = Preconditions.assert_class(db, Db)
      @scripts = Scripts.new(@db, Scripts::SCRIPTS)
    end

    def dry_run?
      @dry_run
    end

    # Applies scripts in order, returning number of scripts applied
    def apply!(dir)
      Preconditions.check_state(File.directory?(dir),
                                "Dir[%s] does not exist" % dir)

      pending_scripts = []
      @scripts.each_pending(dir) do |filename, path|
        pending_scripts << [filename, path]
      end

      if pending_scripts.size > 1
        puts "WARNING: You are about to apply more than 1 script:"
        pending_scripts.each do |filename, path|
          puts "  #{filename}"
        end
        continue = SchemaEvolutionManager::Ask.for_boolean("Are you sure?")
        if !continue
          puts "Wise choice."
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
