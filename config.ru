require 'rubygems'
require 'puppet-validator'

logger       = Logger.new('/var/log/puppet-validator')
logger.level = Logger::WARN

PuppetValidator.set :root, File.dirname(__FILE__)
PuppetValidator.set :logger, logger

# List out the lint checks you want disabled. By default, this will enable
#   all installed checks. puppet-lint --help will list known checks.
#
PuppetValidator.set :disabled_lint_checks, ['80chars']

# Protect from cross site request forgery. With this set, code may be
#   submitted for validation by the website only.
#
PuppetValidator.set :csrf, false

# Provide the option to generate relationship graphs from validated code.
#   This requires that the `graphviz` package be installed.
#
PuppetValidator.set :graph, false

run PuppetValidator
