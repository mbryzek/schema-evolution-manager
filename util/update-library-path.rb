#!/usr/bin/env ruby

file = ARGV.shift.to_s.strip
fromlib = ARGV.shift.to_s.strip
tolib = ARGV.shift.to_s.strip
if file.empty?
  puts "ERROR: Specify file to update"
  exit(1)
end

if fromlib.empty?
  puts "ERROR: Specify path to sem library"
  exit(1)
end

if tolib.empty?
  puts "ERROR: Specify path to sem library"
  exit(1)
end

if !File.exists?(file)
  puts "ERROR: File '#{file}' does not exist"
  exit(1)
end

if !File.exists?(tolib)
  puts "ERROR: Library file '#{tolib}' does not exist"
  exit(1)
end

tmp = []
IO.readlines(file).each do |l|
  if l.strip == "load File.join(File.dirname(__FILE__), '#{fromlib}')"
    tmp << "load File.join('#{tolib}')\n"
  else
    tmp << l
  end
end

File.open(file, "w") do |out|
  out << tmp.join("")
end
