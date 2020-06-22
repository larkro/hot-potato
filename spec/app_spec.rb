# spec/app_spec.rb
require File.expand_path "../spec_helper.rb", __FILE__

describe HotPotato do
  it "should allow accessing the home page" do
    get "/"
    expect(last_response).to be_ok
    expect(last_response.body).to match("Add HotPotato")
  end
  it "should not allow GET access to post page" do
    get "/addPotato"
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with param" do
    post "/addPotato", params: '{ "widget": { "name":"My Widget" } }'
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with bad form fields" do
    post "/addPotato", 'junk="testing"'
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with bad form" do
    post "/addPotato", {
      junk: "testing"
    }
    expect(last_response).not_to be_ok
  end
  it "should not allow POST access to /addPotato with potato only" do
    post "/addPotato", {
      potato: "testing"
    }
    expect(last_response).not_to be_ok
  end
  it "should allow POST access to /addPotato with form field potato and secret" do
    post "/addPotato", {
      potato: "string to be encrypted",
      secret: "adsasd"
    }
    # post "/addPotato", {'potato="string to be encrypted"', 'secret="adsasd"'}
    expect(last_response).to be_ok
  end
  it "should allow kubernetes healthcheck" do
    get "/healthz"
    expect(last_response).to be_ok
    expect(last_response.body).to match("OK")
  end
end
