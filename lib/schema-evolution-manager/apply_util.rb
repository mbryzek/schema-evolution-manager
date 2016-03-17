module SchemaEvolutionManager

  class ApplyUtil

    def initialize(db, pgpass_file, opts={})
      @dry_run = opts.delete(:dry_run)
      if @dry_run.nil?
        @dry_run = true
      end

      @db = Preconditions.assert_class(db, Db)
      @scripts = Scripts.new(@db, Scripts::SCRIPTS)
      @pgpass_file = Preconditions.assert_class(pgpass_file, Tempfile)
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
          puts "[DRY RUN] Applying #{filename}"
          apply_dry_run(filename, path)
        else
          puts "Applying #{filename}"
          apply_real(filename, path)
        end
      end
      count
    end

    def with_password_file(password)
      Preconditions.check_not_blank(password, "password cannot be blank")
      puts "Creating temp pgpass at #{@pgpass_file.path}"
      FileUtils.chmod(0600, @pgpass_file.path)
      @pgpass_file.write(@db.generate_pgpass_str(password))
      @pgpass_file.rewind
      ENV['PGPASSFILE'] = @pgpass_file.path
    end

    def destroy_password_file()
      puts "Deleting the temp pgpass file"
      @pgpass_file.unlink
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
          raise ScriptError.new(@db, filename)
        end
      end

      @scripts.record_as_run!(filename)
    end

  end

end
