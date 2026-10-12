# frozen_string_literal: true

# No requires: exe/bundle_report loads this before bundler/setup, to decide whether to run it.
module NextRails
  module BundleReport
    module Options
      # OptionParser also accepts a unique prefix of a long option (--off for --offline),
      # so an exact match would miss those.
      def self.given?(argv, option)
        argv.any? do |arg|
          name = arg.split("=", 2).first
          name.length > 2 && option.start_with?(name)
        end
      end
    end
  end
end
