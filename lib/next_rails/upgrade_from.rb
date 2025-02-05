require "json"
require "net/http"
require 'pry'

class NextRails::UpgradeFrom

  def self.current_version(current_version)

    uri = URI("https://roadrunner-staging-5ff1a4e7a439.herokuapp.com/api/v1/next_versions?current_rails_version=#{current_version}")
    res = Net::HTTP.get_response(uri)
    next_versions_res = JSON.parse(res.body)

    return next_versions_res['detail'] if next_versions_res.fetch('detail', false)

    rails_version =
    if next_versions_res['next_rails'].nil?
      "You are on the most current Rails version."
    else
      "The next Rails target jump should be #{next_versions_res['next_rails']}."
    end

    rails_version +=
    if next_versions_res['required_ruby'].any? && next_versions_res['required_ruby'].length == 2
      " The recommended Ruby versions for this jump is #{next_versions_res['required_ruby'][0]}, #{next_versions_res['required_ruby'][1]}."
    elsif next_versions_res['required_ruby'].any? && next_versions_res['required_ruby'].length == 1
      " The recommended Ruby version for this jump is #{next_versions_res['required_ruby'][0]}."
    else
      " There are no Ruby recommendations."
    end

    rails_version

  end

end