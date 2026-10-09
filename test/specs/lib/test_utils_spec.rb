require File.expand_path('../../init.rb', __dir__)

describe TestUtils do

  describe "parse_server_url" do

    it "accepts the jdbc url dev db session prints, defaulting the user to postgres" do
      TestUtils.parse_server_url("jdbc:postgresql://localhost:5572/platformdb_sess_i1", "x").should == "postgresql://postgres@localhost:5572/x"
    end

    it "keeps the user and password from the url" do
      TestUtils.parse_server_url("postgres://api:pw@db.example:6000/other", "x").should == "postgresql://api:pw@db.example:6000/x"
    end

    it "reads the user and password from jdbc query parameters" do
      TestUtils.parse_server_url("jdbc:postgresql://localhost:5572/db?user=api&password=pw", "x").should == "postgresql://api:pw@localhost:5572/x"
    end

    it "rejects a url that is not postgres" do
      lambda {
        TestUtils.parse_server_url("mysql://localhost:3306/db", "x")
      }.should raise_error(RuntimeError, /Invalid database server url/)
    end
  end

  describe "server_url" do

    def with_env(values)
      vars = TestUtils::SERVER_URL_VARS + TestUtils::SERVER_HOST_VARS
      saved = vars.map { |v| [v, ENV[v]] }.to_h
      vars.each { |v| ENV.delete(v) }
      values.each { |k, v| ENV[k] = v }
      yield
    ensure
      saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    end

    it "refuses rather than defaulting to a local server" do
      with_env({}) do
        lambda { TestUtils.server_url("x") }.should raise_error(RuntimeError, /SEM_TEST_DB_URL/)
      end
    end

    it "prefers SEM_TEST_DB_URL over CONF_DB_DEV_URL" do
      with_env("SEM_TEST_DB_URL" => "postgresql://a@h1:1/d", "CONF_DB_DEV_URL" => "jdbc:postgresql://h2:2/d") do
        TestUtils.server_url("x").should == "postgresql://a@h1:1/x"
      end
    end

    it "falls back to CONF_DB_DEV_URL" do
      with_env("CONF_DB_DEV_URL" => "jdbc:postgresql://h2:2/d") do
        TestUtils.server_url("x").should == "postgresql://postgres@h2:2/x"
      end
    end

    it "accepts SEM_TEST_SERVER_URL without a database name" do
      with_env("SEM_TEST_SERVER_URL" => "postgresql://postgres@h3:5433/", "CONF_DB_DEV_URL" => "jdbc:postgresql://h2:2/d") do
        TestUtils.server_url("x").should == "postgresql://postgres@h3:5433/x"
      end
    end

    it "falls back to SEM_TEST_PGHOST / SEM_TEST_PGPORT" do
      with_env("SEM_TEST_PGHOST" => "127.0.0.1", "SEM_TEST_PGPORT" => "55001") do
        TestUtils.server_url("x").should == "postgresql://postgres@127.0.0.1:55001/x"
      end
    end
  end

end
