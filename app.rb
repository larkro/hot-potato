require "sinatra/base"
require "sinatra/param"
require "openssl"
require "securerandom"
require "digest/sha2"

class HotPotato < Sinatra::Base
  helpers Sinatra::Param

  configure do
    set :bind, "0.0.0.0" # Default dev env is localhost only, works bad with containers.
    # set :port, 443 # Uncomment if handling TLS
  end

  def genRandom
    SecureRandom.alphanumeric(10)
  end

  def encryptPotato(secret, potato)
    alg = "AES-256-CBC"
    iv = OpenSSL::Cipher.new(alg).random_iv

    digest = Digest::SHA256.new
    digest.update(secret)
    key = digest.digest

    aes = OpenSSL::Cipher.new(alg)
    aes.encrypt
    aes.key = key
    aes.iv = iv

    cipher = aes.update(potato)
    cipher << aes.final
  end

  get "/" do
    @title = "Add HotPotato"
    @my_secret = genRandom
    erb :index
  end

  post "/addPotato" do
    @title = "Potato added"
    param :potato, String, required: true
    param :secret, String, required: true
    one_of :potato, raise: true
    one_of :secret, raise: true
    if params["potato"] == "" || params["secret"] == ""
      redirect to("/")
    else
      @potato = params["potato"]
      @secret = params["secret"]
      @cipher = encryptPotato(@secret, @potato)
      erb :potato
    end
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
