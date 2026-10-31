# The pure half of util/create-release.rb: what a release run decides
# before it touches git, kept here so test/specs/util/release_spec.rb can
# drive it without a checkout.
module SchemaEvolutionManager

  module Release

    USAGE = "usage: util/create-release.rb [--apply] [--version x.y.z]" unless defined?(USAGE)

    # The run's options. --apply releases without asking anything: the
    # next micro version (or --version), committed, tagged and pushed to
    # origin. Without it the run asks for the version and pushes nothing.
    def Release.parse_args(argv)
      opts = { :apply => false, :version => nil }
      args = argv.dup
      while arg = args.shift
        case arg
        when "--apply"
          opts[:apply] = true
        when "--version"
          value = args.shift.to_s.strip
          Preconditions.check_state(value != "", "--version needs a value. %s" % USAGE)
          opts[:version] = value
        else
          raise "Unknown argument[%s]. %s" % [arg, USAGE]
        end
      end
      opts
    end

    # The release tags among +tags+ (x.y.z, optionally prefixed), newest
    # last.
    def Release.release_tags(tags)
      tags.select { |t| Version.is_valid?(t) }.map { |t| Version.parse(t) }.sort.map(&:to_version_string)
    end

    # The version to release, or a refusal. +tags_at_head+ are the tags on
    # the commit being released: one that already carries a release tag is
    # released, which is success with nothing to do.
    #
    # Returns [:already, tag], [:release, version] or [:refuse, why].
    def Release.decide(current, tags_at_head, all_tags, requested=nil)
      at_head = Release.release_tags(tags_at_head)
      if !at_head.empty?
        return [:already, at_head.last]
      end

      if requested && !Version.is_valid?(requested)
        return [:refuse, "%s is not a release version (x.y.z)" % requested]
      end
      version = requested ? Version.parse(requested) : Version.parse(current).next_micro
      existing = Release.release_tags(all_tags)
      if existing.include?(version.to_version_string)
        return [:refuse, "%s is already released" % version.to_version_string]
      end
      newest = existing.last
      if newest && (version <=> Version.parse(newest)) <= 0
        return [:refuse, "%s is not newer than the newest release %s" % [version.to_version_string, newest]]
      end
      [:release, version.to_version_string]
    end

    # README.md with its install instructions pointing at +version+, or nil
    # when the README holds no `git checkout x.y.z` line to update.
    def Release.readme_with_version(text, version)
      found = false
      lines = text.lines.map do |l|
        if l.match(/git checkout \d+\.\d+\.\d+$/)
          found = true
          l.sub(/git checkout \d+\.\d+\.\d+$/, "git checkout %s" % version)
        else
          l
        end
      end
      found ? lines.join : nil
    end

    def Release.sem_version_source(version)
      "# File automatically created and updated by util/create-release.rb\n" +
        "module SchemaEvolutionManager\n\n" +
        "module SemVersion\n\n" +
        "VERSION ||= '%s'\n\n" % version +
        "end\n\n" +
        "end\n"
    end

  end

end
