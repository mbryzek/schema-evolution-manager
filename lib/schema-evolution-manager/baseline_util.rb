module SchemaEvolutionManager

  # Records each pending script as run without running it.
  class BaselineUtil < PendingScriptsUtil

    private
    def label
      "Baselining"
    end

    def execute?
      false
    end

  end

end
