require "json"
require "net/http"

class NextRails::HttpClient
  def self.connect(endpoint)
    uri = URI(endpoint)
    res = Net::HTTP.get_response(uri)
    JSON.parse(res.body)
  end
end
