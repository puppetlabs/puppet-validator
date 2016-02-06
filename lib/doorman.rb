require 'sinatra/base'
require 'webrick'
require 'puppet'
require 'puppet/parser'

# something like 3,000 lines of code
MAXSIZE = 100000

class Doorman < Sinatra::Base
  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'

  configure :production, :development do
    enable :logging
  end

  get '/' do
    erb :index
  end

  post '/validate' do
    logger.info 'Validating code.'

    if request.body.size <= MAXSIZE
      @result = validate params['code']
      @code   = params['code']
    else
      message = "Submitted code size is #{request.body.size}, which is larger than the maximum size of #{MAXSIZE}."
      logger.error message
      @result = { :status => false, :message => message }
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
        err = {:status => false, :message => detail.message}
        err[:line] = detail.line if detail.methods.include? :line
        err[:pos]  = detail.pos  if detail.methods.include? :pos
        err
      end
    end

  end
end
