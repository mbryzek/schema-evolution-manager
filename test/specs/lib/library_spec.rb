load File.join(File.dirname(__FILE__), '../../init.rb')

describe Library do

  def create_repo_with_commit
    TestUtils.in_test_repo do
      Library.system_or_error('echo "Test" > README.md')
      Library.system_or_error("git add README.md && git commit -m 'testlogmessage' README.md")
      yield
    end
  end

  it "Library.ensure_dir!" do
    Library.with_temp_file do |tmpdir|
      Library.ensure_dir!(tmpdir)
      Library.assert_dir_exists(tmpdir)
    end
  end

  it "Library.assert_dir_exists" do
    Library.with_temp_file do |tmpdir|
      Library.system_or_error("rm -rf #{tmpdir}")
      lambda {
        Library.assert_dir_exists(tmpdir)
      }.should raise_error(RuntimeError)
      Library.system_or_error("mkdir #{tmpdir}")
      Library.assert_dir_exists(tmpdir)
    end
  end

  it "Library.format_time" do
    Library.format_time.match(/^\d+\-\d+\-\d+ \d+\:\d+\:\d+/)
  end

  it "Library.git_has_remote?" do
    Library.git_has_remote?.should be_true
    Library.with_temp_file do |tmp|
      Library.system_or_error("git init #{tmp}")
      Dir.chdir(tmp) do
        Library.git_has_remote?.should be_false
      end
    end
  end

  it "Library.git_assert_tag_exists" do
    Library.git_assert_tag_exists("0.0.1")
    lambda {
      Library.git_assert_tag_exists("0.0.0")
    }.should raise_error(RuntimeError)
  end

  describe "Library.assert_valid_tag" do

    it "valid" do
      Library.assert_valid_tag("0.0.0")
      Library.assert_valid_tag("0.0.1")
      Library.assert_valid_tag("0.1.0")
      Library.assert_valid_tag("1.0.0")
    end

    it "invalid" do
      ['-1.0.0', 'r20120101.1'].each do |tag|
        puts "TAG: #{tag}"
        lambda {
          Library.assert_valid_tag(tag)
        }.should raise_error(RuntimeError)
      end
    end

  end

  describe "Library.git_create_tag" do

    it "with valid tag" do
      Library.should_receive(:system_or_error).at_least(:once)
      Library.git_create_tag("0.0.5")
    end

    it "with invalid tag" do
      Library.should_not_receive(:system_or_error)
      lambda {
        Library.git_create_tag("foo")
      }.should raise_error(RuntimeError)
    end

  end

  it "Library.git_user" do
    user = Library.git_user
    if user == ""
      raise "git global user configuration not set - unit test cannot pass"
    end
  end

  it "Library.with_temp_file" do
    file = nil
    Library.with_temp_file do |tmp|
      Library.system_or_error("touch #{tmp}")
      File.exists?(tmp).should be_true
      file = tmp
    end
    File.exists?(file).should be_false
  end

  it "Library.write_to_temp_file" do
    Library.write_to_temp_file("test") do |path|
      IO.read(path).should == "test"
    end
  end

  it "Library.base_dir" do
    File.directory?(Library.base_dir).should be_true
    File.directory?(File.join(Library.base_dir, "bin")).should be_true
    File.directory?(File.join(Library.base_dir, "lib")).should be_true
  end

  describe "Library.system_or_error" do

    it "success" do
      Library.system_or_error("echo 'hey'")
    end

    it "failure" do
      lambda {
        Library.system_or_error('/adfadfds')
      }.should raise_error(RuntimeError)
    end

  end

  describe "Library.system_or_error" do
    it "success" do
      Library.system_or_error("echo 'hey'")
    end

    it "failure" do
      lambda {
        Library.system_or_error('/adfadfds')
      }.should raise_error(RuntimeError)
    end
  end

  it "Library.normalize_path" do
    Library.normalize_path("/tmp").should == "/tmp"
    Library.normalize_path("././tmp").should == "tmp"
  end

  it "Library.is_verbose?" do
    Library.is_verbose?.should be_false
    Library.set_verbose(true)
    Library.is_verbose?.should be_true
    Library.set_verbose(false)
    Library.is_verbose?.should be_false
  end

  describe "Library.git_changes" do

    it "from HEAD" do
      create_repo_with_commit do
        history = Library.git_changes
        history.size.should > 0
        history.index("testlogmessage").should > 0
      end
    end

    it "with tag" do
      tag = "0.0.1"
      create_repo_with_commit do
        1.upto(5) do |i|
          file = "%s.txt" % [i]
          File.open(file, "w") { |out| out << "test" }
          Library.system_or_error("git add %s && git commit -m 'commit%s' %s" % [file, i, file])
        end
        Library.git_create_tag(tag)
        history = Library.git_changes(:tag => tag, :number_changes => 2)
        history.index(tag).should > 0
        history.index("commit5").should > 0
        history.index("commit4").should > 0
        history.index("commit3").should be_nil
        history.index("commit2").should be_nil
        history.index("commit1").should be_nil
        history.index("testlogmessage").should be_nil
      end
    end

  end

  describe "Library.latest_tag" do

    it "returns nil if no tags" do
      TestUtils.in_test_repo do
        Library.latest_tag.should be_nil
      end
    end

    it "returns nil if invalid tags only" do
      create_repo_with_commit do
        Library.system_or_error("git tag -a -m 'test' test")
        Library.latest_tag.should be_nil
      end
    end

    it "finds single tag" do
      create_repo_with_commit do
        Library.git_create_tag("0.0.1")
        Library.latest_tag.to_version_string.should == "0.0.1"
      end
    end

    it "finds proper latest tag" do
      create_repo_with_commit do
        Library.git_create_tag("0.0.1")
        Library.latest_tag.to_version_string.should == "0.0.1"

        Library.git_create_tag("0.1.0")
        Library.latest_tag.to_version_string.should == "0.1.0"
      end
    end

  end


end
