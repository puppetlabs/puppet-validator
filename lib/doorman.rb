require 'logger'
require 'sinatra/base'
require 'puppet'
require 'puppet/parser'
require 'puppet-lint'

# something like 3,000 lines of code
MAXSIZE = 100000
CONTEXT = 3

class Doorman < Sinatra::Base
  set :logging, true
  set :strict, true

  before {
    env["rack.logger"] = settings.logger if settings.logger
  }

  get '/' do
    erb :index
  end

  post '/validate' do
    logger.info "Validating code from #{request.ip}."
    logger.debug "validating #{request.ip}: #{params['code']}"

    if request.body.size <= MAXSIZE
      result = validate params['code']
      lint   = lint params['code'] if params['lint'] == 'on'
      lint ||= {} # but make sure we have a data object to iterate

      @code       = params['code']
      @message    = result[:message]
      @status     = result[:status] ? :success : :fail
      @line       = result[:line]
      @column     = result[:pos]

      # initial highlighting for the potential syntax error
      if @line
        start   = [@line - CONTEXT, 1].max
        initial = {"#{start}-#{@line}" => nil}
      else
        initial = []
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
        Puppet[:code] = data
        validation_environment = Puppet.lookup(:current_environment)

        validation_environment.check_for_reparse
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

    def lint(data)
      begin
        linter = PuppetLint.new
        linter.code = data
        linter.run
        linter.print_problems
      rescue => detail
        logger.warn detail.message
        nil
      end
    end


  end
end
