#!/usr/bin/env ruby
#
# This scripts creates the actual release of schema-evolution-manager - runs all the
# tests, and if they pass, updates VERSION file and creates the git tag.
#
# == Usage
#  ./util/create-release.rb                     # asks for the version; pushes nothing
#  ./util/create-release.rb --apply             # releases origin/main as the next micro version
#  ./util/create-release.rb --apply --version 0.10.0
#  ./util/create-release.rb --apply --version 0.9.66   # in a checkout of tag 0.9.66: publishes it
#
# --apply asks nothing and publishes: it releases origin/main as fetched
# now, commits the version bump, pushes that commit and its tag to origin
# together, and pushes the gem. Homebrew's formula follows the tag. A
# tip of origin/main that already carries a release tag is released:
# that is success with nothing to do, so a second run is harmless.
# This untagged path is for a person's run. devops' rollout releases this
# repo the other way: it cuts tag V first and then runs `--apply --version V`
# in a checkout of that tag (devops' Rollout_release_kind), described below.
#
# --version V in a checkout whose HEAD carries tag V PUBLISHES that tag,
# which somebody else cut (devops' rollout tags first and then runs this
# script in a checkout of the tag): it runs the suite, builds and pushes
# the gem for V (writing V into the version files of the build only), and
# commits the version bump onto origin/main when main's VERSION lags V. No
# tag is created or moved. A gem RubyGems already lists and a main already
# at V are each skipped, so a second run is harmless; a gem push that
# fails exits 1, because a tag with no gem is not a release.
#

load File.join(File.dirname(__FILE__), '../lib/schema-evolution-manager.rb')
load File.join(File.dirname(__FILE__), 'release.rb')
require 'tmpdir'
require 'fileutils'
SchemaEvolutionManager::Library.set_verbose(true)

Lib = SchemaEvolutionManager::Library
Pre = SchemaEvolutionManager::Preconditions
Release = SchemaEvolutionManager::Release

SEM_VERSION_PATH = "lib/schema-evolution-manager/sem_version.rb"
# The files a release writes its version into, relative to the checkout.
VERSION_FILES = ["VERSION", "README.md", SEM_VERSION_PATH]

# ci/build.fast.sh starts a throwaway Postgres container for the suite and streams
# the rspec output here, so a failing spec is readable rather than captured.
def run_tests
  puts "Running Tests"
  system("./ci/build.fast.sh") || Pre.check_state(false, "Tests failed (exit %s)" % $?.exitstatus)
  puts "All tests passed"
end

# Writes +version+ into VERSION, README.md and sem_version.rb under +dir+.
def write_version_files(dir, version)
  readme_path = File.join(dir, "README.md")
  new_readme = Release.readme_with_version(IO.read(readme_path), version)
  Pre.check_state(!new_readme.nil?, "Failed to update %s" % readme_path)
  puts "Update version in %s" % readme_path
  File.open(readme_path, "w") { |out| out << new_readme }

  sem_version_path = File.join(dir, SEM_VERSION_PATH)
  puts "Updating version in %s" % sem_version_path
  File.open(sem_version_path, "w") { |out| out << Release.sem_version_source(version) }

  version_path = File.join(dir, "VERSION")
  puts "Writing version[%s] to %s" % [version, version_path]
  File.open(version_path, "w") { |out| out << version << "\n" }
end

