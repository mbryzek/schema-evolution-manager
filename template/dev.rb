#!/usr/bin/env ruby
# == Wrapper script to update a local postgrseql database
#
# == Usage
#  ./dev.rb
#

command = "schema-evolution-manager/bin/sem-apply --host localhost --user %%user%% --name %%name%%"
puts command
system(command)
