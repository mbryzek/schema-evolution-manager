#!/usr/bin/env ruby
#
# This scripts creates the actual release of schema-evolution-manager - runs all the
# tests, and if they pass, updates VERSION file and creates the git tag.
#
# == Usage
#  ./util/create-release.rb
#

load File.join(File.dirname(__FILE__), '../lib/schema-evolution-manager.rb')
SchemaEvolutionManager::Library.set_verbose(true)

dirty_files = SchemaEvolutionManager::Library.system_or_error("git status --porcelain").strip
SchemaEvolutionManager::Preconditions.check_state(dirty_files == "", "Local checkout is dirty:\n%s" % dirty_files)

puts "Running Tests"
Dir.chdir("test") do
  SchemaEvolutionManager::Library.system_or_error("./run.rb")
end
puts "All tests passed"

version = SchemaEvolutionManager::Version.read
puts "Current version is %s" % version.to_version_string
tmp = SchemaEvolutionManager::Ask.for_string("New version:", :default => version.next_micro.to_version_string)
new_version = SchemaEvolutionManager::Version.parse(tmp)

if new_version.to_version_string == version.to_version_string
  puts "Version has not changed. Exiting"
  exit(1)
end

# Parse README.md
new_readme = ""
found = false
IO.readlines("README.md").each do |l|
  if l.match(/git checkout \d+\.\d+\.\d+$/)
    found = true
    l.sub!(/git checkout \d+\.\d+\.\d+$/, "git checkout %s" % new_version.to_version_string)
  end
  new_readme << l
end
SchemaEvolutionManager::Preconditions.check_state(found, "Failed to update README.md")

puts "Update version in README.md"
File.open("README.md", "w") { |out| out << new_readme }

sem_version_path = "lib/schema-evolution-manager/sem_version.rb"
puts "Updating version in #{sem_version_path}"
File.open(sem_version_path, "w") do |out|
  out << "# File automatically created and updated by util/create-release.rb\n"
  out << "module SchemaEvolutionManager\n\n"
  out << "module SemVersion\n\n"
  out << "VERSION ||= '0.9.43'\n\n"
  out << "end\n\n"
  out << "end\n\n"
  out << "end\n"
end

puts "Writing new_version[%s] to %s" % [new_version.to_version_string, SchemaEvolutionManager::Version::VERSION_FILE]
SchemaEvolutionManager::Version.write(new_version)

SchemaEvolutionManager::Library.system_or_error("git commit --allow-empty -m 'autocommit: Update version to %s' VERSION README.md %s" % [new_version.to_version_string, sem_version_path])

puts "Creating git tag[%s]" % new_version.to_version_string
SchemaEvolutionManager::Library.system_or_error("git tag -a -m '%s' %s" % [new_version.to_version_string, new_version.to_version_string])

SchemaEvolutionManager::Library.system_or_error("gem build schema-evolution-manager.gemspec")

puts "Release tag[%s] created. Need to:" % new_version.to_version_string
puts "  git push origin"
puts "  git push --tags origin"
puts "  gem push schema-evolution-manager-%s.gem" % new_version.to_version_string
