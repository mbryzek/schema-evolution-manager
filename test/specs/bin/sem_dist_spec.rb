require File.expand_path('../../init.rb', __dir__)
require 'tmpdir'

describe "Dist" do

  def add_path
    File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
  end

  def dist_path
    File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")
  end

  # Adds one script holding +sql+ to the repository in the current
  # directory, commits it and tags the commit
  def commit_script_and_tag(sql, tag)
    File.open("new.sql", "w") { |out| out << sql }
    SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
    SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
    SchemaEvolutionManager::Library.git_create_tag(tag)
  end

  # Extracts the single tarball in dist/ into ./tmp, yielding the
  # release directory it holds
  def extract_release
    tarballs = Dir.glob("dist/*.tar.gz")
    tarballs.size.should == 1
    FileUtils.mkdir("tmp")
    SchemaEvolutionManager::Library.system_or_error(["tar", "-xzf", tarballs.first, "-C", "tmp"])
    entries = Dir.children("tmp")
    entries.size.should == 1
    yield File.join("tmp", entries.first)
  end

  # One repository and its distributions serve every example in this group:
  # each only reads what sem-dist wrote, and building a repository and a
  # tarball (git init, sem-add, a commit, a tag, sem-dist) is most of the
  # cost of an example.
  describe "a tagged repository" do

    before(:all) do
      @random_string = "random_string_%s" % [rand(100000)]
      @artifact_name = "my db's schema"
      @repo = Dir.mktmpdir("sem-dist-spec")
      @default_name = "%s-1.2.3" % [File.basename(@repo)]
      Dir.chdir(@repo) do
        SchemaEvolutionManager::Library.system_or_error(["git", "init", "--quiet", "."])
        commit_script_and_tag("select #{@random_string}", "1.2.3")
        SchemaEvolutionManager::Library.system_or_error([dist_path, "--tag", "1.2.3"])
        SchemaEvolutionManager::Library.system_or_error([dist_path, "--artifact_name", @artifact_name, "--tag", "1.2.3"])
        @tarballs = Dir.glob("dist/*.tar.gz").map { |f| File.basename(f) }.sort
        FileUtils.mkdir("tmp")
        SchemaEvolutionManager::Library.system_or_error(["tar", "-xzf", File.join("dist", "#{@default_name}.tar.gz"), "-C", "tmp"])
        @entries = Dir.children("tmp")
      end
      @release_dir = File.join(@repo, "tmp", @default_name)
    end

    after(:all) do
      FileUtils.rm_rf(@repo) if @repo
    end

    it "can create a distribution" do
      @entries.should == [@default_name]
      changes = File.join(@release_dir, "CHANGES")
      if !File.exist?(changes)
        fail("changes file[%s] not found" % [changes])
      end
      scripts = SchemaEvolutionManager::Scripts.all(File.join(@release_dir, "scripts"))
      scripts.size.should == 1
      IO.read(scripts.first).index(@random_string).should > 0
    end

    it "uses an awkward artifact_name verbatim" do
      @tarballs.should == ["#{@default_name}.tar.gz", "#{@artifact_name}-1.2.3.tar.gz"].sort
    end

    it "writes a VERSION file containing the tag" do
      version_file = File.join(@release_dir, "VERSION")
      File.exist?(version_file).should be true
      IO.read(version_file).strip.should == "1.2.3"
    end

    it "fails when the tag exceeds the max version length" do
      # 3-segment (valid for git_create_tag's x.x.x check) but > MAX_VERSION_LENGTH
      long_tag = "1.1." + ("9" * SchemaEvolutionManager::Versions::MAX_VERSION_LENGTH)
      Dir.chdir(@repo) do
        SchemaEvolutionManager::Library.git_create_tag(long_tag)
        result = system(dist_path, "--tag", long_tag, [:out, :err] => File::NULL)
        result.should be false
      end
    end

  end

  it "creates a distribution from a directory whose path a shell would split" do
    TestUtils.in_test_repo(:dirname => TestUtils::AWKWARD_DIRNAME) do
      commit_script_and_tag("select 1", "1.0.0")
      SchemaEvolutionManager::Library.system_or_error([dist_path, "--tag", "1.0.0"])
      Dir.glob("dist/*.tar.gz").map { |f| File.basename(f) }.should == ["#{TestUtils::AWKWARD_DIRNAME}-1.0.0.tar.gz"]
      extract_release do |release_dir|
        File.basename(release_dir).should == "#{TestUtils::AWKWARD_DIRNAME}-1.0.0"
        SchemaEvolutionManager::Scripts.all(File.join(release_dir, "scripts")).size.should == 1
      end
    end
  end

  it "packs the scripts_dir named by .sem as scripts/ and never packs .sem" do
    TestUtils.in_test_repo do
      File.open(".sem", "w") { |out| out << "sem.config.scripts_dir = schema/scripts\n" }
      SchemaEvolutionManager::Library.system_or_error(["git", "add", ".sem"])
      commit_script_and_tag("select 1", "1.0.0")
      SchemaEvolutionManager::Library.system_or_error([dist_path, "--tag", "1.0.0"])
      tarball = Dir.glob("dist/*.tar.gz").first
      entries = SchemaEvolutionManager::Library.system_or_error(["tar", "tzf", tarball]).split("\n").map { |e|
        e.sub(/^[^\/]+\//, '')
      }
      entries.should include("scripts/")
      entries.select { |e| e.match(/^scripts\/.+\.sql$/) }.size.should == 1
      entries.select { |e| File.basename(e) == ".sem" }.should == []
      entries.select { |e| e.start_with?("schema") }.should == []
    end
  end

end
