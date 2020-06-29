require "sinatra/base"
require "sinatra/param"
require "openssl"
require "securerandom"
require "digest/sha2"
require "base64"

class PotatoCollection
  include Enumerable

  attr_accessor :potatoes

  def initialize
    @@potatoes = {}
  end

  def add potato
    id = generateId
    # @potatoes.merge!({ generateId => { msg: "msg-1", secret: "secret-1" }})
    @@potatoes.merge!({id => potato})
  end

  def self.getPotato id
    @@potatoes.to_h[id]
  end

  def generateId
    loop do
      # token = SecureRandom.hex(5)
      token = SecureRandom.urlsafe_base64(5)
      break token unless @@potatoes.include?(token)
    end
  end

  def self.all
    @@potatoes
  end

  def each
    @@potatoes.each { |potato| yield potato }
  end
end

class HotPotato < Sinatra::Base
  helpers Sinatra::Param

  configure do
    set :bind, "0.0.0.0" # Default dev env is localhost only, works bad with containers.
    # set :port, 443 # Uncomment if handling TLS
    @@potatoes = PotatoCollection.new
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
    @ttl = { "1 day" => 86400, "3 days" => 259200, "7 days" => 604800 }
    @default_ttl = "3 days"
    @title = "Add HotPotato"
    @my_secret = genRandom
    erb :index
  end

  get "/test/" do
    msg = genRandom
    secret = genRandom
    @@potatoes.add("{msg: \"msg-#{msg}\", secret: \"secret-#{secret}\"}")
    erb '<a href="/test/"> do it again!</a>'
    # redirect to("/")
  end

  get "/list/" do
    PotatoCollection.all.to_s
  end

  post "/addPotato" do
    @title = "Potato added"
    param :potato, String, required: true
    param :secret, String, required: true
    param :ttl, Integer, required: true
    one_of :potato, raise: true
    one_of :secret, raise: true
    one_of :ttl, raise: true
    if params["potato"] == "" || params["secret"] == "" || params["ttl"] == ""
      redirect to("/")
    else
      @potato = Base64.encode64(params["potato"])
      @secret = params["secret"]
      @ttl = params["ttl"]
      @cipher = encryptPotato(@secret, @potato)
      erb :potato
    end
  end

  # "Hello #{params[:potato]}"
  # @@potatoes.getPotato("{params[:potato]").to_s
  get "/get/:potato" do
    @potato = params["potato"]
    PotatoCollection.getPotato(@potato).to_s
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
