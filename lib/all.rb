require 'fileutils'
require 'pathname'

dir = File.dirname(__FILE__)
load File.join(dir, 'preconditions.rb')
load File.join(dir, 'rdoc_usage.rb')
load File.join(dir, 'library.rb')
load File.join(dir, 'ask.rb')
load File.join(dir, 'version.rb')
load File.join(dir, 'args.rb')
load File.join(dir, 'scripts.rb')
load File.join(dir, 'db.rb')
load File.join(dir, 'apply_util.rb')
load File.join(dir, 'template.rb')
load File.join(dir, 'install_template.rb')
load File.join(dir, 'sem_info.rb')

Library.set_base_dir(File.join(dir, '..'))
