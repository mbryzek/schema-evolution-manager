module SchemaEvolutionManager

  class InstallTemplate

    def initialize(opts={})
      @lib_dir = Preconditions.check_not_blank(opts.delete(:lib_dir), "lib_dir is required")
      @bin_dir = Preconditions.check_not_blank(opts.delete(:bin_dir), "bin_dir is required")
      Preconditions.assert_empty_opts(opts)
    end

    # Generates the actual contents of the install file
    def generate
      template = Template.new
      template.add('timestamp', Time.now.to_s)
      template.add('lib_dir', @lib_dir)
      template.add('bin_dir', @bin_dir)
      template.parse(TEMPLATE)
    end

    def write_to_file(path)
      puts "Writing %s" % path
      File.open(path, "w") do |out|
        out << generate
      end
      Library.system_or_error("chmod +x %s" % path)
    end

    if !defined?(TEMPLATE)
      TEMPLATE = <<-"EOS"
#!/usr/bin/env ruby
#
# Generated on %%timestamp%%
#

load File.join(File.dirname(__FILE__), 'lib/schema-evolution-manager.rb')
SchemaEvolutionManager::Library.set_verbose(true)

lib_dir = '%%lib_dir%%'
bin_dir = '%%bin_dir%%'
version = SchemaEvolutionManager::Version.read

version_name = "schema-evolution-manager-%s" % version.to_version_string
version_dir = File.join(lib_dir, version_name)
version_bin_dir = File.join(version_dir, 'bin')

SchemaEvolutionManager::Library.ensure_dir!(version_dir)
SchemaEvolutionManager::Library.ensure_dir!(bin_dir)

Dir.chdir(lib_dir) do
  if File.exist?("schema-evolution-manager")
    if File.symlink?("schema-evolution-manager")
      SchemaEvolutionManager::Library.system_or_error("rm schema-evolution-manager")
      SchemaEvolutionManager::Library.system_or_error("ln -s %s %s" % [version_name, 'schema-evolution-manager'])
    else
      puts "*** WARNING: File[%s] already exists. Not creating symlink" % File.join(lib_dir, "schema-evolution-manager")
    end
  else
    SchemaEvolutionManager::Library.system_or_error("ln -s %s %s" % [version_name, 'schema-evolution-manager'])
  end
end

['CONVENTIONS.md', 'LICENSE', 'README.md', 'VERSION'].each do |filename|
  SchemaEvolutionManager::Library.system_or_error("cp %s %s" % [filename, version_dir])
end

['bin', 'lib', 'lib/schema-evolution-manager', 'template', 'scripts'].each do |dir|
  this_dir = File.join(version_dir, dir)
  SchemaEvolutionManager::Library.ensure_dir!(this_dir)
  Dir.foreach(dir) do |filename|
    path = File.join(dir, filename)
    if File.file?(path)
      SchemaEvolutionManager::Library.system_or_error("cp %s %s" % [path, this_dir])
      if dir == "bin" && filename != "sem-config"
        SchemaEvolutionManager::Library.system_or_error("chmod +x %s/%s" % [this_dir, filename])
      end
    end
  end
end

aliased_bin_dir = File.join(lib_dir, "schema-evolution-manager", "bin")
Dir.chdir(bin_dir) do
  Dir.foreach(aliased_bin_dir) do |filename|
    path = File.join(aliased_bin_dir, filename)
    if File.file?(path)
      SchemaEvolutionManager::Library.system_or_error("rm -f %s && ln -s %s" % [filename, path])
    end
  end
end

# Overrwrite bin/sem-config with proper location of lib dir
init_file = File.join(version_dir, "bin/sem-config")
SchemaEvolutionManager::Preconditions.check_state(File.exist?(init_file), "Init file[%s] not found" % init_file)
File.open(init_file, "w") do |out|
  out << "load File.join('%s')\n" % File.join(version_dir, 'lib/schema-evolution-manager.rb')
end

puts ""
puts "schema-evolution-manager %s installed in %s" % [version.to_version_string, version_dir]
puts "  - lib dir: %s" % lib_dir
puts "  - bin dir: %s" % bin_dir
puts ""

found = `which sem-add`.strip
if found == ""
  puts "Recommend adding the bin directory to your path"
  puts "  export PATH=%s:$PATH" % bin_dir
  puts ""
end

puts "installation complete"
puts ""

EOS
    end

  end

end
