module SchemaEvolutionManager

  # Records and reads the released repository version applied to a database.
  # The version is written at apply time and the latest row (max id) is the
  # deployed schema version.
  class Versions

    if !defined?(MAX_VERSION_LENGTH)
      MAX_VERSION_LENGTH = 100
    end

    # Validates a version string. Raises RuntimeError with an actionable
    # message if invalid; returns the version if valid.
    def Versions.validate_version!(version)
      Preconditions.assert_class(version, String)
      stripped = version.strip
      if stripped.empty?
        raise "Version cannot be blank"
      end
      if stripped.length > MAX_VERSION_LENGTH
        raise "Version '%s' is %d chars; max %d" % [stripped, stripped.length, MAX_VERSION_LENGTH]
      end
      # Strict whitelist: letters, digits, and . _ + - only. Covers semver
      # (including pre-release/build metadata) and rejects anything unsafe
      # (whitespace, quotes, SQL metacharacters, etc.).
      unless stripped.match(/\A[A-Za-z0-9._+-]+\z/)
        raise "Version '%s' is invalid; only letters, digits, and . _ + - are allowed" % stripped
      end
      stripped
    end

    def initialize(db)
      @db = Preconditions.assert_class(db, Db)
    end

    # Inserts the version only if it differs from the latest recorded value.
    # Returns true if a row was inserted, false if unchanged.
    def record!(version)
      clean = Versions.validate_version!(version)
      return false if latest == clean
      @db.psql_command("insert into %s.versions (version) values ('%s')" % [Db.schema_name, clean])
      true
    end

    # Latest recorded version, or nil if none recorded / table absent.
    def latest
      return nil unless versions_table_exists?
      value = @db.psql_command("select version from %s.versions order by id desc limit 1" % Db.schema_name).strip
      value.empty? ? nil : value
    end

    private

    def versions_table_exists?
      return false unless @db.schema_schema_evolution_manager_exists?
      sql = "select count(*) from information_schema.tables where table_schema = '%s' and table_name = 'versions'" % Db.schema_name
      @db.psql_command(sql).to_i > 0
    end

  end

end
