require "sinatra/base"
require "sinatra/param"
require "openssl"

class HotPotato < Sinatra::Base
  helpers Sinatra::Param

  configure do
    set :bind, "0.0.0.0" # Default dev env is localhost only, works bad with containers.
    # set :port, 443 # Uncomment if handling TLS
  end

  get "/" do
    @title = "Add HotPotato"
    erb :index
  end

  post "/addPotato" do
    param :potato, String, required: true
    one_of :potato
    @title = "Potato added"
    @potato = params["potato"]
    erb :potato
  end

  get "/get/:potato" do
    "Hello #{params[:potato]}"
  end

  # Kubernetes healthcheck
  get "/healthz" do
    status 200
    body "OK"
  end

  # If handling TLS, Verify crt / key files and uncomment
  # def self.run!
  #     super do |server|
  #       server.ssl = true
  #       server.ssl_options = {
  #         :cert_chain_file  => File.dirname(__FILE__) + "/server.crt",
  #         :private_key_file => File.dirname(__FILE__) + "/server.key",
  #         :verify_peer      => false
  #       }
  #     end
  #   end

  run! if app_file == $0
end
