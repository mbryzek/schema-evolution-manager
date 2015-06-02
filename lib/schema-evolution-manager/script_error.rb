module SchemaEvolutionManager

  class ScriptError < Exception

    attr_reader :filename

    def initialize(db, filename)
      @db = Preconditions.assert_class(db, Db)
      @filename = Preconditions.assert_class(filename, String)
    end

    def dml
      "psql --command \"insert into %s.%s (filename) values ('%s')\" %s\n" %
        [Db.schema_name, Scripts::SCRIPTS, filename, @db.url]
    end

  end

end
