#!/usr/bin/env ruby
#
# Preprares schema-evolution-manager for installation. See also install.rb
# script in this directory. Main work is to simply check a few
# dependencies and to capture the directory into which the user
# would like to install schema-evolution-manager.
#
# == Usage
#  ./configure.rb
#    You will be asked for required options
#
#  ./configure.rb --lib_dir /usr/local/lib --bin_dir /usr/local/bin
#    Configure installer for the specified lib and bin directories
#

load File.join(File.dirname(__FILE__), 'lib/schema-evolution-manager.rb')
SchemaEvolutionManager::Library.set_verbose(true)

args = SchemaEvolutionManager::Args.from_stdin(:optional => %w(lib_dir bin_dir))

lib_dir = args.lib_dir || SchemaEvolutionManager::Ask.for_string("lib dir", :default => "/usr/local/lib")

if lib_dir.match(/\/lib$/)
  default_bin_dir = lib_dir.sub(/\/lib$/, '/bin')
else
  default_bin_dir = "/usr/local/bin"
end
bin_dir = args.bin_dir || SchemaEvolutionManager::Ask.for_string("bin dir", :default => default_bin_dir)

target = "./install.rb"
template = SchemaEvolutionManager::InstallTemplate.new(:lib_dir => lib_dir, :bin_dir => bin_dir)
template.write_to_file(target)

puts ""
puts "To complete installation, run:"
puts "  sudo #{target}"
puts ""
