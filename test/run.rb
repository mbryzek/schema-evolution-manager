#!/usr/bin/env ruby

require File.expand_path('init.rb', __dir__)

def run(command)
  puts command
  system(command)
end

# rspec lives in ./gems and is installed on first use. `./run.rb --install`
# installs it and exits, so ci/build.sh pays for the install before its timed
# steps rather than inside whichever spec file happens to run first.
gem_home = SchemaEvolutionManager::Library.normalize_path(File.join(File.dirname(__FILE__), '../gems'))
rspec = File.join(gem_home, 'bin/rspec')
if !File.exist?(rspec)
  run("export GEM_HOME=%s && gem install rspec --version 3.9 --no-document --install-dir %s" % [gem_home, gem_home]) || exit(1)
end
exit(0) if ARGV == ["--install"]

# Most specs create and drop databases, so the run needs a server before it
# starts; a missing one is one message here rather than a failure per spec.
begin
  TestUtils.server_url("postgres")
rescue RuntimeError => e
  $stderr.puts e.message
  exit(1)
end

# Spec files named on the command line run alone (ci/build.sh runs each file as
# one step); with none, every spec runs.
files = ARGV.empty? ? `find specs -type f -name "*spec.rb"`.strip.split : ARGV

result = output = nil

SchemaEvolutionManager::Library.with_temp_file do |tmp|
  result = run("export GEM_HOME=%s && %s %s > %s" % [gem_home, rspec, files.join(" "), tmp])
  output = IO.read(tmp)
end

puts output

if result
  exit(0)
else
  puts ""
  puts "To rerun particular scripts, use rspec at:"
  puts "export GEM_HOME=%s && %s" % [gem_home, rspec]
  exit(1)
end
