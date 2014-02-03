class ScriptError

  attr_reader :filename

  def initialize(db, filename)
    @db = Preconditions.assert_class(db, Db)
    @filename = Preconditions.assert_class(filename, String)
  end

  def dml
    "psql --host %s --username %s --command \"insert into %s.%s (filename) values ('%s')\" %s\n" %
      [@db.host, @db.user, Db.schema_name, Scripts::SCRIPTS, filename, @db.name]
  end

end
