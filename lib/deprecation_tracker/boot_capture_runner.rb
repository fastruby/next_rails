# frozen_string_literal: true

# Executed inside a booted app via `rails runner` (see DeprecationTracker::BootCapture.boot_command).
# NOT meant to be `require`d -- it runs on load.
#
# Reuses DeprecationTracker: init_tracker installs the version-correct deprecation
# hooks (Rails.application.deprecators on 7.1+, the ActiveSupport::Deprecation
# singleton before that, plus KernelWarnTracker). We give it a bucket so `add`
# records, eager-load so declaration-time warnings (associations, scopes,
# callbacks) fire while it is listening, then `after_run` writes the shitlist.
#
# Eager-loading is the whole point of this command -- those declaration-time
# warnings are exactly what the per-test tracker misses -- so it is not optional.
require "deprecation_tracker"

tracker = DeprecationTracker.init_tracker(
  :shitlist_path => ENV.fetch("DEPRECATION_BOOT_OUTPUT"),
  :mode => "save"
)
tracker.bucket = "boot"
Rails.application.eager_load!
tracker.after_run
