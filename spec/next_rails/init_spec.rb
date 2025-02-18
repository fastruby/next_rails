# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe NextRails::Init do
  let(:gemfile_content) { "source 'https://rubygems.org'\ngem 'rails'\n" }

  before(:all) do
    FileUtils.cp('Gemfile', 'Gemfile.original')
  end

  after(:all) do
    FileUtils.cp('Gemfile.original', 'Gemfile')
    FileUtils.rm_f('Gemfile.original')
  end

  before do
    FileUtils.rm_f('Gemfile')
    FileUtils.rm_f('Gemfile.lock')
    FileUtils.rm_f('Gemfile.next')
    FileUtils.rm_f('Gemfile.next.lock')
  end

  after do
    FileUtils.rm_f('Gemfile')
    FileUtils.rm_f('Gemfile.lock')
    FileUtils.rm_f('Gemfile.next')
    FileUtils.rm_f('Gemfile.next.lock')
  end

  describe '.call' do
    it 'already has next Gemfile files' do
      File.write('Gemfile', gemfile_content)
      FileUtils.touch('Gemfile.lock')
      File.write('Gemfile.next', gemfile_content)

      expect(described_class.call).to eq('The next_rails --init command has already been run.')
    end

    it 'does not have Gemfile files' do
      expect(described_class.call).to eq('You must have a Gemfile and Gemfile.lock to run the next_rails --init command.')
    end

    it 'creates Gemfile.next and Gemfile.next.lock' do
      File.write('Gemfile', gemfile_content)
      FileUtils.touch('Gemfile.lock')

      expect do
        described_class.call
      end.to change { File.exist?('Gemfile.next') }.from(false).to(true)
         .and change { File.exist?('Gemfile.next.lock') }.from(false).to(true)
    end

    it 'returns a success message' do
      File.write('Gemfile', gemfile_content)
      FileUtils.touch('Gemfile.lock')

      message = described_class.call
      expect(message).to include('Created Gemfile.next (a symlink to your Gemfile).')
      expect(message).to include("For example, here's how to go from 5.2.8.1 to 6.0.6.1:")
    end
  end
end
