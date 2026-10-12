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

    it "lists incompatible gems without looking up newer versions when offline" do
      specification = Gem::Specification.new do |s|
        s.name = "audited"
        s.version = "5.1.0"
        s.add_dependency "rails", ">= 5.0", "< 7.1"
      end
      audited = NextRails::GemInfo.new(specification)

      expect(audited).not_to receive(:find_latest_compatible)

      output =
        NextRails::BundleReport::RailsVersionCompatibility.new(
          gems: [audited],
          options: { rails_version: "7.1", include_rails_gems: false, offline: true }
        ).generate

      expect(output).to include("Incompatible with Rails 7.1 (compatible versions not looked up):")
      expect(output).to include("audited 5.1.0")
      expect(output).to include("gems incompatible with Rails 7.1")
    end

    it "prints only the count when offline and nothing is incompatible" do
      output =
        NextRails::BundleReport::RailsVersionCompatibility.new(
          gems: [],
          options: { rails_version: "7.1", include_rails_gems: false, offline: true }
        ).generate

      expect(output).not_to include("=> Incompatible")
      expect(output).to include("gems incompatible with Rails 7.1")
    end

    it "names the gems that pull in an incompatible gem" do
      specification = Gem::Specification.new do |s|
        s.name = "responders"
        s.version = "1.1.2"
        s.add_dependency "railties", ">= 3.2", "< 4.2"
      end
      responders = NextRails::GemInfo.new(specification)
      devise = NextRails::GemInfo.new(Gem::Specification.new { |s| s.name = "devise"; s.version = "3.5.10"; s.add_dependency "responders" })
      inherited_resources = NextRails::GemInfo.new(Gem::Specification.new { |s| s.name = "inherited_resources"; s.version = "1.6.0"; s.add_dependency "responders", "~> 1.0" })
      railties = NextRails::GemInfo.new(Gem::Specification.new { |s| s.name = "railties"; s.version = "4.1.16"; s.add_dependency "responders" })

      output =
        NextRails::BundleReport::RailsVersionCompatibility.new(
          gems: [devise, inherited_resources, railties, responders],
          options: { rails_version: "4.2", offline: true }
        ).generate

      expect(output).to include("(required by devise, inherited_resources (~> 1.0))")
    end
  end

  describe "#incompatible_gems_by_state" do
    it "groups the gems under :not_checked when offline" do
      specification = Gem::Specification.new do |s|
        s.name = "audited"
        s.version = "5.1.0"
        s.add_dependency "rails", ">= 5.0", "< 7.1"
      end
      audited = NextRails::GemInfo.new(specification)

      by_state = NextRails::BundleReport::RailsVersionCompatibility.new(
        gems: [audited],
        options: { rails_version: "7.1", offline: true }
      ).incompatible_gems_by_state

      expect(by_state).to eq(not_checked: [audited])
    end
  end
end

