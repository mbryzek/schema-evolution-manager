module SchemaEvolutionManager

  class Version

    VERSION_FILE = File.join(Library.base_dir, "VERSION") unless defined?(VERSION_FILE)

    attr_reader :major, :minor, :micro

    def initialize(version_string)
      Preconditions.check_not_blank(version_string, "version_string cannot be blank")
      Library.assert_valid_tag(version_string)
      pieces = version_string.split(".", 3)
      @major = pieces[0].to_i
      @minor = pieces[1].to_i
      @micro = pieces[2].to_i
    end

    def to_version_string
      "%s.%s.%s" % [major, minor, micro]
    end

    # Returns the next major version
    def next_major
      Version.new("%s.%s.%s" % [major+1, 0, 0])
    end

    # Returns the next minor version
    def next_minor
      Version.new("%s.%s.%s" % [major, minor+1, 0])
    end

    # Returns the next micro version
    def next_micro
      Version.new("%s.%s.%s" % [major, minor, micro+1])
    end

    def <=>(other)
      Preconditions.assert_class(other, Version)
      value = major <=> other.major
      if value == 0
        value = minor <=> other.minor
        if value == 0
          value = micro <=> other.micro
        end
      end
      value
    end

    # Reads the current version (from the VERSION FILE), returning an
    # instance of the Version class
    def Version.read
      Preconditions.check_state(File.exist?(VERSION_FILE), "Version file at path[%s] not found" % VERSION_FILE)
      version = IO.read(VERSION_FILE).strip
      Version.new(version)
    end

    def Version.write(version)
      Preconditions.assert_class(version, Version)
      File.open(VERSION_FILE, "w") do |out|
        out << "%s\n" % version.to_version_string
      end
    end

    def Version.is_valid?(version_string)
      Preconditions.check_not_blank(version_string, "version_string cannot be blank")
      version_string.match(/^\d+\.\d+\.\d+$/)
    end

  end

end
