require_relative './http_client.rb'
require 'byebug'

class NextRails::UpgradeFrom

 def initialize(current_version)
  @current_version = current_version
  url = "https://roadrunner-staging-5ff1a4e7a439.herokuapp.com/api/v1/next_versions?current_rails_version=#{@current_version}"
  @next_versions_res = NextRails::HttpClient.connect(url)
 end

  def self.current_version(current_version)
    new(current_version).print_versions
  end

  def print_versions
    return @next_versions_res['detail'] if @next_versions_res.fetch('detail', false)
    check_rails_version + check_ruby_version
  end

  private

  def ruby_version
    @next_versions_res['required_ruby']
  end

  def check_rails_version
    if @next_versions_res["next_rails"].nil?
      "You are on the most current Rails version."
    else
      "The latest patch for Rails #{@current_version} is #{@next_versions_res['current_latest_patch']}.\nThe next Rails target jump should be #{@next_versions_res["next_rails"]}.\n"
    end
  end

  def check_ruby_version
    return "" if ruby_version.empty?
    "The recommended Ruby version#{'s' if ruby_version.length > 1} for this jump is #{ruby_version.join(', ')}."
  end

end