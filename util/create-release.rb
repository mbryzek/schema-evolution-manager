#!/usr/bin/env ruby
#
# This scripts creates the actual release of schema-evolution-manager - runs all the
# tests, and if they pass, updates VERSION file and creates the git tag.
#
# == Usage
#  ./util/create-release.rb
#

load File.join(File.dirname(__FILE__), '../lib/all.rb')
Library.set_verbose(true)

dirty_files = Library.system_or_error("git status --porcelain").strip
Preconditions.check_state(dirty_files == "", "Local checkout is dirty:\n%s" % [dirty_files])

puts "Running Tests"
Dir.chdir("test") do
  Library.system_or_error("./run.rb")
end
puts "All tests passed"

version = Version.read
puts "Current version is %s" % [version.to_version_string]
tmp = Ask.for_string("New version:", :default => version.next_micro.to_version_string)
new_version = Version.new(tmp)

if new_version.to_version_string != version.to_version_string
  puts "Creating git tag[%s]" % new_version.to_version_string
  puts "Writing new_version[%s] to %s" % [new_version.to_version_string, Version::VERSION_FILE]

  Version.write(new_version)
  Library.system_or_error("git commit -m 'Update version to %s' VERSION" % [new_version.to_version_string])
  Library.system_or_error("git tag -a -m '%s' %s" % [new_version.to_version_string, new_version.to_version_string])
end

puts "Release tag[%s] created. Need to git push" % [new_version.to_version_string]
