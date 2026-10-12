# frozen_string_literal: true

require "spec_helper"

require "timecop"
require "tmpdir"

RSpec.describe NextRails::GemInfo do
  describe ".from_lockfile" do
    let(:lockfile) do
      <<-LOCK
GIT
  remote: https://github.com/example/forked_gem.git
  revision: abc123
  specs:
    forked_gem (2.0.0)
      activerecord (>= 3.2, < 4.1)

GEM
  remote: https://rubygems.org/
  specs:
    haml-rails (0.4)
      actionpack (>= 3.1, < 4.1)
    nokogiri (1.6.8-x86_64-linux)
    nokogiri (1.6.8)
      mini_portile2 (~> 2.1.0)

PLATFORMS
  ruby
  x86_64-linux

DEPENDENCIES
  forked_gem!
  haml-rails
  nokogiri
      LOCK
    end

    # The lockfile Bundler would use: the one next to BUNDLE_GEMFILE. BUNDLE_LOCKFILE,
    # which `bundle exec` sets on newer Bundlers, would point at this repo's lockfile.
    def gems_from(lockfile_name)
      Dir.mktmpdir do |dir|
        gemfile = File.join(dir, lockfile_name.sub(/\.lock\z/, ""))
        File.write(gemfile, "source \"https://rubygems.org\"\n")
        File.write("#{gemfile}.lock", lockfile)
        original = ENV.to_h.select { |key, _| %w[BUNDLE_GEMFILE BUNDLE_LOCKFILE].include?(key) }
        begin
          ENV["BUNDLE_GEMFILE"] = gemfile
          ENV.delete("BUNDLE_LOCKFILE")
          described_class.from_lockfile
        ensure
          %w[BUNDLE_GEMFILE BUNDLE_LOCKFILE].each { |key| ENV[key] = original[key] }
        end
      end
    end

    it "reads each locked gem's version and runtime dependencies from the lockfile" do
      haml_rails = gems_from("Gemfile.lock").find { |gem| gem.name == "haml-rails" }

      expect(haml_rails.version).to eq(Gem::Version.new("0.4"))
      expect(haml_rails.unsatisfied_rails_dependencies(rails_version: "4.1").map(&:name)).to eq(["actionpack"])
      expect(haml_rails.compatible_with_rails?(rails_version: "4.0.13")).to be(true)
    end

    it "reads the lockfile of the Gemfile BUNDLE_GEMFILE names" do
      expect(gems_from("Gemfile.next.lock").map(&:name)).to include("haml-rails")
    end

    it "keeps one gem per name, preferring the plain platform variant" do
      nokogiri = gems_from("Gemfile.lock").select { |gem| gem.name == "nokogiri" }

      expect(nokogiri.length).to eq(1)
      expect(nokogiri.first.gem_specification.runtime_dependencies.map(&:name)).to eq(["mini_portile2"])
    end

    it "marks gems that come from git" do
      gems = gems_from("Gemfile.lock")

      expect(gems.find { |gem| gem.name == "forked_gem" }.sourced_from_git?).to be(true)
      expect(gems.find { |gem| gem.name == "haml-rails" }.sourced_from_git?).to be(false)
    end
  end

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

  describe "#sourced_locally?" do
    let(:source) { nil }
    let(:spec) do
      Gem::Specification.new do |s|
        s.date = release_date
        s.version = "1.0.0"
        s.source = source
      end
    end

    context "when the gem is sourced from a local path" do
      let(:source) { Bundler::Source::Path.new("path" => "engines/foo") }

      it "is true" do
        expect(subject.sourced_locally?).to be(true)
      end
    end

    context "when the gem is sourced from git" do
      let(:source) { Bundler::Source::Git.new("uri" => "https://example.com/foo.git") }

      it "is false (git is reported separately)" do
        expect(subject.sourced_locally?).to be(false)
      end
    end

    context "when the gem is sourced from rubygems" do
      let(:source) { Bundler::Source::Rubygems.new }

      it "is false" do
        expect(subject.sourced_locally?).to be(false)
      end
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
