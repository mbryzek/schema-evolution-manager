require File.expand_path('../../init.rb', __dir__)
load File.expand_path('../../../util/release.rb', __dir__)

describe SchemaEvolutionManager::Release do

  Release = SchemaEvolutionManager::Release unless defined?(Release)

  describe "parse_args" do

    it "defaults to asking, with no version" do
      Release.parse_args([]).should == { :apply => false, :version => nil }
    end

    it "reads --apply and --version" do
      Release.parse_args(["--apply", "--version", "0.10.0"]).should == { :apply => true, :version => "0.10.0" }
    end

    it "refuses an unknown argument" do
      expect { Release.parse_args(["--yes"]) }.to raise_error(/Unknown argument\[--yes\]/)
    end

    it "refuses --version with no value" do
      expect { Release.parse_args(["--version"]) }.to raise_error(/--version needs a value/)
    end

  end

  describe "decide" do

    TAGS = ["0.9.60", "0.9.61", "0.9.62", "not-a-release"] unless defined?(TAGS)

    it "releases the next micro version of an untagged head" do
      Release.decide("0.9.62", [], TAGS).should == [:release, "0.9.63"]
    end

    it "treats a head that carries a release tag as released" do
      Release.decide("0.9.62", ["0.9.62"], TAGS).should == [:already, "0.9.62"]
    end

    it "ignores a non-release tag on head" do
      Release.decide("0.9.62", ["not-a-release"], TAGS).should == [:release, "0.9.63"]
    end

    it "releases a requested version newer than every release" do
      Release.decide("0.9.62", [], TAGS, "0.10.0").should == [:release, "0.10.0"]
    end

    it "refuses a version already released" do
      Release.decide("0.9.61", [], TAGS).should == [:refuse, "0.9.62 is already released"]
    end

    it "refuses a version older than the newest release" do
      Release.decide("0.9.62", [], TAGS + ["0.9.70"]).should == [:refuse, "0.9.63 is not newer than the newest release 0.9.70"]
    end

    it "refuses a requested version that is not x.y.z" do
      Release.decide("0.9.62", [], TAGS, "1.0").should == [:refuse, "1.0 is not a release version (x.y.z)"]
    end

  end

  describe "readme_with_version" do

    it "points the install instructions at the version" do
      text = "Install:\n\n    git checkout 0.9.62\n    ./configure.rb\n"
      Release.readme_with_version(text, "0.9.63").should == "Install:\n\n    git checkout 0.9.63\n    ./configure.rb\n"
    end

    it "is nil for a README with no checkout line" do
      Release.readme_with_version("nothing here\n", "0.9.63").should be_nil
    end

    it "updates the repository's own README" do
      text = IO.read(File.expand_path('../../../README.md', __dir__))
      Release.readme_with_version(text, "99.0.0").should include("git checkout 99.0.0")
    end

  end

  describe "sem_version_source" do

    it "matches the shape of the checked-in sem_version.rb" do
      path = File.expand_path('../../../lib/schema-evolution-manager/sem_version.rb', __dir__)
      checked_in = IO.read(path)
      version = checked_in[/VERSION \|\|= '([^']+)'/, 1]
      Release.sem_version_source(version).should == checked_in
    end

  end

end
