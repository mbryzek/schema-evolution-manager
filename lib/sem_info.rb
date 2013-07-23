module SemInfo

  def SemInfo.tag(args)
    subcommand = args.shift
    if subcommand == "latest"
      if latest = ::SemInfo::Tag.latest
        latest.to_version_string
      else
        nil
      end
    elsif subcommand == "next"
      ::SemInfo::Tag.next(args).to_version_string
    else
      raise "Invalid tag subcommand[%s]" % [subcommand]
    end
  end

  module Tag

    def Tag.latest
      Library.latest_tag
    end

    # @param component: One of major|minor|micro. Defaults to micro
    def Tag.next(component=nil)
      if component.to_s == ""
        component = "micro"
      end
      latest.send("next_%s" % [component])
    end

  end

end
