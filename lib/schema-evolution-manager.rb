require 'fileutils'
require 'pathname'

dir = File.dirname(__FILE__)
lib_dir = File.join(dir, "schema-evolution-manager")

load File.join(lib_dir, 'preconditions.rb')
load File.join(lib_dir, 'rdoc_usage.rb')
load File.join(lib_dir, 'library.rb')

# Need to set base_dir early - version.rb depends on dir being set
SchemaEvolutionManager::Library.set_base_dir(File.join(dir, '..'))

load File.join(lib_dir, 'sem_version.rb')
load File.join(lib_dir, 'ask.rb')
load File.join(lib_dir, 'version.rb')
load File.join(lib_dir, 'args.rb')
load File.join(lib_dir, 'scripts.rb')
load File.join(lib_dir, 'db.rb')
load File.join(lib_dir, 'apply_util.rb')
load File.join(lib_dir, 'baseline_util.rb')
load File.join(lib_dir, 'template.rb')
load File.join(lib_dir, 'install_template.rb')
load File.join(lib_dir, 'script_error.rb')
load File.join(lib_dir, 'sem_info.rb')
load File.join(lib_dir, 'migration_file.rb')
