module SchemaEvolutionManager

  class ScriptError < Exception

    attr_reader :path, :output

    # @param scripts The Scripts instance that records filename as run
    def initialize(scripts, filename, path, output)
      @scripts = Preconditions.assert_class(scripts, Scripts)
      @filename = Preconditions.assert_class(filename, String)
      @path = Preconditions.assert_class(path, String)
      @output = Preconditions.assert_class(output, String)
    end

    # The psql command that records this script as applied: the statement
    # Scripts#record_as_run! executes, in the argv Db#psql_command runs.
    def dml
      db = @scripts.db
      command = db.psql_command_args(@scripts.record_as_run_sql(@filename)) + [db.sanitized_url]
      Library.command_to_s(command)
    end

  end

end
