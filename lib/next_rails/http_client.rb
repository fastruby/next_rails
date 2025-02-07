require "json"
require "net/http"
require "uri"

class NextRails::HttpClient
  def self.get(endpoint, params = {})
    uri = URI(endpoint)
    uri.query = URI.encode_www_form(params) unless params.empty?
    response = Net::HTTP.get_response(uri)

    JSON.parse(response.body)
  end
end
