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
    id
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

  def encryptPotato(secret, potato)
    salt = OpenSSL::Random.random_bytes(16)
    iter = 20000
    cipher = OpenSSL::Cipher.new(settings.alg)
    key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, iter, cipher.key_len)
    cipher.encrypt
    cipher.key = key
    iv = OpenSSL::Cipher.new(settings.alg).random_iv
    cipher.iv = iv
    encrypted = cipher.update(potato) + cipher.final
    PotatoCollection.instance.add({msg: encrypted, salt: salt, iv: iv})
  end

  def decryptPotato(secret, potato)
    decipher = OpenSSL::Cipher.new(settings.alg)

    salt = potato[:salt]
    iter = 20000
    key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, iter, decipher.key_len)

    decipher.decrypt
    decipher.key = key
    decipher.iv = potato[:iv]

    decipher.update(potato[:msg]) + decipher.final
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
      @encrypted = encryptPotato(@secret, @potato)
      #      @my_potato = PotatoCollection.instance.add({msg: @encrypted, secret: @secret, iv: @iv})
      erb :potato
    end
  end

  get "/get/:potato" do
    @potato = params["potato"]
    @p = PotatoCollection.instance.getPotato(@potato).to_h
    if @p.empty?
      redirect to("/")
    else
      @plain = decryptPotato("1", @p)
      erb "<p>Your potato</p> <pre><%= Base64.decode64(@plain) %></pre>"
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
