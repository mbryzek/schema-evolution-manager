module SchemaEvolutionManager

  class ConnectionData

    DEFAULT_PORT = 5432 unless defined?(DEFAULT_PORT)
    
    attr_reader :host, :name, :port, :user

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
      Preconditions.assert_empty_opts(opts)
    end

    # Returns a valid pgpass line entry representing this connection.
    #
    # @param password: Optional password to include in the connection string
    def pgpass(password=nil)
      [@host, @port, @name, @user, password.to_s].join(":")
    end

    # Parses a connection string into a ConnectionData instance. You
    # will get an error if the URL could not be parsed.
    #
    # @param url e.g. postgres://user1@db.com:5553/test_db
    def ConnectionData.parse_url(url)
      protocol, rest = url.split("//", 2)
      if rest.nil?
        raise "Invalid url[%s]. Expected to start with postgres://" % url
      end
      
      lead, name = rest.split("/", 2)
      if name.nil?
        raise "Invalid url[%s]. Missing database name" % url
      end

      parts = lead.split("@", 2)
      if parts.size == 2
        user = parts[0]
        db_host = parts[1]
      else
        user = nil
        db_host = lead
      end

      host, port = db_host.split(":", 2)
      if port
        if port.to_i.to_s != port
          raise "Invalid url[%s]. Expected database port[%s] to be an integer" % [url, port]
        end
      end

      ConnectionData.new(host, name, :user => user, :port => port)
    end
    
  end

end
