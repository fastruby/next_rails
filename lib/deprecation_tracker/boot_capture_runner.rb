# frozen_string_literal: true

# Executed inside a booted app via `rails runner` (see BootCapture.boot_command).
# NOT meant to be `require`d -- it runs on load.
#
# Reuses DeprecationTracker: init_tracker installs the version-correct hooks
# (Rails.application.deprecators on 7.1+, the ActiveSupport::Deprecation singleton
# before that, plus KernelWarnTracker). We set a bucket, eager-load so
# declaration-time warnings (associations, scopes, callbacks) fire while the
# tracker listens, then after_run writes the shitlist. `rails runner` is what
# fully boots the app and registers the framework deprecators we attach to -- a
# hand-rolled boot leaves that collection empty.
#
# The app is already booted by the time this runs, so warnings emitted during
# gem require / initializers fired before we attached and are out of scope; only
# eager-load-time warnings are captured.
require "deprecation_tracker"
require "deprecation_tracker/boot_capture"

# If this environment eager-loads at boot (config.eager_load = true), eager-load
# already ran before this script — the declaration-time warnings fired before the
# tracker could attach and are lost, and re-running eager_load! does nothing. Refuse
# rather than report a false "clean". The CLI passes CI= to keep the stock Rails
# 7.1+ template (config.eager_load = ENV["CI"].present?) from eager-loading, so
# this only trips for apps that hardcode eager_load = true. Exit with a distinct
# status so the CLI surfaces this explanation instead of its generic guess.
if Rails.application.config.eager_load
  STDERR.puts "deprecations boot: this environment eager-loads at boot (config.eager_load = true), " \
    "so eager-load deprecations fired before capture could attach. Set config.eager_load = false " \
    "for this run (the CLI already passes CI= for the stock Rails template)."
  exit DeprecationTracker::BootCapture::EAGER_LOAD_EXIT
end

# Force a recording, non-fatal deprecation setup for the capture. Apps mid-upgrade
# commonly do one of these in the test env, and each would defeat capture:
#   * silence deprecations (config.active_support.report_deprecations = false, or
#     ActiveSupport::Deprecation.silenced = true) — Reporting#warn returns early on
#     `silenced` before behavior is consulted, so nothing is recorded (false clean);
#   * set deprecation = :raise — the first eager-load warning raises and aborts
#     before after_run, leaving the CLI blaming a generic boot failure.
# We only want to RECORD warnings here, not silence or fail on them. Use the
# COLLECTION-level setters, not a per-deprecator loop: they update the collection's
# stored options, so a deprecator a gem/engine registers during eager-load inherits
# the same non-fatal setup instead of the app's :raise. init_tracker appends its
# collector after this, so both :stderr and the collector run. Mirrors init_tracker's
# deprecators-vs-singleton version fork.
# Note: this prints deprecations to stderr even for apps that normally silence them.
if defined?(Rails) && defined?(Rails.application) && defined?(Rails.application.deprecators)
  Rails.application.deprecators.silenced = false
  Rails.application.deprecators.behavior = :stderr
  Rails.application.deprecators.disallowed_behavior = :stderr
elsif defined?(ActiveSupport) && defined?(ActiveSupport::Deprecation)
  ActiveSupport::Deprecation.silenced = false
  ActiveSupport::Deprecation.behavior = :stderr
  ActiveSupport::Deprecation.disallowed_behavior = :stderr if ActiveSupport::Deprecation.respond_to?(:disallowed_behavior=)
end

tracker = DeprecationTracker.init_tracker(
  :shitlist_path => ENV.fetch("DEPRECATION_BOOT_OUTPUT"),
  :mode => "save"
)
tracker.bucket = "boot"
Rails.application.eager_load!
tracker.after_run
