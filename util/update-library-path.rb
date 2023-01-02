#!/usr/bin/env ruby

path = ARGV.shift.to_s.strip
lib = ARGV.shift.to_s.strip
if path.empty?
  puts "ERROR: Specify path to sem executable"
  exit(1)
end

if lib.empty?
  puts "ERROR: Specify path to sem library"
  exit(1)
end

if !File.exist?(path)
  puts "ERROR: File '#{path}' does not exist"
  exit(1)
end

if !File.exist?(lib)
  puts "ERROR: Library file '#{lib}' does not exist"
  exit(1)
end

tmp = []
IO.readlines(path).each do |l|
  if l.strip == "load File.join(File.dirname(__FILE__), 'sem-config')"
    tmp << "load File.join('#{lib}')\n"
  else
    tmp << l
  end
end

File.open(path, "w") do |out|
  out << tmp.join("")
end