# Publishes a tag somebody else cut, from a checkout of it (see the header).
module Publish

  MAX_PUSH_ATTEMPTS = 3

  def Publish.run(version, apply)
    puts "HEAD is tagged %s and --version names it: publishing that tag" % version
    run_tests
    gem_file = Publish.build_gem(version)
    if !apply
      puts "Built %s. Need to:" % gem_file
      puts "  gem push %s" % gem_file
      puts "  commit the version bump to %s onto main" % version
      return
    end
    Publish.push_gem(version, gem_file)
    Publish.bump_main(version)
    puts "Published %s" % version
  end

  # Builds the gem for +version+ from the tag's tree, with the version
  # files written for the build and restored after it, so the checkout is
  # left exactly as it was found.
  def Publish.build_gem(version)
    write_version_files(".", version)
    begin
      Lib.system_or_error(["gem", "build", "schema-evolution-manager.gemspec"])
    ensure
      Lib.system_or_error(["git", "checkout", "--", *VERSION_FILES])
    end
    gem_file = "schema-evolution-manager-%s.gem" % version
    Pre.check_state(File.exist?(gem_file), "gem build wrote no %s" % gem_file)
    gem_file
  end

  def Publish.push_gem(version, gem_file)
    listed = `gem list --remote --exact --all schema-evolution-manager 2>/dev/null`
    if $?.success? && Release.published_versions(listed).include?(version)
      puts "RubyGems already lists schema-evolution-manager %s; nothing to push" % version
      return
    end
    if system("gem", "push", gem_file, :in => File::NULL)
      puts "Pushed %s to RubyGems" % gem_file
    else
      puts "ERROR: gem push of %s failed (exit %s); tag %s has no gem. Re-run this command once RubyGems accepts the push" % [gem_file, $?.exitstatus, version]
      exit(1)
    end
  end

  # Commits the version bump onto origin/main when main's VERSION lags
  # +version+, in a worktree of its own so the tag checkout is untouched.
  # A push that loses a race with another commit to main refetches and
  # tries again.
  def Publish.bump_main(version)
    MAX_PUSH_ATTEMPTS.times do |attempt|
      Lib.system_or_error(["git", "fetch", "origin", "main"])
      main_version = Lib.system_or_error(["git", "show", "origin/main:VERSION"])
      if !Release.main_lags?(main_version, version)
        puts "origin/main is at version %s; no version bump needed" % main_version.strip
        return
      end
      dir = Dir.mktmpdir("sem-release-")
      begin
        Lib.system_or_error(["git", "worktree", "add", "--detach", dir, "origin/main"])
        write_version_files(dir, version)
        Lib.system_or_error(["git", "-C", dir, "commit", "-m", "autocommit: Update version to %s" % version, *VERSION_FILES])
        if system("git", "-C", dir, "push", "origin", "HEAD:refs/heads/main")
          puts "Pushed the version bump to %s onto origin/main" % version
          return
        end
        puts "Push of the version bump lost a race with main (attempt %s of %s)" % [attempt + 1, MAX_PUSH_ATTEMPTS]
      ensure
        system("git", "worktree", "remove", "--force", dir)
        FileUtils.rm_rf(dir)
      end
    end
    puts "ERROR: could not push the version bump to %s onto origin/main after %s attempts" % [version, MAX_PUSH_ATTEMPTS]
    exit(1)
  end

end

opts = Release.parse_args(ARGV)
apply = opts[:apply]

Dir.chdir(File.join(File.dirname(__FILE__), ".."))

dirty_files = Lib.system_or_error(["git", "status", "--porcelain"]).strip
Pre.check_state(dirty_files == "", "Local checkout is dirty:\n%s" % dirty_files)

if apply
  Lib.system_or_error(["git", "fetch", "--tags", "origin", "main"])
end

tags_at_head = Lib.system_or_error(["git", "tag", "--points-at", "HEAD"]).split
requested = opts[:version]
publishing = !requested.nil? && Release.release_tags(tags_at_head).include?(requested)

# Publishing reads a tag, which main has usually moved past; every other
# --apply run releases origin/main itself.
if apply && !publishing
  head = Lib.system_or_error(["git", "rev-parse", "HEAD"])
  main = Lib.system_or_error(["git", "rev-parse", "origin/main"])
  Pre.check_state(head == main, "--apply releases origin/main (%s), and this checkout is at %s" % [main, head])
end

current = SchemaEvolutionManager::Version.read.to_version_string
puts "Current version is %s" % current

if !apply && requested.nil? && Release.release_tags(tags_at_head).empty?
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
when :publish
  Publish.run(value, apply)
  exit(0)
end
new_version = value

run_tests
write_version_files(".", new_version)

Lib.system_or_error(["git", "commit", "--allow-empty", "-m", "autocommit: Update version to %s" % new_version, *VERSION_FILES])

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
