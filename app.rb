require "sinatra/base"
require "sinatra/param"
require "openssl"
require "securerandom"
require "digest/sha2"
require "base64"
require "singleton"

class PotatoCollection
  include Singleton

  def initialize
    @@potatoes = {}
  end

  def add(potato)
    id = generateId
    @@potatoes[id] = potato
    @potato = @@potatoes.to_h[id]
  end

  def getPotato(id)
    @potato = @@potatoes.to_h[id]
    @@potatoes.delete(id)
    @potato
  end

  def all
    @@potatoes
  end

  private

  def generateId
    loop do
      # token = SecureRandom.hex(5)
      token = SecureRandom.urlsafe_base64(5)
      break token unless @@potatoes.include?(token)
    end
  end
end

class HotPotato < Sinatra::Base
  helpers Sinatra::Param

  configure do
    set :bind, "0.0.0.0" # Default dev env is localhost only, works bad with containers.
    # set :port, 443 # Uncomment if handling TLS
    set :alg, "AES-256-CBC"
  end

  def genRandom
    SecureRandom.alphanumeric(10)
  end

  def generateInitializationVector
    OpenSSL::Cipher.new(settings.alg).random_iv
  end

  def encryptPotato(secret, potato, iv)
    digest = Digest::SHA256.new
    digest.update(secret)
    key = digest.digest

    aes = OpenSSL::Cipher.new(settings.alg)
    aes.encrypt
    aes.key = key
    aes.iv = iv

    cipher = aes.update(potato)
    cipher << aes.final
  end

  def decryptPotato(secret, potato)
    alg = "AES-256-CBC"
    key = secret
    iv = potato[:iv]
    msg = potato[:msg]
    p key
    p iv
    p msg
    decode_cipher = OpenSSL::Cipher::Cipher.new(alg)
    decode_cipher.decrypt
    decode_cipher.key = key
    decode_cipher.iv = iv
    plain = decode_cipher.update(cipher64.unpack1("m"))
    plain << decode_cipher.final
  end

  get "/" do
    @ttl = {"1 day (24h)" => 86400, "3 days (72h)" => 259200, "7 days" => 604800}
    @default_ttl = "3 days"
    @title = "Add HotPotato"
    @my_secret = genRandom
    erb :index
  end

  # get "/test/" do
  #   msg = genRandom
  #   secret = genRandom
  #   @@potatoes.add("{msg: \"msg-#{msg}\", secret: \"secret-#{secret}\"}")
  #   erb '<a href="/test/"> do it again!</a>'
  #   # redirect to("/")
  # end

  get "/list/" do
    PotatoCollection.instance.all.to_s
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
      @iv = generateInitializationVector
      @cipher = encryptPotato(@secret, @potato, @iv)
      @my_potato = PotatoCollection.instance.add({msg: @cipher, secret: @secret, iv: @iv})
      erb :potato
    end
  end

  # "Hello #{params[:potato]}"
  # @@potatoes.getPotato("{params[:potato]").to_s
  get "/get/:potato" do
    @potato = params["potato"]
    @p = PotatoCollection.instance.getPotato(@potato).to_h
    if @p.nil?
      redirect to("/")
    else
      # decryptPotato(1,@p)
      erb "<p>Your potato</p><pre><%= @p[:secret] %></pre></p><pre><%= @p[:msg] %></pre>"
    end
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
