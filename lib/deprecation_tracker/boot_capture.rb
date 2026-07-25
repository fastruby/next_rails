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
    # Returned as `[env_hash, *argv]` for `system(*command)` — NOT a shell string —
    # so an operator-supplied `output_path` (via --output) and the gem's RUNNER_PATH
    # can never be word-split or interpreted by a shell (e.g. a path with spaces, or
    # `--output 'x.json; rm -rf foo'`). Values that would have needed quoting in a
    # shell string are ordinary array elements / env values here.
    #
    # Env keys:
    # * CI => nil unsets CI for this one boot. The Rails 7.1+ generated test.rb sets
    #   `config.eager_load = ENV["CI"].present?`, so on CI the app would eager-load
    #   at boot — before the tracker can attach — and the runner would have to refuse.
    #   Unsetting CI keeps that template's eager_load off so capture works even on CI;
    #   apps that hardcode `eager_load = true` are still caught by the runner's guard.
    # * The next bundle sets BUNDLE_GEMFILE=Gemfile.next AND BUNDLE_CACHE_PATH=
    #   vendor/cache.next — the pair `next`/`gem-next-diff` always use together
    #   (exe/next.sh, exe/gem-next-diff). Setting only the Gemfile would resolve
    #   against the current bundle's vendored cache. The current bundle leaves both
    #   at Bundler's defaults (Gemfile, vendor/cache).
    # * RAILS_ENV=test skips dev-only initializers.
    # output_path is required, but declared as an optional kwarg + guard rather
    # than a required kwarg (`output_path:`) so the file parses on Ruby 2.0 — the
    # gem's stated floor, which the rest of the code keeps to.
    def self.boot_command(output_path: nil, next_mode: false)
      raise ArgumentError, "output_path is required" unless output_path
      env = { "CI" => nil, "RAILS_ENV" => "test", OUTPUT_ENV => output_path.to_s }
      if next_mode
        env["BUNDLE_GEMFILE"] = "Gemfile.next"
        env["BUNDLE_CACHE_PATH"] = "vendor/cache.next"
      end
      [env, "bundle", "exec", "rails", "runner", RUNNER_PATH]
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
    #   :eager_load_refused - the runner refused (see EAGER_LOAD_EXIT); explained already
    #   :failed             - the app did not boot; no usable capture
    #   :ok                 - the partial was written and can be promoted
    def self.boot_result(succeeded, exit_status, output_written)
      return :eager_load_refused if exit_status == EAGER_LOAD_EXIT
      return :failed unless succeeded && output_written
      :ok
    end
  end
end
