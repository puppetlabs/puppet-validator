require 'date'

Gem::Specification.new do |s|
  s.name              = "puppet-validator"
  s.version           = '0.0.7'
  s.date              = Date.today.to_s
  s.summary           = "Puppet code validator as a service"
  s.homepage          = "https://github.com/puppetlabs/puppet-validator/"
  s.email             = "binford2k@gmail.com"
  s.authors           = ["Ben Ford"]
  s.license           = "Apache-2.0"
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( puppet-validator )
  s.files             = %w( README.md LICENSE config.ru )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("doc/**/*")
  s.files            += Dir.glob("views/**/*")
  s.files            += Dir.glob("public/**/*")
  s.add_dependency      "sinatra",       "~> 1.3"
  s.add_dependency      "puppet",        [">= 2.7", "<5.0"]
  s.add_dependency      "puppet-lint",   "~> 1.1"
  s.add_dependency      "nokogiri",      "~> 1.6", ">= 1.6.5"
  s.add_dependency      "ruby-graphviz", "~> 1.2"
  s.description       = <<-desc
    Puppet Validator is a simple web service that accepts arbitrary code submissions and
    validates it the way `puppet parser validate` would. It can optionally also
    run `puppet-lint` checks on the code and display both results together.
  desc
end
