load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Library do

  def create_repo_with_commit
    TestUtils.in_test_repo do
      TestUtils.sh('echo "Test" > README.md')
      TestUtils.sh("git add README.md && git commit -m 'testlogmessage' README.md")
      yield
    end
  end

  it "SchemaEvolutionManager::Library.ensure_dir!" do
    SchemaEvolutionManager::Library.with_temp_file do |tmpdir|
      SchemaEvolutionManager::Library.ensure_dir!(tmpdir)
      SchemaEvolutionManager::Library.assert_dir_exists(tmpdir)
    end
  end

  it "SchemaEvolutionManager::Library.assert_dir_exists" do
    SchemaEvolutionManager::Library.with_temp_file do |tmpdir|
      TestUtils.sh("rm -rf #{tmpdir}")
      lambda {
        SchemaEvolutionManager::Library.assert_dir_exists(tmpdir)
      }.should raise_error(RuntimeError)
      TestUtils.sh("mkdir #{tmpdir}")
      SchemaEvolutionManager::Library.assert_dir_exists(tmpdir)
    end
  end

  it "SchemaEvolutionManager::Library.format_time" do
    SchemaEvolutionManager::Library.format_time.match(/^\d+\-\d+\-\d+ \d+\:\d+\:\d+/)
  end

  it "SchemaEvolutionManager::Library.git_has_remote?" do
    SchemaEvolutionManager::Library.git_has_remote?.should be true
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      TestUtils.sh("git init #{tmp}")
      Dir.chdir(tmp) do
        SchemaEvolutionManager::Library.git_has_remote?.should be false
      end
    end
  end

  describe "SchemaEvolutionManager::Library.assert_valid_tag" do

    it "valid" do
      SchemaEvolutionManager::Library.assert_valid_tag("0.0.0")
      SchemaEvolutionManager::Library.assert_valid_tag("0.0.1")
      SchemaEvolutionManager::Library.assert_valid_tag("0.1.0")
      SchemaEvolutionManager::Library.assert_valid_tag("1.0.0")
    end

    it "invalid" do
      ['-1.0.0', 'r20120101.1'].each do |tag|
        puts "TAG: #{tag}"
        lambda {
          SchemaEvolutionManager::Library.assert_valid_tag(tag)
        }.should raise_error(RuntimeError)
      end
    end

  end

  describe "SchemaEvolutionManager::Library.git_create_tag" do

    it "with valid tag" do
      SchemaEvolutionManager::Library.should_receive(:system_or_error).at_least(:once)
      SchemaEvolutionManager::Library.git_create_tag("0.0.5")
    end

    it "with invalid tag" do
      SchemaEvolutionManager::Library.should_not_receive(:system_or_error)
      lambda {
        SchemaEvolutionManager::Library.git_create_tag("foo")
      }.should raise_error(RuntimeError)
    end

  end

  describe "SchemaEvolutionManager::Library.with_temp_file" do

    it "no args" do
      file = nil
      SchemaEvolutionManager::Library.with_temp_file do |tmp|
        TestUtils.sh("touch #{tmp}")
        File.exist?(tmp).should be true
        file = tmp
      end
      File.exist?(file).should be false
    end

    it "respects prefix" do
      SchemaEvolutionManager::Library.with_temp_file(:prefix => "thisisaprefix") do |tmp|
        File.basename(tmp).split(".", 2).first.should == "thisisaprefix"
        File.dirname(tmp).should == SchemaEvolutionManager::Library::TMPFILE_DIR
      end
    end

    it "is private to this process" do
      dir = SchemaEvolutionManager::Library::TMPFILE_DIR
      File.directory?(dir).should be true
      (File.stat(dir).mode & 0777).should == 0700
      dir.should_not == "/tmp"
    end

    it "does not collide with another process using the same prefix" do
      lib = File.expand_path("../../../lib/schema-evolution-manager.rb", File.dirname(__FILE__))
      script = "load %s; SchemaEvolutionManager::Library.with_temp_file(:prefix => 'x.sql') { |t| print t }" % lib.inspect
      other = `ruby -e #{Shellwords.escape(script)}`
      SchemaEvolutionManager::Library.with_temp_file(:prefix => "x.sql") do |tmp|
        other.should_not == ""
        tmp.should_not == other
      end
    end

  end

  it "SchemaEvolutionManager::Library.delete_file_if_exists" do
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      File.exist?(tmp).should be false
      SchemaEvolutionManager::Library.delete_file_if_exists(tmp)

      File.open(tmp, "w") { |out| out << "touch" }
      File.exist?(tmp).should be true
      SchemaEvolutionManager::Library.delete_file_if_exists(tmp)
      File.exist?(tmp).should be false
    end
  end

  it "SchemaEvolutionManager::Library.write_to_temp_file" do
    SchemaEvolutionManager::Library.write_to_temp_file("test") do |path|
      IO.read(path).should == "test"
    end
  end

  it "SchemaEvolutionManager::Library.base_dir" do
    File.directory?(SchemaEvolutionManager::Library.base_dir).should be true
    File.directory?(File.join(SchemaEvolutionManager::Library.base_dir, "bin")).should be true
    File.directory?(File.join(SchemaEvolutionManager::Library.base_dir, "lib")).should be true
  end

  describe "SchemaEvolutionManager::Library.system_or_error" do

    it "returns stripped standard output" do
      SchemaEvolutionManager::Library.system_or_error(["echo", "hey"]).should == "hey"
    end

    it "raises on a missing executable" do
      lambda {
        SchemaEvolutionManager::Library.system_or_error(["/adfadfds"])
      }.should raise_error(RuntimeError)
    end

    it "raises on a non zero exit code" do
      lambda {
        SchemaEvolutionManager::Library.system_or_error(["false"])
      }.should raise_error(RuntimeError, /Non zero exit code/)
    end

    it "refuses a shell command line" do
      lambda {
        SchemaEvolutionManager::Library.system_or_error("echo hey")
      }.should raise_error(RuntimeError)
    end

    it "passes each argument through without a shell" do
      value = "a b'c\"$HOME;`id`*"
      SchemaEvolutionManager::Library.system_or_error(["printf", "%s", value]).should == value
    end

    it "sets env" do
      SchemaEvolutionManager::Library.system_or_error(["/bin/sh", "-c", "echo $SEM_TEST"], :env => { "SEM_TEST" => "x y" }).should == "x y"
    end

    it "names the log form in an error, not the command" do
      lambda {
        SchemaEvolutionManager::Library.system_or_error(["false", "secret"], :log => ["false", "[REDACTED]"])
      }.should raise_error(RuntimeError, /REDACTED/) { |e| e.message.should_not include("secret") }
    end

  end

  it "SchemaEvolutionManager::Library.command_to_s" do
    SchemaEvolutionManager::Library.command_to_s(["mv", "a b", "it's"]).should == "mv a\\ b it\\'s"
    SchemaEvolutionManager::Library.command_to_s(["tar"], "A" => "1").should == "A=1 tar"
  end

  it "SchemaEvolutionManager::Library.ensure_dir! with an awkward path" do
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      dir = File.join(tmp, TestUtils::AWKWARD_DIRNAME, "nested")
      SchemaEvolutionManager::Library.ensure_dir!(dir)
      File.directory?(dir).should be true
    end
  end

  it "SchemaEvolutionManager::Library.normalize_path" do
    SchemaEvolutionManager::Library.normalize_path("/tmp").should == "/tmp"
    SchemaEvolutionManager::Library.normalize_path("././tmp").should == "tmp"
  end

  describe "SchemaEvolutionManager::Library.parse_property" do

    it "splits name and value, stripping whitespace" do
      SchemaEvolutionManager::Library.parse_property("  sem.config.scripts_dir  =  a = b  ", /^sem\.config\./).should == ["scripts_dir", "a = b"]
    end

    it "returns nil when the prefix does not match" do
      SchemaEvolutionManager::Library.parse_property("scripts_dir = a", /^sem\.config\./).should be_nil
    end

    it "returns a nil value without an equals sign" do
      SchemaEvolutionManager::Library.parse_property("-- sem.attribute.transaction", /^\-\-\s+sem\.attribute\./).should == ["transaction"]
    end

  end

  it "SchemaEvolutionManager::Library.is_verbose?" do
    SchemaEvolutionManager::Library.is_verbose?.should be false
    SchemaEvolutionManager::Library.set_verbose(true)
    SchemaEvolutionManager::Library.is_verbose?.should be true
    SchemaEvolutionManager::Library.set_verbose(false)
    SchemaEvolutionManager::Library.is_verbose?.should be false
  end

  describe "SchemaEvolutionManager::Library.git_changes" do

    it "from HEAD" do
      create_repo_with_commit do
        history = SchemaEvolutionManager::Library.git_changes
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
          TestUtils.sh("git add %s && git commit -m 'commit%s' %s" % [file, i, file])
        end
        SchemaEvolutionManager::Library.git_create_tag(tag)
        history = SchemaEvolutionManager::Library.git_changes(:tag => tag, :number_changes => 2)
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

  describe "SchemaEvolutionManager::Library.tag_exists?" do

    it "returns false if no tags" do
      TestUtils.in_test_repo do
        SchemaEvolutionManager::Library.tag_exists?("1.0.1").should be false
      end
    end

    it "matches an exact tag" do
      create_repo_with_commit do
        SchemaEvolutionManager::Library.git_create_tag("1.0.1")
        SchemaEvolutionManager::Library.tag_exists?("1.0.1").should be true
      end
    end

    it "does not match a tag that only contains the name" do
      create_repo_with_commit do
        SchemaEvolutionManager::Library.git_create_tag("1.0.10")
        SchemaEvolutionManager::Library.system_or_error(["git", "tag", "-a", "-m", "test", "v2.0.0"])
        SchemaEvolutionManager::Library.tag_exists?("1.0.10").should be true
        SchemaEvolutionManager::Library.tag_exists?("1.0.1").should be false
        SchemaEvolutionManager::Library.tag_exists?("2.0.0").should be false
      end
    end

  end

  describe "SchemaEvolutionManager::Library.latest_tag" do

    it "returns nil if no tags" do
      TestUtils.in_test_repo do
        SchemaEvolutionManager::Library.latest_tag.should be_nil
      end
    end

    it "returns nil if invalid tags only" do
      create_repo_with_commit do
        TestUtils.sh("git tag -a -m 'test' test")
        SchemaEvolutionManager::Library.latest_tag.should be_nil
      end
    end

    it "finds single tag" do
      create_repo_with_commit do
        SchemaEvolutionManager::Library.git_create_tag("0.0.1")
        SchemaEvolutionManager::Library.latest_tag.to_version_string.should == "0.0.1"
      end
    end

    it "finds proper latest tag" do
      create_repo_with_commit do
        SchemaEvolutionManager::Library.git_create_tag("0.0.1")
        SchemaEvolutionManager::Library.latest_tag.to_version_string.should == "0.0.1"

        SchemaEvolutionManager::Library.git_create_tag("0.1.0")
        SchemaEvolutionManager::Library.latest_tag.to_version_string.should == "0.1.0"
      end
    end

  end


end
