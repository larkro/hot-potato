# spec/app_spec.rb
require File.expand_path "../spec_helper.rb", __FILE__

describe HotPotato do
  it "should allow accessing the home page" do
    get "/"
    expect(last_response).to be_ok
    expect(last_response.body).to match("Send a HotPotato")
  end
  it "should not allow GET access to post page" do
    get "/addPotato"
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with param" do
    post "/add", params: '{ "widget": { "name":"My Widget" } }'
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with bad form fields" do
    post "/add", 'junk="testing"'
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with bad form" do
    post "/add", {
      junk: "testing"
    }
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with potato only" do
    post "/add", {
      potato: "testing"
    }
    expect(last_response).not_to be_ok
  end
  it "should NOT allow POST access to /addPotato with form field TTL as String" do
    post "/add", {
      potato: "string to be encrypted",
      secret: "adsasd",
      ttl: "adsasd"
    }
    expect(last_response).not_to be_ok
  end
  it "should NOT allow POST access to /addPotato without all three form field " do
    post "/add", {
      potato: "string to be encrypted",
      ttl: "adsasd"
    }
    expect(last_response).not_to be_ok
  end
  it "should allow POST access to /addPotato with form field potato, secret and ttl" do
    post "/add", {
      potato: "string to be encrypted",
      secret: "adsasd",
      ttl: "123"
    }
    expect(last_response).to be_ok
  end
  it "should allow kubernetes healthcheck" do
    get "/healthz"
    expect(last_response).to be_ok
    expect(last_response.body).to match("OK")
  end
end
