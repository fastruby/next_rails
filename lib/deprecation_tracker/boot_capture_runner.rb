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

tracker = DeprecationTracker.init_tracker(
  :shitlist_path => ENV.fetch("DEPRECATION_BOOT_OUTPUT"),
  :mode => "save"
)
tracker.bucket = "boot"
Rails.application.eager_load!
tracker.after_run
