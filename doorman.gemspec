require 'date'

Gem::Specification.new do |s|
  s.name              = "doorman"
  s.version           = '0.0.1'
  s.date              = Date.today.to_s
  s.summary           = "Puppet code validator as a service"
  s.homepage          = "https://github.com/puppetlabs/doorman/"
  s.email             = "binford2k@gmail.com"
  s.authors           = ["Ben Ford"]
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( doorman )
  s.files             = %w( README.md LICENSE config.ru )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("doc/**/*")
  s.files            += Dir.glob("views/**/*")
  s.files            += Dir.glob("public/**/*")
  s.add_dependency      "sinatra", "~> 1.3"
  s.add_dependency      "puppet",  "~> 4.0"
  s.description       = <<-desc

  desc
end