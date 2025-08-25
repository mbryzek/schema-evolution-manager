module SchemaEvolutionManager

  class ScriptError < Exception

    attr_reader :path, :output

    def initialize(db, filename, path, output)
      @db = Preconditions.assert_class(db, Db)
      @filename = Preconditions.assert_class(filename, String)
      @path = Preconditions.assert_class(path, String)
      @output = Preconditions.assert_class(output, String)
    end

    def dml
      sql_command = "insert into %s.%s (filename) values ('%s')" % [Db.schema_name, Scripts::SCRIPTS, @filename]
      "psql --command \"%s\" %s" % [sql_command, @db.sanitized_url]
    end

  end

end
