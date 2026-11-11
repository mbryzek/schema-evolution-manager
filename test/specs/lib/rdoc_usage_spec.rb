require File.expand_path('../../init.rb', __dir__)
require 'stringio'

describe SchemaEvolutionManager::RdocUsage do

  it "RdocUsage.message" do
    msg = SchemaEvolutionManager::RdocUsage.message
    msg.size.should > 0
    msg.index("rspec").should >= 0
  end

  # Runs the block with stdout and stderr captured; returns
  # [stdout, stderr, exit status of the SystemExit it raised].
  def capture_exit
    out, err = $stdout, $stderr
    $stdout, $stderr = StringIO.new, StringIO.new
    status = nil
    begin
      yield
    rescue SystemExit => e
      status = e.status
    ensure
      captured = [$stdout.string, $stderr.string]
      $stdout, $stderr = out, err
    end
    captured + [status]
  end

  it "error! writes one ERROR line and its details to stderr, nothing to stdout, and exits" do
    stdout, stderr, status = capture_exit {
      SchemaEvolutionManager::RdocUsage.error!("Missing tag.", SchemaEvolutionManager::RdocUsage::MISSING_INPUT, :details => ["a", "b"])
    }
    [stdout, stderr, status].should == ["", "ERROR: Missing tag.\na\nb\n", 3]
  end

  it "error! appends the usage when asked" do
    _, stderr, status = capture_exit {
      SchemaEvolutionManager::RdocUsage.error!("Unrecognized command[x]", SchemaEvolutionManager::RdocUsage::INVALID_INPUT, :usage => true)
    }
    status.should == 4
    stderr.chomp.should == ("ERROR: Unrecognized command[x]\n\n" + SchemaEvolutionManager::RdocUsage.message).chomp
  end

  it "error! refuses an exit code that names no kind of fault" do
    lambda {
      SchemaEvolutionManager::RdocUsage.error!("x", 2)
    }.should raise_error(RuntimeError, /Invalid exit_code\[2\]/)
  end

end
