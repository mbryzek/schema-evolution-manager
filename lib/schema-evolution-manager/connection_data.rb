module SchemaEvolutionManager

  class ConnectionData

    DEFAULT_PORT = 5432 unless defined?(DEFAULT_PORT)

    attr_reader :host, :name, :port, :user, :password

    def initialize(host, name, opts={})
      @host = host
      @name = name

      port = opts.delete(:port).to_s
      if port.to_s.empty?
        @port = DEFAULT_PORT
      else
        @port = port.to_i
      end
      Preconditions.check_argument(@port > 0, "Port must be > 0")

      @user = opts.delete(:user)
      @password = opts.delete(:password)
      Preconditions.assert_empty_opts(opts)
    end

    # Returns a valid pgpass line entry representing this connection.
    # The name parsed from a url can carry query parameters
    # (?sslmode=require), which libpq does not match on, so they are dropped.
    #
    # @param password: Optional password to include in the connection string
    def pgpass(password=nil)
      database = @name.to_s.split("?", 2).first
      [@host, @port, database, @user, password].map { |v| ConnectionData.pgpass_escape(v) }.join(":")
    end

    # libpq reads ':' as the pgpass field separator and '\' as its escape,
    # so both must be backslash-escaped within a field.
    def ConnectionData.pgpass_escape(value)
      value.to_s.gsub(/[\\:]/) { |c| "\\#{c}" }
    end

    # Returns the url with any password removed from it. The username is
    # kept so that libpq still selects the matching pgpass entry.
    #
    # @param url e.g. postgres://user:pass@db.com:5553/test_db
    def ConnectionData.strip_password(url)
      ConnectionData.rebuild_lead(url) { |user, _password| user }
    end

    # Returns the url with any password replaced by [REDACTED], for display.
    def ConnectionData.redact(url)
      ConnectionData.rebuild_lead(url) { |user, password| password.nil? ? user : "#{user}:[REDACTED]" }
    end

    # Parses a connection string into a ConnectionData instance. You
    # will get an error if the URL could not be parsed. A password in the
    # url is percent-decoded, as libpq does, and never appears in an error.
    #
    # @param url e.g. postgres://user1@db.com:5553/test_db
    def ConnectionData.parse_url(url)
      display = ConnectionData.redact(url)
      protocol, rest = url.split("//", 2)
      if rest.nil?
        raise "Invalid url[%s]. Expected to start with postgres://" % display
      end

      lead, name = rest.split("/", 2)
      if name.nil?
        raise "Invalid url[%s]. Missing database name" % display
      end

      userinfo, db_host = ConnectionData.split_lead(lead)
      user, password = ConnectionData.split_userinfo(userinfo)

      host, port = db_host.split(":", 2)
      if port
        if port.to_i.to_s != port
          raise "Invalid url[%s]. Expected database port[%s] to be an integer" % [display, port]
        end
      end

      ConnectionData.new(host, name, :user => user && ConnectionData.percent_decode(user),
                         :password => password && ConnectionData.percent_decode(password), :port => port)
    end

    # Splits "userinfo@host:port" on the LAST '@', since an unencoded
    # password may itself contain one. Returns [userinfo or nil, host:port]
    def ConnectionData.split_lead(lead)
      index = lead.rindex("@")
      index.nil? ? [nil, lead] : [lead[0...index], lead[(index + 1)..-1]]
    end

    # Splits "user:password" on the FIRST ':'. Returns [user, password or nil]
    def ConnectionData.split_userinfo(userinfo)
      return [nil, nil] if userinfo.nil?
      user, password = userinfo.split(":", 2)
      [user, password]
    end

    def ConnectionData.percent_decode(value)
      value.gsub(/%([0-9A-Fa-f]{2})/) { $1.hex.chr }
    end

    # Yields [user, password] from the url's userinfo and returns the url
    # with the userinfo replaced by the block's result. A url with no
    # userinfo is returned unchanged.
    def ConnectionData.rebuild_lead(url)
      protocol, rest = url.split("//", 2)
      return url if rest.nil?
      lead, name = rest.split("/", 2)
      userinfo, db_host = ConnectionData.split_lead(lead)
      return url if userinfo.nil?
      user, password = ConnectionData.split_userinfo(userinfo)
      new_userinfo = yield(user, password)
      new_lead = new_userinfo.to_s.empty? ? db_host : "#{new_userinfo}@#{db_host}"
      name.nil? ? "#{protocol}//#{new_lead}" : "#{protocol}//#{new_lead}/#{name}"
    end

  end

end
