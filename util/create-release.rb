#!/usr/bin/env ruby
#
# This scripts creates the actual release of schema-evolution-manager - runs all the
# tests, and if they pass, updates VERSION file and creates the git tag.
#
# == Usage
#  ./util/create-release.rb                     # asks for the version; pushes nothing
#  ./util/create-release.rb --apply             # releases origin/main as the next micro version
#  ./util/create-release.rb --apply --version 0.10.0
#
# --apply asks nothing and publishes: it releases origin/main as fetched
# now, commits the version bump, pushes that commit and its tag to origin
# together, and pushes the gem. Homebrew's formula follows the tag. A
# tip of origin/main that already carries a release tag is released:
# that is success with nothing to do, so a second run is harmless.
# `dev deploy all` runs it in its checkout of origin/main whenever main is
# ahead of the newest tag (devops' Deploy_item.tag_releases).
#

load File.join(File.dirname(__FILE__), '../lib/schema-evolution-manager.rb')
load File.join(File.dirname(__FILE__), 'release.rb')
SchemaEvolutionManager::Library.set_verbose(true)

Lib = SchemaEvolutionManager::Library
Pre = SchemaEvolutionManager::Preconditions
Release = SchemaEvolutionManager::Release

opts = Release.parse_args(ARGV)
apply = opts[:apply]

Dir.chdir(File.join(File.dirname(__FILE__), ".."))

dirty_files = Lib.system_or_error(["git", "status", "--porcelain"]).strip
Pre.check_state(dirty_files == "", "Local checkout is dirty:\n%s" % dirty_files)

if apply
  Lib.system_or_error(["git", "fetch", "--tags", "origin", "main"])
  head = Lib.system_or_error(["git", "rev-parse", "HEAD"])
  main = Lib.system_or_error(["git", "rev-parse", "origin/main"])
  Pre.check_state(head == main, "--apply releases origin/main (%s), and this checkout is at %s" % [main, head])
end

tags_at_head = Lib.system_or_error(["git", "tag", "--points-at", "HEAD"]).split
current = SchemaEvolutionManager::Version.read.to_version_string
puts "Current version is %s" % current

requested = opts[:version]
if !apply && requested.nil?
  requested = SchemaEvolutionManager::Ask.for_string("New version:", :default => SchemaEvolutionManager::Version.parse(current).next_micro.to_version_string)
end

outcome, value = Release.decide(current, tags_at_head, Lib.git_tags, requested)
case outcome
when :already
  puts "HEAD is already released as %s; nothing to release" % value
  exit(0)
when :refuse
  puts "ERROR: %s" % value
  exit(1)
end
new_version = value

# ci/build.sh starts a throwaway Postgres container for the suite and streams
# the rspec output here, so a failing spec is readable rather than captured.
puts "Running Tests"
system("./ci/build.sh") || Pre.check_state(false, "Tests failed (exit %s)" % $?.exitstatus)
puts "All tests passed"

new_readme = Release.readme_with_version(IO.read("README.md"), new_version)
Pre.check_state(!new_readme.nil?, "Failed to update README.md")

puts "Update version in README.md"
File.open("README.md", "w") { |out| out << new_readme }

sem_version_path = "lib/schema-evolution-manager/sem_version.rb"
puts "Updating version in #{sem_version_path}"
File.open(sem_version_path, "w") { |out| out << Release.sem_version_source(new_version) }

puts "Writing new_version[%s] to %s" % [new_version, SchemaEvolutionManager::Version::VERSION_FILE]
SchemaEvolutionManager::Version.write(SchemaEvolutionManager::Version.parse(new_version))

Lib.system_or_error(["git", "commit", "--allow-empty", "-m", "autocommit: Update version to %s" % new_version, "VERSION", "README.md", sem_version_path])

puts "Creating git tag[%s]" % new_version
Lib.system_or_error(["git", "tag", "-a", "-m", new_version, new_version])

gem_file = "schema-evolution-manager-%s.gem" % new_version
Lib.system_or_error(["gem", "build", "schema-evolution-manager.gemspec"])

if !apply
  puts "Release tag[%s] created. Need to:" % new_version
  puts "  git push origin"
  puts "  git push --tags origin"
  puts "  gem push %s" % gem_file
  exit(0)
end

# One atomic push: origin gets the version commit and its tag together, or
# neither when main moved since the fetch above.
Lib.system_or_error(["git", "push", "--atomic", "origin", "HEAD:refs/heads/main", "refs/tags/%s" % new_version])
puts "Released %s: origin/main and tag %s pushed" % [new_version, new_version]

# The tag is the release Homebrew follows, so a gem push that fails (no
# RubyGems credentials on this machine) leaves the release out and says
# what is left.
if system("gem", "push", gem_file, :in => File::NULL)
  puts "Pushed %s to RubyGems" % gem_file
else
  puts "WARNING: gem push failed; the tag is released. Publish the gem from a checkout of %s with: gem push %s" % [new_version, gem_file]
end
