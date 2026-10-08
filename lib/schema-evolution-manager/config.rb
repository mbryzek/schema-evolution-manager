module SchemaEvolutionManager

  # Repository level configuration, read from a file named .sem. Every
  # command walks up from the current directory to the first .sem; the
  # directory holding it is the base directory. Lines follow the
  # migration file attribute grammar:
  #
  #   sem.config.scripts_dir = schema/scripts
  #
  # Blank lines and lines starting with # are ignored. Paths are
  # relative to the base directory. With no .sem anywhere, the base
  # directory is the start directory and scripts_dir is ./scripts.
  class Config

    unless defined?(FILENAME)
      FILENAME = ".sem"
      PROPERTY_PREFIX = /^sem\.config\./
      DEFAULT_SCRIPTS_DIR = "scripts"
      NAMES = ["scripts_dir"]
    end

    attr_reader :path, :base_dir, :scripts_dir

    # path: the .sem file this config was read from, or nil
    # base_dir: absolute path against which relative paths resolve
    # scripts_dir: scripts directory, relative to base_dir or absolute
    def initialize(path, base_dir, scripts_dir)
      @path = path
      @base_dir = Library.normalize_path(File.expand_path(base_dir))
      @scripts_dir = Library.normalize_path(File.expand_path(scripts_dir, @base_dir))
    end

    def Config.load(start_dir=Dir.pwd)
      Preconditions.assert_class(start_dir, String)
      start = File.expand_path(start_dir)
      Preconditions.check_state(File.directory?(start), "Dir[%s] does not exist" % start)

      if path = Config.find(start)
        Config.parse(path)
      else
        Config.new(nil, start, DEFAULT_SCRIPTS_DIR)
      end
    end

    # Returns the path to the first .sem file found walking up from
    # dir to the filesystem root, or nil if there is none.
    def Config.find(dir)
      current = File.expand_path(dir)
      loop do
        candidate = File.join(current, FILENAME)
        if File.file?(candidate)
          return candidate
        end
        parent = File.dirname(current)
        if parent == current
          return nil
        end
        current = parent
      end
    end

    def Config.parse(path)
      Preconditions.check_state(File.file?(path), "File[%s] does not exist" % path)

      values = {}
      File.foreach(path).each_with_index do |line, index|
        stripped = line.strip
        if stripped.empty? || stripped.start_with?("#")
          next
        end

        location = "File[%s] line %s" % [path, index + 1]
        name, value = Library.parse_property(stripped, PROPERTY_PREFIX)
        Preconditions.check_state(!name.nil? && !value.nil?,
                                  "%s: Invalid line[%s]. Expected sem.config.<name> = <value>" % [location, stripped])
        Preconditions.check_state(NAMES.include?(name),
                                  "%s: Config with name[%s] not found. Must be one of: %s" % [location, name, NAMES.join(" ")])
        Preconditions.check_state(!value.empty?,
                                  "%s: Config[%s] - value cannot be blank" % [location, name])
        Preconditions.check_state(!values.has_key?(name),
                                  "%s: Config[%s] is specified more than once" % [location, name])
        values[name] = value
      end

      Config.new(path, File.dirname(path), values["scripts_dir"] || DEFAULT_SCRIPTS_DIR)
    end

  end

end
