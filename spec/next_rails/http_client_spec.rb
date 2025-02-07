require "spec_helper"
require "next_rails/http_client"

RSpec.describe NextRails::HttpClient do
  describe "#get" do
    let(:url) { "http://example.com" }
    let(:body) { { message: "Hello, world!" }.to_json }
    let(:response_body) { JSON.parse(body) }

    it "returns a successful response body" do
      stub_request(:get, url).to_return(status: 200, body: body, headers: { "Content-Type": "application/json" })

      response = NextRails::HttpClient.get(url)
      expect(response).to eq response_body
    end

    it "returns a successful response body with query params" do
      stub_request(:get, "#{url}?query=test").to_return(status: 200, body: body, headers: { "Content-Type": "application/json" })

      response = NextRails::HttpClient.get(url, { query: "test"})
      expect(response).to eq response_body
    end
  end
end
