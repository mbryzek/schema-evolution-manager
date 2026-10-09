#!/usr/bin/env ruby
# == Wrapper script to update a local postgrseql database
#
# == Usage
#  ./dev.rb
#

Dir.chdir(File.dirname($0)) {
  command = ["sem-apply", "--url", %%url_literal%%]
  puts command.join(" ")
  exec(*command)
}
