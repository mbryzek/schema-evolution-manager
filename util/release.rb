# The pure half of util/create-release.rb: what a release run decides
# before it touches git, kept here so test/specs/util/release_spec.rb can
# drive it without a checkout.
module SchemaEvolutionManager

  module Release

    USAGE = "usage: util/create-release.rb [--apply] [--version x.y.z]" unless defined?(USAGE)

    # The build script create-release.rb's run_tests runs before it tags,
    # relative to the repository root. test/specs/util/release_spec.rb
    # asserts the tree has it, so renaming the script fails the suite
    # rather than the next release.
    BUILD_SCRIPT = "ci/build.fast.sh" unless defined?(BUILD_SCRIPT)

    # The run's options. --apply releases without asking anything: the
    # next micro version (or --version), committed, tagged and pushed to
    # origin. --apply --version V in a checkout whose HEAD already carries
    # tag V publishes that tag instead (Release.decide). Without --apply
    # the run asks for the version and pushes nothing.
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
    # A head that already carries the REQUESTED version's tag is a tag cut
    # by somebody else (devops' rollout tags first, then runs this script
    # in a checkout of that tag): [:publish, version] builds and pushes
    # its gem and brings main's VERSION up to it, rather than reading the
    # tag as a release already made.
    #
    # Returns [:already, tag], [:publish, version], [:release, version] or
    # [:refuse, why].
    def Release.decide(current, tags_at_head, all_tags, requested=nil)
      at_head = Release.release_tags(tags_at_head)
      if requested && !at_head.empty?
        if at_head.include?(requested)
          return [:publish, requested]
        end
        return [:refuse, "HEAD is tagged %s, not the requested %s" % [at_head.join(", "), requested]]
      end
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

    # Whether main, whose VERSION file reads +main_version+, still lags the
    # published +version+ and so needs the version-bump commit.
    def Release.main_lags?(main_version, version)
      (Version.parse(main_version.strip) <=> Version.parse(version)) < 0
    end

    # The versions RubyGems lists for the gem, read from the output of
    # `gem list --remote --exact --all schema-evolution-manager`, whose line
    # is `schema-evolution-manager (0.9.65, 0.9.64, ...)`.
    def Release.published_versions(gem_list_output)
      line = gem_list_output.lines.find { |l| l.start_with?("schema-evolution-manager (") }
      return [] if line.nil?
      line[/\((.*)\)/, 1].to_s.split(",").map { |v| v.strip.split(" ").first }.compact
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
