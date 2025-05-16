# frozen_string_literal: true

require "optparse"
require "next_rails"
require "next_rails/bundle_report"
require 'byebug'

class NextRails::BundleReport::CLI
  def initialize(argv)
    validate_arguments(argv)
    @argv = argv
  end

  def validate_arguments(argv)
    return unless argv.any?

    valid_report_types = %w[outdated compatibility ruby_check]
    report_type = argv.first

    unless valid_report_types.include?(report_type)
      raise ArgumentError, "Invalid report type '#{report_type}'. Valid types are: #{valid_report_types.join(', ')}."
    end

    argv.each do |arg|
      if arg.start_with?("--rails-version") && !/--rails-version=+\d+(\.\d+)*$/.match(arg)
        raise ArgumentError, "Invalid Rails version format. Example: --rails-version=5.0.7"
      end

      if arg.start_with?("--ruby-version") && !/--ruby-version=+\d+(\.\d+)*$/.match(arg)
        raise ArgumentError, "Invalid Ruby version format. Example: --ruby-version=3.3"
      end
    end
  end

  def run
    options = parse_options
    execute_report(@argv.first, options)
  end

  private

  def parse_options
    options = {}
    option_parser = OptionParser.new do |opts|
      opts.banner = <<-EOS
        Usage: #{$0} [report-type] [options]

        report-type  There are three report types available: `outdated`, `compatibility` and `ruby_check`.

        Examples:
          #{$0} compatibility --rails-version 5.0
          #{$0} compatibility --ruby-version 3.3
          #{$0} outdated
          #{$0} outdated --json

        ruby_check To find a compatible ruby version for the target rails version

        Examples:
          #{$0} ruby_check --rails-version 7.0.0

      EOS

      opts.separator ""
      opts.separator "Options:"

      opts.on("--rails-version [STRING]",
              "Rails version to check compatibility against (defaults to 5.0)") do |rails_version|
        options[:rails_version] = rails_version
      end

      opts.on("--ruby-version [STRING]",
              "Ruby version to check compatibility against (defaults to 2.3)") do |ruby_version|
        options[:ruby_version] = ruby_version
      end

      opts.on("--include-rails-gems", "Include Rails gems in compatibility report (defaults to false)") do
        options[:include_rails_gems] = true
      end

      opts.on("--json", "Output JSON in outdated report (defaults to false)") do
        options[:format] = "json"
      end

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    begin
      option_parser.parse!(@argv)
    rescue OptionParser::ParseError => e
      warn Rainbow(e.message).red
      puts option_parser
      exit 1
    end

    options
  end

  def execute_report(report_type, options)
    case report_type
    when "ruby_check"
      NextRails::BundleReport.compatible_ruby_version(rails_version: options.fetch(:rails_version))
    when "outdated"
      NextRails::BundleReport.outdated(options.fetch(:format, nil))
    else
      if options[:ruby_version]
        NextRails::BundleReport.ruby_compatibility(ruby_version: options.fetch(:ruby_version, "2.3"))
      else
        NextRails::BundleReport.rails_compatibility(
          rails_version: options.fetch(:rails_version, "5.0"),
          include_rails_gems: options.fetch(:include_rails_gems, false)
        )
      end
    end
  end
end
