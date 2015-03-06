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
#  ./configure.rb --prefix /usr/local
#    Configure installer for the specified lib and bin directories
#

load File.join(File.dirname(__FILE__), 'lib/schema-evolution-manager.rb')
SchemaEvolutionManager::Library.set_verbose(true)

args = SchemaEvolutionManager::Args.from_stdin(:optional => %w(prefix))

prefix = args.prefix || SchemaEvolutionManager::Ask.for_string("prefix", :default => "/usr/local")
lib_dir = File.join(prefix, "lib")
bin_dir = File.join(prefix, "bin")

target = "./install.rb"
template = SchemaEvolutionManager::InstallTemplate.new(:lib_dir => lib_dir, :bin_dir => bin_dir)
template.write_to_file(target)

puts ""
puts "To complete installation, run:"
puts "  sudo #{target}"
puts ""
