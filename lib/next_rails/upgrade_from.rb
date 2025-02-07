require_relative './http_client.rb'
require 'byebug'

class NextRails::UpgradeFrom

 def initialize(current_version)
  @current_version = current_version
  url = "https://roadrunner-staging-5ff1a4e7a439.herokuapp.com/api/v1/next_versions?current_rails_version=#{@current_version}"
  @next_versions_res = NextRails::HttpClient.connect(url)
 end

  def self.current_version(current_version)
    new(current_version).check_version
  end

  def check_version
    return @next_versions_res['detail'] if @next_versions_res.fetch('detail', false)
    rails_v = check_rails_version
    rails_v + check_ruby_version
  end

  def check_rails_version
    if @next_versions_res["next_rails"].nil?
      "You are on the most current Rails version."
    else
      "The latest patch for Rails #{@current_version} is #{@next_versions_res['current_latest_patch']}.\nThe next Rails target jump should be #{@next_versions_res["next_rails"]}.\n"
    end
  end

  # def check_ruby_version
  #   if @next_versions_res['required_ruby'].any? && @next_versions_res['required_ruby'].length == 2
  #     "The recommended Ruby versions for this jump is #{@next_versions_res['required_ruby'][0]}, #{@next_versions_res['required_ruby'][1]}."
  #   elsif @next_versions_res['required_ruby'].any? && @next_versions_res['required_ruby'].length == 3
  #     "The recommended Ruby versions for this jump is #{@next_versions_res['required_ruby'][0]}, #{@next_versions_res['required_ruby'][1]}, #{@next_versions_res['required_ruby'][2]}."
  #   elsif @next_versions_res['required_ruby'].any? && @next_versions_res['required_ruby'].length == 1
  #     "The recommended Ruby version for this jump is #{@next_versions_res['required_ruby'][0]}."
  #   else
  #     ""
  #   end
  # end

  def check_ruby_version
    ruby_versions = @next_versions_res['required_ruby']

    if ruby_versions.any?
      versions_text = ruby_versions.join(', ')
      "The recommended Ruby version#{'s' if ruby_versions.length > 1} for this jump is #{versions_text}."
    else
      ""
    end
  end
end