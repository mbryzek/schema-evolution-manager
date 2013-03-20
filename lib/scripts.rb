class Scripts

  if !defined?(SCRIPTS)
    SCRIPTS = "scripts"
    BOOTSTRAP_SCRIPTS = "bootstrap_scripts"
    VALID_TABLE_NAMES = [BOOTSTRAP_SCRIPTS, SCRIPTS]
  end

  # @param db Instance of Db class
  # @param table_name Name of the table used to record which scripts
  # we have processed. Will be one of 'scripts' or 'bootstrap_scripts'
  def initialize(db, table_name)
    @db = Preconditions.assert_class(db, Db)
    @table_name = Preconditions.assert_class(table_name, String)
    Preconditions.check_state(VALID_TABLE_NAMES.include?(@table_name),
                              "Invalid table name[%s]. Must be one of: %s" % [@table_name, VALID_TABLE_NAMES.join(", ")])
  end

  # Returns a sorted list of the full file paths to any sql scripts in
  # the specified directory
  def Scripts.all(dir)
    Preconditions.assert_class(dir, String)

    if File.directory?(dir)
      Dir.glob("#{dir}/*.sql").sort
    else
      []
    end
  end

  # For each sql script that needs to be applied to this database,
  # yields a pair of |filename, fullpath| in proper order
  #
  # db = Db.new(host, user, name)
  # scripts = Scripts.new(db)
  # scripts.each_pending do |filename, path|
  #    puts filename
  # end
  def each_pending(dir)
    files = {}
    Scripts.all(dir).each do |path|
      name = File.basename(path)
      files[name] = path
    end

    scripts_previously_run(files.keys).each do |filename|
      files.delete(filename)
    end

    files.keys.sort.each do |filename|
      ## We have to recheck if this script is still pending. Some
      ## upgrade scripts may modify the scripts table themselves. This
      ## is actually useful in cases like when we migrated gilt from
      ## util_schema => schema_evolution_manager schema
      if !has_run?(filename)
        yield filename, files[filename]
      end
    end
  end

  # True if this script has already been applied to the db. False
  # otherwise.
  def has_run?(filename)
    if @db.schema_schema_evolution_manager_exists?
      query = "select count(*) from %s.%s where filename = '%s'" % [Db.schema_name, @table_name, filename]
      @db.psql_command(query).to_i > 0
    else
      false
    end
  end

  # Inserts a record to indiciate that we have loaded the specified file.
  def record_as_run!(filename)
    Preconditions.check_state(filename.match(/^\d\d\d\d\d\d+\-\d\d\d\d\d\d\.sql$/),
                              "Invalid filename[#{filename}]. Must be like: 20120503-173242.sql")
    command = "insert into %s.%s (filename) select '%s' where not exists (select 1 from %s.%s where filename = '%s')" % [Db.schema_name, @table_name, filename, Db.schema_name, @table_name, filename]
    @db.psql_command(command)
  end

  private
  # Fetch the list of scripts that have already been applied to this
  # database.
  def scripts_previously_run(scripts)
    if scripts.empty? || !@db.schema_schema_evolution_manager_exists?
      []
    else
      sql = "select filename from %s.%s where filename in (%s)" % [Db.schema_name, @table_name, "'" + scripts.join("', '") + "'"]
      @db.psql_command(sql).strip.split
    end
  end
end
