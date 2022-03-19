# frozen_string_literal: true

require 'date'
require 'tempfile'
require_relative 'spec_helper'
require_relative '../lib/next_rails/bundle_report'

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
      subject { described_class.outdated }

      it 'invokes $stdout.puts properly', :aggregate_failures do
        allow($stdout)
          .to receive(:puts)
          .with("#{'alpha 0.0.1'.bold.white}: released #{alpha_age} (latest version, 0.0.2, released #{bravo_age})\n")
        allow($stdout)
          .to receive(:puts)
          .with("#{'bravo 0.2.0'.bold.white}: released #{bravo_age} (latest version, 0.2.2, released #{charlie_age})\n")
        allow($stdout).to receive(:puts).with('')
        allow($stdout).to receive(:puts).with(<<~EO_MULTLINE_STRING)
          #{'1'.yellow} gems are sourced from git
          #{'2'.red} of the 2 gems are out-of-date (100%)
        EO_MULTLINE_STRING

        subject
      end
    end
  end
end
