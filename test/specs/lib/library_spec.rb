load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Library do

  def create_repo_with_commit
    TestUtils.in_test_repo do
      SchemaEvolutionManager::Library.system_or_error('echo "Test" > README.md')
      SchemaEvolutionManager::Library.system_or_error("git add README.md && git commit -m 'testlogmessage' README.md")
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
      SchemaEvolutionManager::Library.system_or_error("rm -rf #{tmpdir}")
      lambda {
        SchemaEvolutionManager::Library.assert_dir_exists(tmpdir)
      }.should raise_error(RuntimeError)
      SchemaEvolutionManager::Library.system_or_error("mkdir #{tmpdir}")
      SchemaEvolutionManager::Library.assert_dir_exists(tmpdir)
    end
  end

  it "SchemaEvolutionManager::Library.format_time" do
    SchemaEvolutionManager::Library.format_time.match(/^\d+\-\d+\-\d+ \d+\:\d+\:\d+/)
  end

  it "SchemaEvolutionManager::Library.git_has_remote?" do
    SchemaEvolutionManager::Library.git_has_remote?.should be_true
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      SchemaEvolutionManager::Library.system_or_error("git init #{tmp}")
      Dir.chdir(tmp) do
        SchemaEvolutionManager::Library.git_has_remote?.should be_false
      end
    end
  end

  it "SchemaEvolutionManager::Library.git_assert_tag_exists" do
    SchemaEvolutionManager::Library.git_assert_tag_exists("0.9.0")
    lambda {
      SchemaEvolutionManager::Library.git_assert_tag_exists("0.0.0")
    }.should raise_error(RuntimeError)
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
        SchemaEvolutionManager::Library.system_or_error("touch #{tmp}")
        File.exist?(tmp).should be_true
        file = tmp
      end
      File.exist?(file).should be_false
    end

    it "respects prefix" do
      SchemaEvolutionManager::Library.with_temp_file(:prefix => "thisisaprefix") do |tmp|
        tmp.split(".", 2).first.should == "/tmp/thisisaprefix"
      end
    end

  end

  it "SchemaEvolutionManager::Library.delete_file_if_exists" do
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      File.exist?(tmp).should be_false
      SchemaEvolutionManager::Library.delete_file_if_exists(tmp)

      File.open(tmp, "w") { |out| out << "touch" }
      File.exist?(tmp).should be_true
      SchemaEvolutionManager::Library.delete_file_if_exists(tmp)
      File.exist?(tmp).should be_false
    end
  end

  it "SchemaEvolutionManager::Library.write_to_temp_file" do
    SchemaEvolutionManager::Library.write_to_temp_file("test") do |path|
      IO.read(path).should == "test"
    end
  end

  it "SchemaEvolutionManager::Library.base_dir" do
    File.directory?(SchemaEvolutionManager::Library.base_dir).should be_true
    File.directory?(File.join(SchemaEvolutionManager::Library.base_dir, "bin")).should be_true
    File.directory?(File.join(SchemaEvolutionManager::Library.base_dir, "lib")).should be_true
  end

  describe "SchemaEvolutionManager::Library.system_or_error" do

    it "success" do
      SchemaEvolutionManager::Library.system_or_error("echo 'hey'")
    end

    it "failure" do
      lambda {
        SchemaEvolutionManager::Library.system_or_error('/adfadfds')
      }.should raise_error(RuntimeError)
    end

  end

  describe "SchemaEvolutionManager::Library.system_or_error" do
    it "success" do
      SchemaEvolutionManager::Library.system_or_error("echo 'hey'")
    end

    it "failure" do
      lambda {
        SchemaEvolutionManager::Library.system_or_error('/adfadfds')
      }.should raise_error(RuntimeError)
    end
  end

  it "SchemaEvolutionManager::Library.normalize_path" do
    SchemaEvolutionManager::Library.normalize_path("/tmp").should == "/tmp"
    SchemaEvolutionManager::Library.normalize_path("././tmp").should == "tmp"
  end

  it "SchemaEvolutionManager::Library.is_verbose?" do
    SchemaEvolutionManager::Library.is_verbose?.should be_false
    SchemaEvolutionManager::Library.set_verbose(true)
    SchemaEvolutionManager::Library.is_verbose?.should be_true
    SchemaEvolutionManager::Library.set_verbose(false)
    SchemaEvolutionManager::Library.is_verbose?.should be_false
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
          SchemaEvolutionManager::Library.system_or_error("git add %s && git commit -m 'commit%s' %s" % [file, i, file])
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

  describe "SchemaEvolutionManager::Library.latest_tag" do

    it "returns nil if no tags" do
      TestUtils.in_test_repo do
        SchemaEvolutionManager::Library.latest_tag.should be_nil
      end
    end

    it "returns nil if invalid tags only" do
      create_repo_with_commit do
        SchemaEvolutionManager::Library.system_or_error("git tag -a -m 'test' test")
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
