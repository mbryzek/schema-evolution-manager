#!/usr/bin/env ruby

load File.join(File.dirname(__FILE__), '..', 'lib', 'schema-evolution-manager.rb')

def run(command)
  puts command
  system(command)
end

gem_home = SchemaEvolutionManager::Library.normalize_path(File.join(File.dirname(__FILE__), '../gems'))
rspec = File.join(gem_home, 'bin/rspec')
if !File.exist?(rspec)
  run("export GEM_HOME=%s && gem install rspec --version 2.13.0 --no-rdoc --no-ri --install-dir %s" % [gem_home, gem_home])
end

files = `find specs -type f -name "*spec.rb"`.strip.split

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
