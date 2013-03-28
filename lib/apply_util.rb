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
                              "Dir[%s] does not exist" % [dir])

    count = 0
    @scripts.each_pending(dir) do |filename, path|
      count += 1
      if @dry_run
        puts "[DRY RUN] Applying #{filename}"
        apply_dry_run(filename, path)
      else
        puts "Applying #{filename}"
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
    have_error = true
    begin
      @db.psql_file(path)
      have_error = false
    ensure
      if have_error
        msg = ""
        msg << "ERROR APPLYING SCRIPT #{filename}\n"
        msg << "If this script has previously been applied to this database, you can record it as having run by:\n"
        msg << "  psql --host %s --username %s --command \"insert into %s.%s (filename) values ('%s')\" %s\n" %
          [@db.host, @db.user, Db.schema_name, Scripts::SCRIPTS, filename, @db.name]
        raise msg
      end
    end

    @scripts.record_as_run!(filename)
  end

end
