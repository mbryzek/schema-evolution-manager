module SchemaEvolutionManager

  class Version

    VERSION_FILE = File.join(Library.base_dir, "VERSION") unless defined?(VERSION_FILE)

    attr_reader :major, :minor, :micro

    def initialize(major, minor, micro, opts={})
      @major = major.to_i
      @minor = minor.to_i
      @micro = micro.to_i
      @prefix = opts.delete(:prefix) || nil
      if !opts.empty?
        raise "Invalid keys: " + opts.keys
      end
    end

    def Version.parse(version_string)
      Preconditions.check_not_blank(version_string, "version_string cannot be blank")
      Library.assert_valid_tag(version_string)
      if md = version_string.match(/^(\w*)(\d+)\.(\d+)\.(\d+)$/)
        Version.new(md[2], md[3], md[4], :prefix => md[1])
      else
        raise "ERROR: Bug in version string parser for version[%s]" % version_string
      end
    end

    def to_version_string
      "%s%s.%s.%s" % [@prefix, major, minor, micro]
    end

    # Returns the next major version
    def next_major
      Version.new(major+1, 0, 0, :prefix => @prefix)
    end

    # Returns the next minor version
    def next_minor
      Version.new(major, minor+1, 0, :prefix => @prefix)
    end

    # Returns the next micro version
    def next_micro
      Version.new(major, minor, micro+1, :prefix => @prefix)
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
      Preconditions.check_state(File.exists?(VERSION_FILE), "Version file at path[%s] not found" % VERSION_FILE)
      version = IO.read(VERSION_FILE).strip
      Version.parse(version)
    end

    def Version.write(version)
      Preconditions.assert_class(version, Version)
      File.open(VERSION_FILE, "w") do |out|
        out << "%s\n" % version.to_version_string
      end
    end

    def Version.is_valid?(version_string)
      Preconditions.check_not_blank(version_string, "version_string cannot be blank")
      version_string.match(/^\w*\d+\.\d+\.\d+$/)
    end

  end

end
