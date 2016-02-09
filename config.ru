require 'rubygems'
require 'doorman'

logger       = Logger.new('/var/log/doorman')
logger.level = Logger::WARN

Doorman.set :root, File.dirname(__FILE__)
Doorman.set :logger, logger

run Doorman
