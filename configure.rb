#!/usr/bin/env ruby
#
# Preprares schema-evolution-manager for installation. See also install.rb
# script in this directory. Main work is to simply check a few
# dependencies and to capture the directory into which the user
# would like to install schema-evolution-manager.
#
# == Usage
#  ./configure.rb
#

load File.join(File.dirname(__FILE__), 'lib/all.rb')
Library.set_verbose(true)

lib_dir = Ask.for_string("lib dir", :default => "/usr/local/lib")

if lib_dir.match(/\/lib$/)
  default_bin_dir = lib_dir.sub(/\/lib$/, '/bin')
else
  default_bin_dir = "/usr/local/bin"
end
bin_dir = Ask.for_string("bin dir", :default => default_bin_dir)

target = "./install.rb"
template = InstallTemplate.new(:lib_dir => lib_dir, :bin_dir => bin_dir)
template.write_to_file(target)

puts ""
puts "To complete installation, run:"
puts "  sudo #{target}"
puts ""
