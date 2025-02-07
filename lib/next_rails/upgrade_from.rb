require_relative "http_client"

class NextRails::UpgradeFrom
  URL = ENV.fetch("UPGRADE_FROM_URL") { "https://roadrunner-staging-5ff1a4e7a439.herokuapp.com/api/v1/next_versions" }

  def initialize(current_version)
    @current_version = current_version
    @response = NextRails::HttpClient.get(URL, {current_rails_version: @current_version})
  end

  def self.current_version(current_version)
    new(current_version).print_versions
  end

  def print_versions
    return @response['detail'] if @response.fetch('detail', false)

    check_rails_version + check_ruby_version
  end

  private

  def ruby_version
    @response['required_ruby']
  end

  def check_rails_version
    return "You are on the most current Rails version." if @response['next_rails'].nil?

    "The latest patch for Rails #{@current_version} is #{@response['current_latest_patch']}.\nThe next Rails target jump should be #{@response['next_rails']}.\n"
  end

  def check_ruby_version
    return "" if ruby_version.empty?

    "The recommended Ruby version#{'s' if ruby_version.length > 1} for this jump is #{ruby_version.join(', ')}."
  end
end
