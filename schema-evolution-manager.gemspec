Gem::Specification.new do |s|
  s.name              = 'schema-evolution-manager'
  s.homepage          = "https://github.com/gilt/schema-evolution-manager"
  s.version           = File.open('VERSION') {|f| f.readline}
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "Schema evolution manager is a simple schema migration tool for postgresql databases."
  s.description       = "Schema Evolution Manager makes it very simple for engineers to contribute schema changes to a postgresql database, managing the schema evolutions as proper source code."
  s.description       = 
  s.authors           = ["Michael Bryzek"]
  s.email             = 'mbryzek@alum.mit.edu'
  s.licenses          = 'Apache 2.0'
  s.files             = %w( README.md )
  s.files             += Dir.glob("bin/**/*")
  s.files             += Dir.glob("lib/**/*")
  s.files             += Dir.glob("scripts/**/*")
  s.files             += Dir.glob("template/**/*")
  s.executables       = Dir.entries("bin").select {|f| !File.directory? f}
end
