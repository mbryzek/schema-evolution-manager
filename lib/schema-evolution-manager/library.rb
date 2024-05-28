module SchemaEvolutionManager
  class Library

    unless defined?(TMPFILE_DIR)
      TMPFILE_DIR = "/tmp"
      TMPFILE_PREFIX = "schema-evolution-manager-#{Process.pid}.tmp"
    end
    @@tmpfile_count = 0
    @@verbose = false

    # Creates the dir if it does not already exist
    def Library.ensure_dir!(dir)
      Preconditions.assert_class(dir, String)

      if !File.directory?(dir)
        Library.system_or_error("mkdir -p #{dir}")
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
      command = "git tag -l"
      results = Library.system_or_error(command)
      if results.nil?
        raise "No git tags found"
      end

      all_tags = results.strip.split
      if !all_tags.include?(tag)
        raise "Tag[#{tag}] not found. Check #{command}"
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
      `git tag -l`.strip.split.select { |tag| Version.is_valid?(tag) }.map { |tag| Version.new(tag) }.sort.last
    end

    # Ex: Library.git_create_tag("0.0.1")
    def Library.git_create_tag(tag)
      Library.assert_valid_tag(tag)
      has_remote = Library.git_has_remote?
      if has_remote
        Library.system_or_error("git fetch --tags origin")
      end
      Library.system_or_error("git tag -a -m #{tag} #{tag}")
      if has_remote
        Library.system_or_error("git push --tags origin")
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

    # Runs the specified command, raising an error if there is a problem
    # (based on status code of the process executed). Otherwise returns
    # all the output from the script invoked.
    def Library.system_or_error(command)
      if Library.is_verbose?
        puts command
      end

      begin
        result = `#{command}`.strip
        status = $?
        if status.to_i > 0
          raise "Non zero exit code[%s] running command[%s]" % [status, command]
        end
      rescue Exception => e
        raise "Error running command[%s]: %s" % [command, e.to_s]
      end
      result
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

      git_log_command = "git log --pretty=format:\"%h %ad | %s%d [%an]\" --date=short -#{number_changes}"
      git_log = Library.system_or_error(git_log_command)
      out = ""
      out << "Created: %s\n" % Library.format_time
      if tag
        out << "Git Tag: %s\n" % tag
      end
      out << "\n"
      out << "%s:\n" % git_log_command
      out << "  " << git_log.split("\n").join("\n  ") << "\n"
      out
    end

    @@base_dir = Library.normalize_path(File.join(File.dirname(__FILE__), ".."))
  end

end
