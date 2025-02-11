# frozen_string_literal: true

require "spec_helper"

RSpec.describe NextRails::BundleReport::RubyVersionCompatibility do
  let(:ruby_3_0_gem) do
    Gem::Specification.new do |s|
      s.name = "ruby_3_0_gem"
      s.version = "1.0.0"
      s.required_ruby_version = ">= 3.0"
    end
  end

  let(:ruby_2_5_gem) do
    Gem::Specification.new do |s|
      s.name = "ruby_2_5_gem"
      s.version = "1.0.0"
      s.required_ruby_version = ">= 2.5"
    end
  end

  let(:ruby_2_3_to_2_5_gem) do
    Gem::Specification.new do |s|
      s.name = "ruby_2_3_to_2_5_gem"
      s.version = "1.0.0"
      s.required_ruby_version = [">= 2.3", "< 2.5"]
    end
  end

  let(:no_ruby_version_gem) do
    Gem::Specification.new do |s|
      s.name = "no_ruby_version_gem"
      s.version = "1.0.0"
    end
  end

  describe "#generate" do
    context "with invalid ruby version" do
      it "returns invalid message" do
        options = { ruby_version: "hola" }

        result = described_class.new(gems: [], options: options).generate
        expect(result).to include "Invalid Ruby version: hola"
      end
    end

    context "with valid ruby version" do
      it "returns 0 incompatible gems" do
        options = { ruby_version: "3.0" }
        gems = [NextRails::GemInfo.new(ruby_3_0_gem)]

        result = described_class.new(gems: gems, options: options).generate
        expect(result).to include "0 incompatible gems with Ruby 3.0"
      end

      it "returns 1 incompatible gem" do
        options = { ruby_version: "2.5" }
        gems = [NextRails::GemInfo.new(ruby_3_0_gem)]

        result = described_class.new(gems: gems, options: options).generate

        expect(result).to include "Incompatible gems with Ruby 2.5"
        expect(result).to include "ruby_3_0_gem - required Ruby version: >= 3.0"
        expect(result).to include "1 incompatible gem with Ruby 2.5"
      end

      it "returns 2 incompatible gems" do
        options = { ruby_version: "2.7" }
        gems = [
          NextRails::GemInfo.new(ruby_3_0_gem),
          NextRails::GemInfo.new(ruby_2_5_gem),
          NextRails::GemInfo.new(ruby_2_3_to_2_5_gem),
          NextRails::GemInfo.new(no_ruby_version_gem)
        ]

        result = described_class.new(gems: gems, options: options).generate

        expect(result).to include "Incompatible gems with Ruby 2.7"
        expect(result).to include "ruby_3_0_gem - required Ruby version: >= 3.0"
        expect(result).to include "ruby_2_3_to_2_5_gem - required Ruby version:" # >= 2.3, < 2.5"
        expect(result).to include "2 incompatible gems with Ruby 2.7"
      end
    end
  end
end
