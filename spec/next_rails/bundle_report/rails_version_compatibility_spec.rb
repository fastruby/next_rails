# frozen_string_literal: true

require "spec_helper"

RSpec.describe NextRails::BundleReport::RailsVersionCompatibility do
  describe "#generate" do
    it "returns non incompatible gems" do
      output = NextRails::BundleReport::RailsVersionCompatibility.new(options: { rails_version: 7.0 }).generate
      expect(output).to match "gems incompatible with Rails 7.0"
    end

    it "returns incompatible with compatible versions" do
      next_rails_version = 7.1
      specification = Gem::Specification.new do |s|
        s.name = "audited"
        s.version = "5.1.0"
        s.add_dependency "rails", ">= 5.0", "< 7.1"
      end
      audited = NextRails::GemInfo.new(specification)
      gems = [audited]

      allow_any_instance_of(described_class).to receive(:incompatible_gems_by_state)
        .and_return({ found_compatible: gems })

      allow(audited).to receive(:latest_compatible_version).and_return(Gem::Version.new("5.8.0"))

      output =
        NextRails::BundleReport::RailsVersionCompatibility.new(
          gems: gems,
          options: { rails_version: next_rails_version, include_rails_gems: false }
        ).generate

      expect(output).to include("Incompatible with Rails 7.1 (with new versions that are compatible):")
      expect(output).to include("These gems will need to be upgraded before upgrading to Rails 7.1.")
      expect(output).to include("- upgrade to 5.8.0")
      expect(output).to include("gems incompatible with Rails 7.1")
    end
  end
end

