# frozen_string_literal: true

require 'fileutils'

module NextRails
  # This class is responsible for installing the dual-boot files for your.
  class Init
    def self.call(opts)
      new(opts).call
    end

    def initialize(opts)
      @opts = opts
    end

    def call
      return gemfiles_message unless gemfiles?
      return next_gemfiles_message if next_gemfiles?

      add_next_conditional
      create_sym_link
      copy_gemfile_lock
      message
    end

    private

    def gemfiles?
      %w[Gemfile Gemfile.lock].any? { |file| File.exist?(file) }
    end

    def gemfiles_message
      'You must have a Gemfile and Gemfile.lock to run the next_rails --init command.'
    end

    def next_gemfiles?
      %w[Gemfile.next Gemfile.next.lock].any? { |file| File.exist?(file) }
    end

    def next_gemfiles_message
      'The next_rails --init command has already been run.'
    end

    def add_next_conditional
      File.open('Gemfile.tmp', 'w') do |file|
        file.write <<-STRING
def next?
  File.basename(__FILE__) == "Gemfile.next"
end
        STRING
      end

      File.open('Gemfile', 'r') do |original|
        File.open('Gemfile.tmp', 'a') do |temp|
          temp.write(original.read)
        end
      end

      File.rename('Gemfile.tmp', 'Gemfile')
    end

    def create_sym_link
      File.symlink('Gemfile', 'Gemfile.next')
    end

    def copy_gemfile_lock
      FileUtils.cp('Gemfile.lock', 'Gemfile.next.lock')
    end

    def message
      @opts ? upgrade_message : init_message
    end

    def init_message
      <<-MESSAGE
Created Gemfile.next (a symlink to your Gemfile). Your Gemfile has been modified to support dual-booting!

There's just one more step: modify your Gemfile to use a newer version of Rails using the \`next?\` helper method.

For example, here's how to go from 5.2.8.1 to 6.0.6.1:

if next?
  gem "rails", "6.0.6.1"
else
  gem "rails", "5.2.8.1"
end
      MESSAGE
    end

    def upgrade_message
      "Created Gemfile.next (a symlink to your Gemfile). Your Gemfile has been modified to support dual-booting!"
    end
  end
end
