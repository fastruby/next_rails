# frozen_string_literal: true

class DeprecationTracker
  # Capture deprecation warnings emitted at BOOT time -- while the app runs its
  # initializers and eager-loads its classes -- rather than during a test run.
  #
  # This is the one deprecation surface the test-run tracker structurally misses.
  # `track_rspec` / `track_minitest` attach per-example, so a warning that fires
  # when a class body is evaluated (association / scope / callback declarations)
  # never reaches them. Eager-loading the whole app with the tracker already
  # listening surfaces exactly those.
  #
  # It deliberately does NOT reimplement any capture logic. `boot_capture_runner.rb`
  # drives the existing DeprecationTracker (init_tracker installs the
  # version-correct hooks; add / after_run collect and write). BootCapture only
  # provides the command that boots the app and runs that script.
  #
  # Kept compatible with the gem's supported Rubies (>= 2.0): no safe-navigation,
  # no squiggly heredocs, stdlib only.
  class BootCapture
    # The runner script shipped with the gem and executed via `rails runner`.
    RUNNER_PATH = File.expand_path("boot_capture_runner.rb", __dir__)

    # Env var the command uses to tell the runner where to write the shitlist.
    OUTPUT_ENV = "DEPRECATION_BOOT_OUTPUT"

    # Follows the tracker's spec/support convention (DeprecationTracker::DEFAULT_PATH
    # is spec/support/deprecation_warning.shitlist.json); ".boot" keeps the boot
    # capture from clobbering the test-run shitlist, ".next" separates the bundles.
    def self.default_output_path(next_mode: false)
      name = next_mode ? "deprecation_warning.boot.next.shitlist.json" : "deprecation_warning.boot.shitlist.json"
      File.join("spec", "support", name)
    end

    # The command that boots the app and runs the gem's runner script. The next
    # bundle is selected with BUNDLE_GEMFILE=Gemfile.next (what `bin/next` wraps,
    # and it works in projects that never generated the shim). RAILS_ENV=test
    # skips dev-only initializers and matches CI.
    def self.boot_command(output_path:, next_mode: false)
      env = "RAILS_ENV=test"
      env += " BUNDLE_GEMFILE=Gemfile.next" if next_mode
      env += " #{OUTPUT_ENV}=#{output_path}"
      "#{env} bundle exec rails runner #{RUNNER_PATH}"
    end
  end
end
