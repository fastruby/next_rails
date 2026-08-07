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
  # The runner boots the app itself (require config/application, configure, then
  # initialize!) rather than running inside an already-initialized `rails runner`,
  # so initializer-time and gem-load-time warnings are in scope too. See
  # boot_capture_runner.rb for what remains out of reach (config/boot.rb, and
  # deprecator-based warnings during Bundler.require).
  #
  # It deliberately does NOT reimplement any capture logic. `boot_capture_runner.rb`
  # drives the existing DeprecationTracker (init_tracker installs the
  # version-correct hooks; add / after_run collect and write). BootCapture only
  # provides the command that runs that script in the app's bundle.
  #
  # Kept compatible with the gem's supported Rubies (>= 2.0): no safe-navigation,
  # no squiggly heredocs, stdlib only.
  class BootCapture
    # The runner script shipped with the gem, run with `bundle exec ruby`.
    RUNNER_PATH = File.expand_path("boot_capture_runner.rb", __dir__)

    # Env var the command uses to tell the runner where to write the shitlist.
    OUTPUT_ENV = "DEPRECATION_BOOT_OUTPUT"

    # Env var the command uses to tell the runner which directory holds
    # config/application.rb. The CLI runs from the app root, so this is Dir.pwd.
    APP_ROOT_ENV = "DEPRECATION_BOOT_APP_ROOT"

    # Exit status the runner uses when there is no config/application.rb to load
    # (the CLI was run outside a Rails app root). The CLI branches on this so the
    # runner's specific explanation isn't buried under a generic "boot failed" guess.
    NO_APP_EXIT = 4

    # Follows the tracker's spec/support convention (DeprecationTracker::DEFAULT_PATH
    # is spec/support/deprecation_warning.shitlist.json); ".boot" keeps the boot
    # capture from clobbering the test-run shitlist, ".next" separates the bundles.
    def self.default_output_path(next_mode: false)
      name = next_mode ? "deprecation_warning.boot.next.shitlist.json" : "deprecation_warning.boot.shitlist.json"
      File.join("spec", "support", name)
    end

    # The command that runs the gem's runner script in the app's bundle. Plain
    # `bundle exec ruby`, not `rails runner`: the runner boots the app itself so it
    # can attach before the initializers run, and `rails runner` would have already
    # booted it (and, on Rails 3.x, would eval the script instead of loading it).
    #
    # Returned as `[env_hash, *argv]` for `system(*command)` — NOT a shell string —
    # so neither the output path nor the gem's RUNNER_PATH can be word-split or
    # interpreted by a shell (a checkout living under a path with spaces is enough
    # to matter). Values that would have needed quoting are ordinary array elements
    # and env values here.
    #
    # Env keys:
    # * APP_ROOT_ENV tells the runner where config/application.rb lives. The CLI is
    #   run from the app root, so it is Dir.pwd. CI is deliberately left alone: the
    #   runner attaches before initialize!, so an environment that eager-loads at
    #   boot (the generated test.rb ties config.eager_load to ENV["CI"]) is captured
    #   rather than refused, and this boot sees the same config CI would.
    # * The next bundle sets BUNDLE_GEMFILE=Gemfile.next AND BUNDLE_CACHE_PATH=
    #   vendor/cache.next — the pair `next`/`gem-next-diff` always use together
    #   (exe/next.sh, exe/gem-next-diff). Setting only the Gemfile would resolve
    #   against the current bundle's vendored cache. The current bundle leaves both
    #   at Bundler's defaults (Gemfile, vendor/cache).
    # * RAILS_ENV=test skips dev-only initializers.
    # output_path is required, but declared as an optional kwarg + guard rather
    # than a required kwarg (`output_path:`) so the file parses on Ruby 2.0 — the
    # gem's stated floor, which the rest of the code keeps to.
    def self.boot_command(output_path: nil, next_mode: false, app_root: nil)
      raise ArgumentError, "output_path is required" unless output_path
      env = {
        "RAILS_ENV" => "test",
        OUTPUT_ENV => output_path.to_s,
        APP_ROOT_ENV => (app_root || Dir.pwd).to_s
      }
      if next_mode
        env["BUNDLE_GEMFILE"] = "Gemfile.next"
        env["BUNDLE_CACHE_PATH"] = "vendor/cache.next"
      end
      [env, "bundle", "exec", "ruby", RUNNER_PATH]
    end

    # A human-readable, shell-like rendering of `boot_command` for logging. Not
    # executed — `system(*boot_command(...))` runs the real thing without a shell.
    # Unset (nil) env vars are omitted rather than shown as `KEY=`, which would
    # read as "blanked" and contradict the unset semantics the command relies on.
    def self.command_display(command)
      env, argv = command[0], command[1..-1]
      env_str = env.reject { |_key, value| value.nil? }.map { |key, value| "#{key}=#{value}" }.join(" ")
      parts = env_str.empty? ? argv : [env_str] + argv
      parts.join(" ")
    end

    # The sibling file the CLI writes to, renamed onto output_path only on success
    # so a failed/refused boot never destroys a previous capture.
    def self.partial_path_for(output_path)
      "#{output_path}.partial"
    end

    # Classify a boot attempt from its process result so the CLI's branching is
    # testable without shelling out. `succeeded` is the truthiness of system's
    # return, `exit_status` the child's exit code (nil if it couldn't run),
    # `output_written` whether the partial file exists afterward.
    #   :no_app - there is no config/application.rb to boot; explained already
    #   :failed - the app did not boot; no usable capture
    #   :ok     - the partial was written and can be promoted
    def self.boot_result(succeeded, exit_status, output_written)
      return :no_app if exit_status == NO_APP_EXIT
      return :failed unless succeeded && output_written
      :ok
    end
  end
end
