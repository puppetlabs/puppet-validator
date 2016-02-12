require 'logger'
require 'sinatra/base'
require 'puppet'
require 'puppet/parser'
require 'puppet-lint'

# something like 3,000 lines of code
MAXSIZE = 100000
CONTEXT = 3

class PuppetValidator < Sinatra::Base
  set :logging, true
  set :strict, true

  before {
    env["rack.logger"] = settings.logger if settings.logger
  }

  def initialize(app=nil)
    super(app)

    Puppet.initialize_settings if Puppet.version.to_i == 3 and Puppet.settings[:confdir].nil?

    # there must be a better way
    if settings.respond_to? :disabled_lint_checks
      # can pass in an array, a filename, or a list of checks
      if settings.disabled_lint_checks.class == String
        path = File.expand_path(settings.disabled_lint_checks)
        if File.file? path
          data = File.readlines(path).map {|line| line.chomp }
          data.reject! {|line| line.empty? or line.start_with? '#' }

          settings.disabled_lint_checks = data
        else
          settings.disabled_lint_checks = settings.disabled_lint_checks.split(',')
        end
      end

    else
      # this seems... gross, but I don't know a better way to make sure this
      # option exists whether it was passed in or not.
      def settings.disabled_lint_checks
        []
      end
    end

  end

  get '/' do
    @disabled = settings.disabled_lint_checks
    @checks   = puppet_lint_checks

    erb :index
  end

  post '/validate' do
    logger.info "Validating code from #{request.ip}."
    logger.debug "validating #{request.ip}: #{params['code']}"

    if request.body.size <= MAXSIZE
      result = validate params['code']
      lint   = lint(params['code'], params['checks']) if params['lint'] == 'on'
      lint ||= {} # but make sure we have a data object to iterate

      @code          = params['code']
      @message       = result[:message]
      @status        = result[:status] ? :success : :fail
      @line          = result[:line]
      @column        = result[:pos]
      @lint_warnings = ! lint.empty?

      # initial highlighting for the potential syntax error
      if @line
        start   = [@line - CONTEXT, 1].max
        initial = {"#{start}-#{@line}" => nil}
      else
        initial = {}
      end

      # then add all the lint warnings and tooltip
      @highlights = lint.inject(initial) do |acc, item|
        acc.merge({item[:line] => "#{item[:kind].upcase}: #{item[:message]}"})
      end.to_json

    else
      @message = "Submitted code size is #{request.body.size}, which is larger than the maximum size of #{MAXSIZE}."
      @status  = :fail
      logger.error @message
    end

    erb :result
  end

  not_found do
    halt 404, "You shall not pass! (page not found)\n"
  end

  helpers do

    def validate(data)
      begin
        Puppet.settings[:app_management] = true if Gem::Version.new(Puppet.version) >= Gem::Version.new('4.3.2')

        Puppet[:code] = data

        if Puppet::Node::Environment.respond_to?(:create)
          validation_environment = Puppet::Node::Environment.create(:production, [])
          validation_environment.check_for_reparse
        else
          validation_environment = Puppet::Node::Environment.new(:production)
        end

        validation_environment.known_resource_types.clear

        {:status => true, :message => "Syntax OK for Puppet version #{Puppet.version}"}
      rescue => detail
        logger.warn detail.message
        err = {:status => false, :message => detail.message}
        err[:line] = detail.line if detail.methods.include? :line
        err[:pos]  = detail.pos  if detail.methods.include? :pos
        err
      end
    end

    def lint(data, checks=nil)
      begin
        if checks
          logger.info "Disabling checks: #{(puppet_lint_checks - checks).inspect}"

          checks.each do |check|
            PuppetLint.configuration.send("enable_#{check}")
          end

          (puppet_lint_checks - checks).each do |check|
            PuppetLint.configuration.send("disable_#{check}")
          end
        else
          logger.info "Disabling checks: #{settings.disabled_lint_checks.inspect}"

          settings.disabled_lint_checks.each do |check|
            PuppetLint.configuration.send("disable_#{check}")
          end
        end

        linter = PuppetLint.new
        linter.code = data
        linter.run
        linter.print_problems
      rescue => detail
        logger.warn detail.message
        nil
      end
    end

    def puppet_lint_checks
      # sanitize because reasonss
      PuppetLint.configuration.checks.map {|check| check.to_s}
    end

  end
end
