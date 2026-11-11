module SchemaEvolutionManager

  # Applies the pending scripts of a directory to the scripts table, with
  # a dry run by default. Subclasses name the action (label) and whether
  # each script body is executed (execute?); Scripts#apply_pending! is the
  # loop.
  class PendingScriptsUtil

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
      @scripts.apply_pending!(dir, :execute => execute?, :dry_run => @dry_run, :label => label)
    end

  end

end
