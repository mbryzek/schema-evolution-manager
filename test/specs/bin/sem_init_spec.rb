load File.join(File.dirname(__FILE__), '../../init.rb')

describe "Init" do

  # sem-init only writes and commits the wrapper scripts; it never connects
  # to the database, so these run without one.
  def run_init(url)
    init_path = File.join(SchemaEvolutionManager::Library.base_dir, "bin/sem-init")
    SchemaEvolutionManager::Library.with_temp_file do |tmp|
      SchemaEvolutionManager::Library.system_or_error("git init #{tmp}")
      SchemaEvolutionManager::Library.system_or_error("#{init_path} --dir #{tmp} --url #{Shellwords.escape(url)}")
      yield tmp
    end
  end

  it "basics" do
    run_init("postgresql://postgres@localhost:5432/sample") do |dir|
      File.exist?(File.join(dir, "dev.rb")).should be true
      File.exist?(File.join(dir, "README.md")).should be true
      IO.read(File.join(dir, "dev.rb")).should include('["sem-apply", "--url", "postgresql://postgres@localhost:5432/sample"]')
    end
  end

  it "never writes a password into dev.rb or its git history" do
    run_init("postgres://user1:s3cret@localhost:5432/sample") do |dir|
      dev = IO.read(File.join(dir, "dev.rb"))
      dev.should_not include("s3cret")
      dev.should include('"postgres://user1@localhost:5432/sample"')
      Dir.chdir(dir) do
        SchemaEvolutionManager::Library.system_or_error("git log -p --all").should_not include("s3cret")
      end
    end
  end

  it "dev.rb execs sem-apply with an argv, not a shell line" do
    url = 'postgres://user1@localhost:5432/sample;$(touch${IFS}injected)"#{1}\\'
    run_init(url) do |dir|
      stub_dir = File.join(dir, "stub")
      FileUtils.mkdir(stub_dir)
      stub = File.join(stub_dir, "sem-apply")
      File.open(stub, "w") { |out| out << "#!/bin/sh\nfor a in \"$@\"; do echo \"arg:$a\"; done\n" }
      File.chmod(0755, stub)

      output = `PATH=#{Shellwords.escape(stub_dir)}:$PATH ruby #{Shellwords.escape(File.join(dir, "dev.rb"))}`
      $?.success?.should be true
      output.lines.map(&:chomp).select { |l| l.start_with?("arg:") }.should == ["arg:--url", "arg:#{url}"]
      File.exist?(File.join(dir, "injected")).should be false
    end
  end

end
