require 'json'
require 'logger'
require 'sinatra/base'
require 'puppet'
require 'puppet/parser'
require 'puppet-lint'

require 'graphviz'
require 'nokogiri'
require 'cgi'

MAXSIZE = 100000  # something like 3,000 lines of code
CONTEXT = 3       # how many lines of code around an error should we highlight?

class PuppetValidator < Sinatra::Base
  require 'puppet-validator/validators'

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

    Puppet.initialize_settings rescue nil
    Puppet.settings[:app_management] = true if Gem::Version.new(Puppet.version) >= Gem::Version.new('4.3.2')

    # set up the base environment
    Puppet.push_context(Puppet.base_context(Puppet.settings), 'Setup for Puppet Validator') rescue nil

    # disable as much disk access as possible
    Puppet::Node::Facts.indirection.terminus_class = :memory
    Puppet::Node.indirection.cache_class = nil

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

    # put our supported versions in reverse semver order
    settings.puppet_versions = settings.puppet_versions.sort_by { |v| Gem::Version.new(v) }.reverse

  end

  get '/' do
    @versions = [Puppet.version] + settings.puppet_versions
    @disabled = settings.disabled_lint_checks
    @checks   = puppet_lint_checks

    erb :index
  end

  post '/validate' do
    logger.info "Validating code from #{request.ip}."
    logger.debug "validating #{request.ip}: #{params['code']}"

    halt 403, 'Request validation failed.' unless safe?

    frag = Nokogiri::HTML.fragment(params['code'])
    unless frag.elements.empty?
      logger.warn 'HTML code found in validation string'
      frag.elements.each { |elem| logger.debug "HTML: #{elem.to_s}" }
      params['code'] = CGI.escapeHTML(params['code'])
    end

    if request.body.size <= MAXSIZE
      result = validate params['code']
      lint   = lint(params['code'], params['checks']) if params['lint'] == 'on'
      lint ||= {} # but make sure we have a data object to iterate

      @version       = Puppet.version
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

      @relationships = rendered_dot(@code) if params['relationships'] == 'on'
    else
      @message = "Submitted code size is #{request.body.size}, which is larger than the maximum size of #{MAXSIZE}."
      @status  = :fail
      logger.error @message
    end

    erb :result
  end

  #################### API endpoints ####################

  post '/api/v0/validate/rspec' do
    rspec = PuppetValidator::Validators::Rspec.new(settings.spec)
    rspec.validate(params['code'], params['spec']).to_json
  end

#   post '/api/v0/validate/syntax' do
#   end
#
#   post '/api/v0/validate/relationships' do
#   end
#
#   post '/api/v0/validate/lint' do
#   end

  #######################################################

  not_found do
    halt 404, "You shall not pass! (page not found)\n"
  end

  helpers do

    def safe?
      return true unless settings.csrf
      if session[:csrf] == params['_csrf'] && session[:csrf] == request.cookies['authenticity_token']
        true
      else
        logger.warn 'CSRF attempt detected.'
        false
      end
    end

    def validate(data)
      begin
        Puppet[:code] = data

        if Puppet::Node::Environment.respond_to?(:create)
          validation_environment = Puppet::Node::Environment.create(:production, [])
          validation_environment.check_for_reparse
        else
          validation_environment = Puppet::Node::Environment.new(:production)
        end

        validation_environment.known_resource_types.clear

        {:status => true, :message => 'Syntax OK'}
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

    def rendered_dot(code)
      return unless settings.graph

      begin
        node    = Puppet::Node.indirection.find('validator')
        catalog = Puppet::Resource::Catalog.indirection.find(node.name, :use_node => node)

        # These calls are failing due to an internal method not being available in 2 & 3.x. Suspect
        # that it's related to the compiler not being set up fully?
        catalog.remove_resource(catalog.resource("Stage", :main)) rescue nil
        catalog.remove_resource(catalog.resource("Class", :settings)) rescue nil

        graph   = catalog.to_ral.relationship_graph.to_dot

        svg = GraphViz.parse_string(graph) do |graph|
          graph[:label] = 'Resource Relationships'

          graph.each_node do |name, node|
            next unless name.start_with? 'Whit'
            newname = name.dup
            newname.sub!('Admissible_class', 'Starting Class')
            newname.sub!('Completed_class', 'Finishing Class')
            node[:label] = newname[5..-2]
          end
        end.output(:svg => String)

      rescue => detail
        logger.warn detail.message
        logger.debug detail.backtrace.join "\n"
        return { :status => false, :message => detail.message }
      end

      { :status => true, :data => svg }
    end

  end
end
