require 'spec_helper'
require 'byebug'

RSpec.describe NextRails::BundleReport::CLI do
  describe '#initialize' do
    it 'raises if called with invalid arguments' do
      expect { described_class.new(['invalid_report_type']) }
        .to raise_error(ArgumentError,
                        /Invalid report type 'invalid_report_type'. Valid types are: outdated, compatibility, ruby_check./)
    end

    it 'calls outdated if called with outdated' do
      expect(NextRails::BundleReport).to receive(:outdated)
      described_class.new(['outdated']).run
    end

    it 'calls compatible_ruby_version if called with ruby_check' do
      expect(NextRails::BundleReport).to receive(:compatible_ruby_version)
      described_class.new(['ruby_check', '--rails-version=7.0.0']).run
    end

    it 'calls rails_compatibility if called with compatibility with rails-version option' do
      expect(NextRails::BundleReport).to receive(:rails_compatibility)
      described_class.new(['compatibility', '--rails-version=7.0.0']).run
    end

    it 'calls ruby_compatibility if called with compatibility with ruby-version option' do
      expect(NextRails::BundleReport).to receive(:ruby_compatibility)
      described_class.new(['compatibility', '--ruby-version=3.2.0']).run
    end
  end
end
