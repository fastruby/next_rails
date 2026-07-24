# frozen_string_literal: true

class DeprecationTracker
  # Capture deprecation warnings emitted while the app EAGER-LOADS its classes --
  # the association / scope / callback declaration warnings that fire when a class
  # body is evaluated -- rather than during a test run.
  #
  # This is the one such surface the test-run tracker structurally misses:
  # `track_rspec` / `track_minitest` attach per-example, so a warning that fires at
  # class-body-evaluation time never reaches them. Eager-loading the whole app with
  # the tracker already listening surfaces exactly those.
  #
  # Scope: warnings emitted EARLIER in boot -- during `Bundler.require` or the
  # framework/app initializers, before `rails runner` hands control to the runner
  # script and the tracker attaches -- are NOT captured. Only eager-load-time (and
  # later) warnings are in scope.
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

    # Exit status the runner uses when it refuses because the environment
    # eager-loads at boot (see boot_capture_runner.rb). The CLI branches on this
    # so the runner's specific explanation isn't buried under a generic
    # "boot failed" guess.
    EAGER_LOAD_EXIT = 3

    # Follows the tracker's spec/support convention (DeprecationTracker::DEFAULT_PATH
    # is spec/support/deprecation_warning.shitlist.json); ".boot" keeps the boot
    # capture from clobbering the test-run shitlist, ".next" separates the bundles.
    def self.default_output_path(next_mode: false)
      name = next_mode ? "deprecation_warning.boot.next.shitlist.json" : "deprecation_warning.boot.shitlist.json"
      File.join("spec", "support", name)
    end

    # The command that boots the app (via `rails runner`, which fully boots and so
    # registers the framework deprecators the runner attaches to) and runs the
    # gem's runner script.
    #
    # `CI=` blanks the CI env var for this one boot. The Rails 7.1+ generated
    # test.rb sets `config.eager_load = ENV["CI"].present?`, so on CI the app
    # would eager-load at boot — before the tracker can attach — and the runner
    # would have to refuse. Forcing CI blank keeps that template's eager_load off
    # so capture works even on CI; apps that hardcode `eager_load = true` are
    # still caught by the runner's guard.
    #
    # The next bundle is selected with BUNDLE_GEMFILE=Gemfile.next (what `bin/next`
    # wraps, and it works in projects that never generated the shim). RAILS_ENV=test
    # skips dev-only initializers.
    def self.boot_command(output_path:, next_mode: false)
      env = "CI= RAILS_ENV=test"
      env += " BUNDLE_GEMFILE=Gemfile.next" if next_mode
      env += " #{OUTPUT_ENV}=#{output_path}"
      "#{env} bundle exec rails runner #{RUNNER_PATH}"
    end
  end
end
