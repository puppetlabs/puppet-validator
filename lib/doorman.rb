require 'sinatra/base'
require 'webrick'
require 'puppet'
require 'puppet/parser'

class Doorman < Sinatra::Base
  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'

  get '/' do
    erb :index
  end

  post '/validate' do
    validate params['code']
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

        'Syntax OK'
      rescue => detail
        str  = detail.message
        str << "\n    Line: #{detail.line}" if (detail.methods.include? :line and detail.line)
        str << "\nPosition: #{detail.pos}"  if (detail.methods.include? :pos  and detail.pos)
        str
      end
    end

  end
end
