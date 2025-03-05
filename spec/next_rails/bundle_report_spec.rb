# frozen_string_literal: true

require "rainbow"
require "spec_helper"

RSpec.describe NextRails::BundleReport do
  describe '.outdated' do
    let(:mock_version) { Struct.new(:version, :age) }
    let(:mock_gem) { Struct.new(:name, :version, :age, :latest_version, :up_to_date?, :created_at, :sourced_from_git?) }
    let(:format_str) { '%b %e, %Y' }
    let(:alpha_date) { Date.parse('2022-01-01') }
    let(:alpha_age) { alpha_date.strftime(format_str) }
    let(:bravo_date) { Date.parse('2022-02-02') }
    let(:bravo_age) { bravo_date.strftime(format_str) }
    let(:charlie_date) { Date.parse('2022-03-03') }
    let(:charlie_age) { charlie_date.strftime(format_str) }

    before do
      allow(NextRails::GemInfo).to receive(:all).and_return(
        [
          mock_gem.new('alpha', '0.0.1', alpha_age, mock_version.new('0.0.2', bravo_age), false, alpha_date, false),
          mock_gem.new('bravo', '0.2.0', bravo_age, mock_version.new('0.2.2', charlie_age), false, bravo_date, true)
        ]
      )
    end

    context 'when writing human-readable output' do
      #subject { described_class.outdated }

      it 'invokes $stdout.puts properly', :aggregate_failures do
        allow($stdout)
          .to receive(:puts)
          .with("#{Rainbow('alpha 0.0.1').bold.white}: released #{alpha_age} (latest version, 0.0.2, released #{bravo_age})\n")
        allow($stdout)
          .to receive(:puts)
          .with("#{Rainbow('bravo 0.2.0').bold.white}: released #{bravo_age} (latest version, 0.2.2, released #{charlie_age})\n")
        allow($stdout).to receive(:puts).with('')
        allow($stdout).to receive(:puts).with(<<-EO_MULTLINE_STRING)
          #{Rainbow('1').yellow} gems are sourced from git
          #{Rainbow('2').red} of the 2 gems are out-of-date (100%)
        EO_MULTLINE_STRING
      end
    end

    context 'when writing JSON output' do
      it 'JSON is correctly formatted' do
        gems = NextRails::GemInfo.all
        out_of_date_gems = gems.reject(&:up_to_date?).sort_by(&:created_at)
        sourced_from_git = gems.select(&:sourced_from_git?)

        expect(NextRails::BundleReport.build_json(out_of_date_gems, gems.count, sourced_from_git.count)).to eq(
          {
            outdated_gems: [
              { name: 'alpha', installed_version: '0.0.1', installed_age: alpha_age, latest_version: '0.0.2',
                latest_age: bravo_age },
              { name: 'bravo', installed_version: '0.2.0', installed_age: bravo_age, latest_version: '0.2.2',
                latest_age: charlie_age }
            ],
            sourced_from_git_count: sourced_from_git.count,
            total_gem_count: gems.count
          }
        )
      end
    end
  end

  describe ".rails_compatibility" do
    it "returns empty output invalid rails version" do
      output = with_captured_stdout do
        NextRails::BundleReport.rails_compatibility(rails_version: nil)
      end
      expect(output).to be_empty
    end
  end

  describe ".ruby_compatibility" do
    it "returns empty output invalid ruby version" do
      output = with_captured_stdout do
        NextRails::BundleReport.ruby_compatibility(ruby_version: nil)
      end
      expect(output).to be_empty
    end
  end

  describe "#compatible_ruby_version" do
    context "when rails_version is a valid one" do
      it "returns the correct ruby version" do
        rails_version = { rails_version: "7.0.0" }
        ruby_version = NextRails::BundleReport.compatible_ruby_version(rails_version)
        expect(ruby_version).to eq(">= 2.7.0")
      end
    end

    context "when partial rails_version is passed as argument" do
      it "returns the correct ruby version" do
        rails_version = { rails_version: "7.0" }
        ruby_version = NextRails::BundleReport.compatible_ruby_version(rails_version)
        expect(ruby_version).to eq(">= 2.7.0")
      end
    end

    context "when rails_version is an invalid one" do
      it "returns nil for ruby version" do
        rails_version = { rails_version: "0.0.0" }
        ruby_version = NextRails::BundleReport.compatible_ruby_version(rails_version)
        expect(ruby_version).to eq(nil)
      end
    end
  end
end
