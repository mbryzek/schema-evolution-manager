module SchemaEvolutionManager

  # Container for common args, mainly to have stricter validation on
  # inputs. Tried to use GetoptLong but could not write solid unit
  # tests around it... so we have our own internal simple implementation.
  class Args

    if !defined?(FLAGS_WITH_ARGUMENTS)
      FLAGS_WITH_ARGUMENTS = {
        :artifact_name => "Specifies the name of the artifact. Tag will be appended to this name",
        :user => "Connect to the database as this username instead of the default",
        :host => "Specifies the host name of the machine on which the server is running",
        :port => "Specifies the port on which the server is running",
        :name => "Specifies the name of the database to which to connect",
        :url => "The connection string for the psql database",
        :dir => "Path to a directory",
        :tag => "A git tag (e.g. 0.0.1)",
        :prefix => "Configure installer to use this prefix",
        :set => "Passthrough for postgresql --set argument"
      }

      FLAGS_NO_ARGUMENTS = {
        :password => "Prompt user to enter password for the database user. Password is stored for the duration of the process",
        :dry_run => "Include flag to echo commands that will run without actually executing them",
        :help => "Display help",
        :verbose => "Enable verbose logging of all system calls",
      }
    end

    attr_reader :artifact_name, :host, :port, :name, :prefix, :url, :user, :dir, :dry_run, :tag, :password, :set

    # args: Actual string arguments
    # :required => list of parameters that are required
    # :optional => list of parameters that are optional
    def initialize(args, opts={})
      Preconditions.assert_class_or_nil(args, String)
      required = (opts.delete(:required) || []).map { |flag| format_flag(flag) }
      optional = (opts.delete(:optional) || []).map { |flag| format_flag(flag) }
      Preconditions.assert_class(required, Array)
      Preconditions.assert_class(optional, Array)
      Preconditions.assert_empty_opts(opts)
      Preconditions.check_state(optional.size + required.size > 0,
                                "Must have at least 1 optional or required parameter")

      if !optional.include?(:help)
        optional << :help
      end
      if !optional.include?(:verbose)
        optional << :verbose
      end

      found_arguments = parse_string_arguments(args)
      missing = required.select { |field| blank?(found_arguments[field]) }

      @artifact_name = found_arguments.delete(:artifact_name)
      @host = found_arguments.delete(:host)
      @port = found_arguments.delete(:port)
      @name = found_arguments.delete(:name)
      @prefix = found_arguments.delete(:prefix)
      @url = found_arguments.delete(:url)
      @user = found_arguments.delete(:user)
      @dir = found_arguments.delete(:dir)
      @tag = found_arguments.delete(:tag)
      @set = found_arguments.delete(:set)

      @dry_run = found_arguments.delete(:dry_run)
      @password = found_arguments.delete(:password)
      @help = found_arguments.delete(:help)
      @verbose = found_arguments.delete(:verbose)

      Preconditions.check_state(found_arguments.empty?,
                                "Did not handle all flags: %s" % found_arguments.keys.join(" "))

      if @help
        RdocUsage.printAndExit(0)
      end

      if @verbose
        Library.set_verbose(true)
      end

      if !missing.empty?
        missing_fields_error(required, optional, missing)
      end
    end

    # Hack to minimize bleeding from STDIN. Returns an instance of Args class
    def Args.from_stdin(opts)
      values = ARGV.join(" ")
      Args.new(values, opts)
    end

    private
    def blank?(value)
      value.to_s.strip == ""
    end

    def missing_fields_error(required, optional, fields)
      Preconditions.assert_class(fields, Array)
      Preconditions.check_state(!fields.empty?, "Missing fields cannot be empty")

      title = fields.size == 1 ? "Missing parameter" : "Missing parameters"
      sorted = fields.sort_by { |f| f.to_s }

      puts "**************************************************"
      puts "ERROR: #{title}: #{sorted.join(", ")}"
      puts "**************************************************"
      puts help_parameters("Required parameters", required)
      puts help_parameters("Optional parameters", optional)
      exit(1)
    end

    def help_parameters(title, parameters)
      docs = []
      if !parameters.empty?
        docs << ""
        docs << title
        docs << "-------------------"
        parameters.each do |flag|
          documentation = FLAGS_WITH_ARGUMENTS[flag] || FLAGS_NO_ARGUMENTS[flag]
          Preconditions.check_not_null(documentation, "No documentation found for flag[%s]" % flag)
          docs << "  --#{flag}"
          docs <<  "    " + documentation
          docs <<  ""
        end
      end
      docs.join("\n")
    end


    def parse_string_arguments(args)
      Preconditions.assert_class_or_nil(args, String)
      found = {}
      index = 0
      values = args.to_s.strip.split(/\s+/)
      while index < values.length do
        flag = format_flag(values[index])
        index += 1

        if FLAGS_WITH_ARGUMENTS.has_key?(flag)
          found[flag] = values[index]
          index += 1

        elsif FLAGS_NO_ARGUMENTS.has_key?(flag)
          found[flag] = true

        else
          raise "Unknown flag[%s]" % flag
        end

      end
      found
    end

    # Strip leading dashes and convert to symbol
    def format_flag(flag)
      Preconditions.assert_class(flag, String)
      flag.sub(/^\-\-/, '').to_sym
    end

  end

end
