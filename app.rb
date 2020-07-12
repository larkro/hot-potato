require "sucker_punch"
require "sinatra/base"
require "sinatra/param"
require "openssl"
require "securerandom"
require "digest/sha2"
require "base64"
require "singleton"

class CleaningJob
  include SuckerPunch::Job

  def perform
    wait_time = 60
    puts "Worker started. Will clean up every #{wait_time} seconds."
    loop do
      sleep(wait_time)
      PotatoCollection.instance.check_ttl
    end
  end
end

class PotatoCollection
  include Singleton

  def initialize
    @@potatoes = {}
    CleaningJob.perform_async
  end

  def number
    @@potatoes.count
  end

  def add(secret, potato, alg, end_of_life)
    if (@encrypted_potato = encrypt_potato(secret, potato, alg, end_of_life))
      id = generate_id
      @@potatoes[id] = @encrypted_potato
      id
    else
      Base64.encode64("Not saved")
    end
  end

  def get(id, secret, alg)
    @potato = @@potatoes.to_h[id]
    if @potato.nil?
      Base64.encode64("No potato for you")
    else
      @plain = decrypt_potato(secret, @potato, alg)
      # Hash comes from rescue OpenSSL::Cipher::CipherError.
      # Hiding that the potato existed but supplied passwd was bad.
      if @plain.class == Hash
        Base64.encode64("No potato for you")
      else
        @@potatoes.delete(id)
        @plain
      end
    end
  end

  def check_ttl
    @@potatoes.delete_if { |k, v| v[:ttl] <= Time.now.to_i }
  end

  # TODO remove, debug purpose only
  # def all
  #   @@potatoes
  # end

  private

  def encrypt_potato(secret, potato, alg, end_of_life)
    cipher = OpenSSL::Cipher.new(alg)

    salt = OpenSSL::Random.random_bytes(16)
    iter = 20000
    key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, iter, cipher.key_len)
    iv = OpenSSL::Cipher.new(alg).random_iv

    cipher.encrypt
    cipher.key = key
    cipher.iv = iv

    encrypted = cipher.update(potato) + cipher.final
    {msg: encrypted, salt: salt, iv: iv, ttl: end_of_life}
  end

  def decrypt_potato(secret, potato, alg)
    decipher = OpenSSL::Cipher.new(alg)

    salt = potato[:salt]
    iter = 20000
    key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, iter, decipher.key_len)

    decipher.decrypt
    decipher.key = key
    decipher.iv = potato[:iv]

    decipher.update(potato[:msg]) + decipher.final
  rescue OpenSSL::Cipher::CipherError
    {msg: "Wrong passwd"}
  end

  def generate_id
    loop do
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

  # TODO remove, debug purpose only
  # get "/list/" do
  #   @title = "Debug view"
  #   @p = PotatoCollection.instance.all.to_h
  #   erb '<%= @p.each {|key, value| puts "<p>#{key} is #{value}</p>" }%>'
  # end

  get "/" do
    # @ttl = {"debug" => 20, "1 day (24h)" => 86400, "3 days (72h)" => 259200, "7 days" => 604800}
    @ttl = {"1 day (24h)" => 86400, "3 days (72h)" => 259200, "7 days" => 604800}
    @title = "Send a HotPotato"
    @my_secret = SecureRandom.alphanumeric(10)
    erb :index
  end

  get "/num" do
    num = PotatoCollection.instance.number
    @title = "Number of potatoes"
    erb "<pre>#{num}</pre>"
  end

  post "/add" do
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
      @end_of_life = Time.now.to_i + @ttl
      @encrypted = PotatoCollection.instance.add(@secret, @potato, settings.alg, @end_of_life)
      @base_url = request.base_url
      erb :add
    end
  end

  get "/get/:potato" do
    @title = "Get HotPotato"
    @potato_id = params["potato"]
    erb :get
  end

  post "/get" do
    @title = "Your potato"
    param :potato, String, required: true
    param :secret, String, required: true
    one_of :potato, raise: true
    one_of :secret, raise: true
    @potato = params["potato"]
    @secret = params["secret"]
    if params["potato"] == "" || params["secret"] == ""
      redirect to("/get")
    else
      @p = PotatoCollection.instance.get(@potato, @secret, settings.alg)
      if @p.empty?
        redirect to("/")
      else
        erb :got
      end
    end
  end

  not_found do
    redirect to("/")
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
