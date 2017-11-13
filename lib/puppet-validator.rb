require 'json'
require 'logger'
require 'sinatra/base'
require 'nokogiri'
require 'cgi'

MAXSIZE = 100000  # something like 3,000 lines of code
CONTEXT = 3       # how many lines of code around an error should we highlight?

class PuppetValidator < Sinatra::Base
  require 'puppet-validator/validators'
  require 'puppet-validator/helpers'

  set :logging, true
  set :strict, true

  enable :sessions

  before do
    env["rack.logger"] = settings.logger if settings.logger

    if settings.csrf
      session[:csrf] ||= SecureRandom.hex(32)
      response.set_cookie 'authenticity_token', {
        :value   => session[:csrf],
        :expires => Time.now + (60 * 60 * 24),
      }
    end
  end

  def initialize(app=nil)
    super(app)

    # make sure that all the settings we expect are defined.
    [:disabled_lint_checks, :puppet_versions, :csrf].each do |name|
      next if settings.respond_to? name

      settings.define_singleton_method(name) { Array.new }

      settings.define_singleton_method("#{name}=") do |arg|
        settings.define_singleton_method(name) { arg }
      end
    end

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

    # put all installed Puppet versions in reverse semver order
    #settings.puppet_versions = settings.puppet_versions.sort_by { |v| Gem::Version.new(v) }.reverse
    settings.puppet_versions = Gem::Specification.all.select {|g| g.name == 'puppet' }.collect {|g| g.version.to_s }
  end

  get '/' do
    @versions = settings.puppet_versions
    @disabled = settings.disabled_lint_checks
    # loads lint into global namespace, but I don't see an alternative
    @checks   = PuppetValidator::Validators::Lint.all_checks

    erb :index
  end

  # The all-in-one blob that renders via an erb page
  post '/validate' do
    logger.info "Validating code from #{request.ip}."
    logger.debug "validating #{request.ip}: #{params['code']}"

    validate_request!

    PuppetValidator.run_in_process do
      syntax = PuppetValidator::Validators::Syntax.new(settings, params['version'])
      result = syntax.validate(params['code'])

      @code          = params['code']
      @version       = params['version']
      @message       = result[:message]
      @status        = result[:status] ? :success : :fail
      @line          = result[:line]
      @column        = result[:pos]

      # initial highlighting for the potential syntax error
      if @line
        start       = [@line - CONTEXT, 1].max
        @highlights = {"#{start}-#{@line}" => nil}
      else
        @highlights = {}
      end

      # then add all the lint warnings and tooltip
      if params['lint'] == 'on'
        linter = PuppetValidator::Validators::Lint.new(settings)
        lint   = linter.validate(params['code'], params['checks'])

        @lint_warnings = ! lint.empty?
        @highlights    = lint.inject(@highlights) do |acc, item|
          acc.merge({item[:line] => "#{item[:kind].upcase}: #{item[:message]}"})
        end.to_json
      end

      if params['relationships'] == 'on' and settings.graph
        @relationships = syntax.render!
      end

      erb :result
    end
  end

  ################### API v0 endpoints ###################

  post '/api/v0/validate/rspec' do
    validate_request!

    PuppetValidator.run_in_process do
      rspec = PuppetValidator::Validators::Rspec.new(settings)
      rspec.validate(params['code'], params['spec']).to_json
    end
  end

  post '/api/v0/validate/syntax' do
    validate_request!

    PuppetValidator.run_in_process do
      syntax = PuppetValidator::Validators::Syntax.new(settings)
      syntax.validate(params['code']).to_json
    end
  end

  post '/api/v0/validate/relationships' do
    validate_request!
    halt 403, 'Graph generation disabled.' unless settings.graph

    PuppetValidator.run_in_process do
      syntax = PuppetValidator::Validators::Syntax.new(settings)

      # need to prebuild the catalog first
      results = syntax.validate(params['code'])
      # return either an SVG or the error message
      results[:status] ? syntax.render! : results[:message]
    end

  end

  post '/api/v0/validate/lint' do
    validate_request!

    PuppetValidator.run_in_process do
      linter = PuppetValidator::Validators::Lint.new(settings)
      linter.validate(params['code']).to_json
    end
  end

  #######################################################

  not_found do
    halt 404, "You shall not pass! (page not found)\n"
  end

  helpers do

    def validate_request!
      csrf_safe!
      check_size_limit!
      sanitize_code!
    end

    def csrf_safe!
      return true unless settings.csrf
      if session[:csrf] == params['_csrf'] && session[:csrf] == request.cookies['authenticity_token']
        true
      else
        logger.warn 'CSRF attempt detected.'
        halt 403, 'Request validation failed.'
      end
    end

    def check_size_limit!
      if request.body.size > MAXSIZE
        halt 403, "Submitted code size is #{request.body.size}, which is larger than the maximum size of #{MAXSIZE}."
      end
    end

    def sanitize_code!
      frag = Nokogiri::HTML.fragment(params['code'])
      unless frag.elements.empty?
        logger.warn 'HTML code found in validation string'
        frag.elements.each { |elem| logger.debug "HTML: #{elem.to_s}" }
        params['code'] = CGI.escapeHTML(params['code'])
      end
    end

  end
end
