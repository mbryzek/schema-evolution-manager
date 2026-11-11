module SchemaEvolutionManager

  # Runs each pending script and records it as run.
  class ApplyUtil < PendingScriptsUtil

    private
    def label
      "Applying"
    end

    def execute?
      true
    end

  end

end
