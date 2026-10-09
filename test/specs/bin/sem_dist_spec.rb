load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Dist" do

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

  it "can create a distribution" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")
    random_string = "random_string_%s" % [rand(100000)]

    TestUtils.in_test_repo do
      File.open("new.sql", "w") { |out| out << "select #{random_string}" }
      SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
      SchemaEvolutionManager::Library.git_create_tag("1.0.0")
      SchemaEvolutionManager::Library.system_or_error([dist_path, "--tag", "1.0.0"])
      SchemaEvolutionManager::Library.assert_dir_exists("dist")
      extract_release do |release_dir|
        changes = File.join(release_dir, "CHANGES")
        if !File.exist?(changes)
          fail("changes file[%s] not found" % [changes])
        end
        scripts = SchemaEvolutionManager::Scripts.all(File.join(release_dir, "scripts"))
        scripts.size.should == 1
        IO.read(scripts.first).index(random_string).should > 0
      end
    end
  end

  it "creates a distribution from a directory whose path a shell would split" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")

    TestUtils.in_test_repo(:dirname => TestUtils::AWKWARD_DIRNAME) do
      File.open("new.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
      SchemaEvolutionManager::Library.git_create_tag("1.0.0")
      SchemaEvolutionManager::Library.system_or_error([dist_path, "--tag", "1.0.0"])
      Dir.glob("dist/*.tar.gz").map { |f| File.basename(f) }.should == ["#{TestUtils::AWKWARD_DIRNAME}-1.0.0.tar.gz"]
      extract_release do |release_dir|
        File.basename(release_dir).should == "#{TestUtils::AWKWARD_DIRNAME}-1.0.0"
        SchemaEvolutionManager::Scripts.all(File.join(release_dir, "scripts")).size.should == 1
      end
    end
  end

  it "uses an awkward artifact_name verbatim" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")
    artifact_name = "my db's schema"

    TestUtils.in_test_repo do
      File.open("new.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
      SchemaEvolutionManager::Library.git_create_tag("1.0.0")
      SchemaEvolutionManager::Library.system_or_error([dist_path, "--artifact_name", artifact_name, "--tag", "1.0.0"])
      Dir.glob("dist/*.tar.gz").map { |f| File.basename(f) }.should == ["#{artifact_name}-1.0.0.tar.gz"]
    end
  end

  it "writes a VERSION file containing the tag" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")

    TestUtils.in_test_repo do
      File.open("new.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
      SchemaEvolutionManager::Library.git_create_tag("1.2.3")
      SchemaEvolutionManager::Library.system_or_error([dist_path, "--tag", "1.2.3"])
      extract_release do |release_dir|
        version_file = File.join(release_dir, "VERSION")
        File.exist?(version_file).should be true
        IO.read(version_file).strip.should == "1.2.3"
      end
    end
  end

  it "packs the scripts_dir named by .sem as scripts/ and never packs .sem" do
    add_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-add")
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")

    TestUtils.in_test_repo do
      File.open(".sem", "w") { |out| out << "sem.config.scripts_dir = schema/scripts\n" }
      File.open("new.sql", "w") { |out| out << "select 1" }
      SchemaEvolutionManager::Library.system_or_error([add_path, "./new.sql"])
      SchemaEvolutionManager::Library.system_or_error(["git", "add", ".sem"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
      SchemaEvolutionManager::Library.git_create_tag("1.0.0")
      SchemaEvolutionManager::Library.system_or_error(["rm", "-rf", "dist"])
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

  it "fails when the tag exceeds the max version length" do
    dist_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-dist")
    # 3-segment (valid for git_create_tag's x.x.x check) but > MAX_VERSION_LENGTH
    long_tag = "1.1." + ("9" * SchemaEvolutionManager::Versions::MAX_VERSION_LENGTH)

    TestUtils.in_test_repo_with_script do
      SchemaEvolutionManager::Library.system_or_error(["git", "add", "scripts"])
      SchemaEvolutionManager::Library.system_or_error(["git", "commit", "-m", "Testing"])
      SchemaEvolutionManager::Library.git_create_tag(long_tag)
      result = system(dist_path, "--tag", long_tag, [:out, :err] => File::NULL)
      result.should be false
    end
  end

end
