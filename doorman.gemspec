require 'date'

Gem::Specification.new do |s|
  s.name              = "doorman"
  s.version           = '0.0.1'
  s.date              = Date.today.to_s
  s.summary           = "Puppet code validator as a service"
  s.homepage          = "http://github.com/binford2k/arnold"
  s.email             = "binford2k@gmail.com"
  s.authors           = ["Ben Ford"]
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( doorman )
  s.files             = %w( README.md LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("doc/**/*")
  s.files            += Dir.glob("views/**/*")
  s.files            += Dir.glob("public/**/*")
  s.add_dependency      "sinatra", "~> 1.3"
  s.description       = <<-desc

  desc
end