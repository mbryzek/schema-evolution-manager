load File.join(File.dirname(__FILE__), '../../init.rb')

describe SchemaEvolutionManager::Args do

  it "needs at least one required or optional argument" do
    lambda {
      SchemaEvolutionManager::Args.new("")
    }.should raise_error(RuntimeError)
  end

  it "handles basic flags" do
    args = SchemaEvolutionManager::Args.new("--host localhost", { :required => ['host'], :optional => ['dry_run'] })
    args.host.should == "localhost"
    args.dry_run.should be_false

    args = SchemaEvolutionManager::Args.new("--dry_run --host localhost", { :required => ['host'], :optional => ['dry_run'] })
    args.host.should == "localhost"
    args.dry_run.should be_true

    args = SchemaEvolutionManager::Args.new(" --host localhost --dry_run", { :required => ['host'], :optional => ['dry_run'] })
    args.host.should == "localhost"
    args.dry_run.should be_true
  end

  it "handles full db config" do
    args = SchemaEvolutionManager::Args.new("--host localhost --port 5433 --name test --user mbryzek", { :required => %w(host port name user) })
    args.host.should == "localhost"
    args.port.should == "5433"
    args.name.should == "test"
    args.user.should == "mbryzek"
  end

  it "ok with nil/empty as inputs" do
    SchemaEvolutionManager::Args.new(nil, { :optional => %w(dry_run) })
    SchemaEvolutionManager::Args.new("", { :optional => %w(dry_run) })
    SchemaEvolutionManager::Args.new("   ", { :optional => %w(dry_run) })
  end

  it "has documentation for all params" do
    args = SchemaEvolutionManager::Args.new("", :optional => %w(help))
    [SchemaEvolutionManager::Args::FLAGS_WITH_ARGUMENTS.keys, SchemaEvolutionManager::Args::FLAGS_NO_ARGUMENTS.keys].flatten.each do |flag|
      msg = args.send(:help_parameters, "test", [flag])
      msg.index(flag.to_s).should > 0
    end
  end

end
