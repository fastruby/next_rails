# frozen_string_literal: true

require "spec_helper"

RSpec.describe NextRails::BundleReport::RailsVersionCompatibility do
  describe "generate" do
    it "returns non incompatible gems" do
      output = NextRails::BundleReport::RailsVersionCompatibility.new(options: { rails_version: 7.0 }).generate
      expect(output).to match "gems incompatible with Rails 7.0"
    end
  end
end

