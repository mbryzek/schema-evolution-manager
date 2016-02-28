module SchemaEvolutionManager

  class BaselineUtil

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

      count = 0
      @scripts.each_pending(dir) do |filename, path|
        count += 1
        if @dry_run
          puts "[DRY RUN] Baselining #{filename}"
          apply_dry_run(filename, path)
        else
          puts "Baselining #{filename}"
          apply_real(filename, path)
        end
      end
      count
    end

    private
    def apply_dry_run(filename, path)
      puts path
      puts ""
    end

    def apply_real(filename, path)
      @scripts.record_as_run!(filename)
    end

  end

end
