require 'rubygems'
require 'puppet-validator'

logger       = Logger.new('/var/log/puppet-validator')
logger.level = Logger::WARN

PuppetValidator.set :puppet_versions, Dir.glob('*').select {|f| File.symlink? f and File.readlink(f) == '.' }
PuppetValidator.set :root, File.dirname(__FILE__)
PuppetValidator.set :logger, logger
PuppetValidator.set :disabled_lint_checks, ['80chars']

# Protect from cross site request forgery. With this set, code may be
#   submitted for validation by the website only.
#
# Note: This will currently break multiple version validation.
PuppetValidator.set :csrf, false

run PuppetValidator
