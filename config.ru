require 'rubygems'
require 'puppet-validator'

logger       = Logger.new('/var/log/puppet-validator')
logger.level = Logger::WARN

PuppetValidator.set :root, File.dirname(__FILE__)
PuppetValidator.set :logger, logger
PuppetValidator.set :disabled_lint_checks, ['80chars']

run PuppetValidator
