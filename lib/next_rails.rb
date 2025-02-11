# frozen_string_literal: true

require "next_rails/gem_info"
require "next_rails/version"
require "next_rails/init"
require "next_rails/bundle_report"
require "next_rails/bundle_report/ruby_version_compatibility"
require "next_rails/bundle_report/rails_version_compatibility"
require "deprecation_tracker"

module NextRails
  @@next_bundle_gemfile = nil

  # This method will check your environment
  # (e.g. `ENV['BUNDLE_GEMFILE]`) to determine whether your application is
  # running with the next set of dependencies or the current set of dependencies.
  #
  # @return [Boolean]
  def self.next?
    return @@next_bundle_gemfile unless @@next_bundle_gemfile.nil?

    @@next_bundle_gemfile = File.exist?(ENV["BUNDLE_GEMFILE"]) && File.basename(ENV["BUNDLE_GEMFILE"]) == "Gemfile.next"
  end

  # This method will reset the @@next_bundle_gemfile variable. Then next time
  # you call `NextRails.next?` it will check the environment once again.
  def self.reset_next_bundle_gemfile
    @@next_bundle_gemfile = nil
  end
end
