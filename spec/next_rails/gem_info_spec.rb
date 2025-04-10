# frozen_string_literal: true

require "spec_helper"

require "timecop"

RSpec.describe NextRails::GemInfo do
  let(:release_date) { Time.utc(2019, 7, 6, 0, 0, 0) }
  let(:now) { Time.utc(2019, 7, 6, 12, 0, 0) }
  let(:spec) do
    Gem::Specification.new do |s|
      s.date = release_date
      s.version = "1.0.0"
    end
  end

  subject { NextRails::GemInfo.new(spec) }

  describe "#age" do
    around do |example|
      Timecop.travel(now) do
        example.run
      end
    end

    let(:result) { now.strftime("%b %e, %Y") }

    it "returns a date" do
      expect(subject.age).to eq(result)
    end
  end

  describe "#up_to_date?" do
    it "is up to date" do
      allow(Gem).to receive(:latest_spec_for).and_return(spec)
      expect(subject.up_to_date?).to be_truthy
    end
  end

  describe "#state" do
    let(:mock_gem) { Struct.new(:name, :version, :runtime_dependencies) }
    let(:mocked_dependency) { Struct.new(:name, :requirement) }

    it "returns :incompatible if gem specifies a rails dependency but no compatible version is found" do
      # set up a mock gem with with a rails dependency that is unsatisfied by the version given
      mocked_dependency_requirement = double("requirement")
      allow(mocked_dependency_requirement).to receive(:satisfied_by?).and_return(false)
      runtime_deps = [mocked_dependency.new("rails", mocked_dependency_requirement)]
      incompatible_gem = mock_gem.new('incompatible', '0.0.1', runtime_deps)

      rails_version = "7.0.0"
      gem_info = NextRails::GemInfo.new(incompatible_gem)

      expect(gem_info.state(rails_version)).to eq(:incompatible)
    end

    it "returns :no_new_version if a gem specifies an unsatisfied rails dependency and no other specs are returned" do
      # set up a mock gem with with a rails dependency that is unsatisfied by the version given
      mocked_dependency_requirement = double("requirement")
      allow(mocked_dependency_requirement).to receive(:satisfied_by?).and_return(false)
      runtime_deps = [mocked_dependency.new("rails", mocked_dependency_requirement)]
      incompatible_gem = mock_gem.new('incompatible', '0.0.1', runtime_deps)

      # Set up a mock SpecFetcher to return an empty list
      fetcher_double = double("spec_fetcher")
      allow(fetcher_double).to receive(:available_specs).and_return([[],[]])
      allow(Gem::SpecFetcher).to receive(:new).and_return(fetcher_double)

      rails_version = "7.0.0"
      gem_info = NextRails::GemInfo.new(incompatible_gem)
      gem_info.find_latest_compatible

      expect(gem_info.state(rails_version)).to eq(:no_new_version)
    end
  end

  describe "#find_latest_compatible" do
    let(:mock_gem) { Struct.new(:name, :version) }

    it "sets latest_compatible_version to NullGem if no specs are found" do
      gem = mock_gem.new('gem_name', "0.0.1")

      # Set up a mock SpecFetcher to return an empty list
      fetcher_double = double("spec_fetcher")
      allow(fetcher_double).to receive(:available_specs).and_return([[],[]])
      allow(Gem::SpecFetcher).to receive(:fetcher).and_return(fetcher_double)

      gem_info = NextRails::GemInfo.new(gem)
      gem_info.find_latest_compatible
      expect(gem_info.latest_compatible_version).to be_a(NextRails::GemInfo::NullGemInfo)
    end
  end
end
