module SchemaEvolutionManager
  class Library

    unless defined?(TMPFILE_DIR)
      # A directory private to this process. Temp file names below are
      # "<prefix>.<counter>", and sem-apply uses a migration's basename as the
      # prefix, so two processes applying the same scripts would otherwise
      # compute the same path and delete each other's copy mid-run. mktmpdir
      # honours TMPDIR and creates the directory mode 0700 with a random name.
      TMPFILE_DIR = Dir.mktmpdir("schema-evolution-manager-")
      TMPFILE_PREFIX = "schema-evolution-manager-#{Process.pid}.tmp"
      tmpfile_dir_owner = Process.pid
      at_exit { FileUtils.rm_rf(TMPFILE_DIR) if Process.pid == tmpfile_dir_owner }
    end
    @@tmpfile_count = 0
    @@verbose = false

    # Creates the dir if it does not already exist
    def Library.ensure_dir!(dir)
      Preconditions.assert_class(dir, String)

      if !File.directory?(dir)
        Library.system_or_error(["mkdir", "-p", "--", dir])
      end
      Library.assert_dir_exists(dir)
    end

    def Library.assert_dir_exists(dir)
      Preconditions.assert_class(dir, String)

      if !File.directory?(dir)
        raise "Dir[#{dir}] does not exist"
      end
    end

    def Library.format_time(timestamp=Time.now)
      timestamp.strftime('%Y-%m-%d %H:%M:%S %Z')
    end

    def Library.git_assert_tag_exists(tag)
      command = ["git", "tag", "-l"]
      results = Library.system_or_error(command)
      if results.nil?
        raise "No git tags found"
      end

      if !Library.tag_exists?(tag)
        raise "Tag[#{tag}] not found. Check #{Shellwords.join(command)}"
      end
    end

    def Library.assert_valid_tag(tag)
      Preconditions.check_state(Version.is_valid?(tag), "Invalid tag[%s]. Format must be x.x.x (e.g. 1.1.2)" % tag)
    end

    def Library.git_has_remote?
      system("git config --get remote.origin.url")
    end

    # Fetches the latest tag from the git repo. Returns nil if there are
    # no tags, otherwise returns an instance of Version. Only searches for
    # tags matching x.x.x (e.g. 1.0.2)
    def Library.latest_tag
      `git tag -l`.strip.split.select { |tag| Version.is_valid?(tag) }.map { |tag| Version.parse(tag) }.sort.last
    end

    def Library.tag_exists?(tag)
      `git tag -l`.strip.include?(tag)
    end

    # Ex: Library.git_create_tag("0.0.1")
    def Library.git_create_tag(tag)
      Library.assert_valid_tag(tag)
      has_remote = Library.git_has_remote?
      if has_remote
        Library.system_or_error(["git", "fetch", "--tags", "origin"])
      end
      Library.system_or_error(["git", "tag", "-a", "-m", tag, tag])
      if has_remote
        Library.system_or_error(["git", "push", "--tags", "origin"])
      end
    end

    # Generates a temp file name, yield the full path to the
    # file. Cleans up automatically on exit.
    def Library.with_temp_file(opts={})
      prefix = opts.delete(:prefix)
      Preconditions.assert_empty_opts(opts)

      if prefix.to_s == ""
        prefix = TMPFILE_PREFIX
      end
      path = File.join(TMPFILE_DIR, "%s.%s" % [prefix, @@tmpfile_count])
      @@tmpfile_count += 1
      yield path
    ensure
      Library.delete_file_if_exists(path)
    end

    def Library.delete_file_if_exists(path)
      if File.exist?(path)
        FileUtils.rm_r(path)
      end
    end

    # Writes the string to a temp file, yielding the path. Cleans up on
    # exit.
    def Library.write_to_temp_file(string)
      Library.with_temp_file do |path|
        File.open(path, "w") do |out|
          out << string
        end
        yield path
      end
    end

    # Returns the relative path to the base directory (root of this git
    # repo)
    def Library.base_dir
      @@base_dir
    end

    def Library.set_base_dir(value)
      Preconditions.check_state(File.directory?(value), "Dir[%s] not found" % value)
      @@base_dir = Library.normalize_path(value)
    end

    # Runs the command, raising an error if it exits non-zero, and
    # returns its standard output, stripped. Standard error passes
    # through to ours.
    #
    # The command is an argv array, executed directly and never through a
    # shell, so a path or value holding a space, a quote or a dollar sign
    # reaches the program as exactly one argument:
    #
    #   Library.system_or_error(["mv", "--", file, target])
    #
    # @param env: Optional hash of environment variables set for the command
    # @param log: Optional array shown in place of the command when
    #        logging or raising, for a command carrying a secret
    def Library.system_or_error(command, opts={})
      env = opts.delete(:env) || {}
      log = opts.delete(:log) || command
      Preconditions.assert_empty_opts(opts)
      Preconditions.assert_class(command, Array)
      Preconditions.check_state(!command.empty?, "command cannot be empty")
      Preconditions.check_state(command.all? { |arg| arg.is_a?(String) }, "every argument must be a String: %s" % command.inspect)

      display = Library.command_to_s(log, env)
      if Library.is_verbose?
        puts display
      end

      begin
        result, status = Open3.capture2(env, *command)
      rescue SystemCallError => e
        raise "Error running command[%s]: %s" % [display, e.to_s]
      end
      if !status.success?
        raise "Non zero exit code[%s] running command[%s]" % [status, display]
      end
      result.strip
    end

    # A shell-quoted rendering of an argv, for logs and error messages
    def Library.command_to_s(command, env={})
      (env.map { |k, v| "%s=%s" % [k, Shellwords.escape(v)] } + [Shellwords.join(command)]).join(" ")
    end

    def Library.normalize_path(path)
      Pathname.new(path).cleanpath.to_s
    end

    def Library.is_verbose?
      @@verbose
    end

    def Library.set_verbose(value)
      @@verbose = value ? true : false
    end

    # Returns a formatted string of git commits made since the specified tag.
    def Library.git_changes(opts={})
      tag = opts.delete(:tag)
      number_changes = opts.delete(:number_changes) || 10
      Preconditions.check_state(number_changes > 0)
      Preconditions.assert_empty_opts(opts)

      git_log_command = ["git", "log", "--pretty=format:%h %ad | %s%d [%an]", "--date=short", "-#{number_changes}"]
      git_log = Library.system_or_error(git_log_command)
      out = ""
      out << "Created: %s\n" % Library.format_time
      if tag
        out << "Git Tag: %s\n" % tag
      end
      out << "\n"
      out << "%s:\n" % Library.command_to_s(git_log_command)
      out << "  " << git_log.split("\n").join("\n  ") << "\n"
      out
    end

    @@base_dir = Library.normalize_path(File.join(File.dirname(__FILE__), ".."))
  end

end
