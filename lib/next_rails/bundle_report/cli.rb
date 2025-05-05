# frozen_string_literal: true
class NextRails::BundleReport::CLI
  def initialize(argv)
    validate_arguments(argv)
  end

  def validate_arguments(argv)
    #
  end

  def generate
    # Print a report on our Gemfile
    # Why not just use `bundle outdated`? It doesn"t give us the information we care about (and it fails).
    at_exit do
      require "optparse"
      require "next_rails"

      options = {}
      option_parser = OptionParser.new do |opts|
        opts.banner = <<-EOS
          Usage: #{$0} [report-type] [options]

          report-type  There are two report types available: `outdated` and `compatibility`

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

        opts.on("--rails-version [STRING]", "Rails version to check compatibility against (defaults to 5.0)") do |rails_version|
          options[:rails_version] = rails_version
        end

        opts.on("--ruby-version [STRING]", "Ruby version to check compatibility against (defaults to 2.3)") do |ruby_version|
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
        option_parser.parse!
      rescue OptionParser::ParseError => e
        STDERR.puts Rainbow(e.message).red
        puts option_parser
        exit 1
      end

      report_type = ARGV.first

      case report_type
      when "ruby_check" then NextRails::BundleReport.compatible_ruby_version(rails_version: options.fetch(:rails_version))
      when "outdated" then bundle_report = NextRails::BundleReport.new
        bundle_report.(options.fetch(:format, nil))
      else
        if options[:ruby_version]
          NextRails::BundleReport.ruby_compatibility(ruby_version: options.fetch(:ruby_version, "2.3"))
        else
          NextRails::BundleReport.rails_compatibility(rails_version: options.fetch(:rails_version, "5.0"), include_rails_gems: options.fetch(:include_rails_gems, false))
        end
      end
    end

    # Needs to happen first
    require "bundler/setup"

  end
end
