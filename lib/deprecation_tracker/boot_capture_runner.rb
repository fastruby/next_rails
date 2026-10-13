# frozen_string_literal: true

# Boots the app itself and captures the deprecations it emits while doing so.
# Executed via `bundle exec ruby` from the app root (see BootCapture.boot_command).
# NOT meant to be `require`d -- it runs on load.
#
# Why boot the app here instead of running inside `rails runner`: `rails runner`
# hands us an app that is ALREADY initialized, so every warning emitted while gems
# were required and while the initializers ran has already gone by. Doing what
# config/environment.rb does -- require config/application, then initialize! --
# with our hook wedged in the middle moves the attach point as early as a script
# can reach:
#
#   require the tracker      <- Kernel#warn patch is live from here on
#   require config/application  (this is where Bundler.require loads the gems)
#   configure deprecations   <- before any initializer runs
#   initialize!              <- app + framework initializers, now captured
#   eager_load!              <- class bodies, now captured
#
# Still out of reach: anything emitted inside config/boot.rb, and deprecator-based
# warnings during Bundler.require -- config/application.rb runs Bundler.require
# itself, so gems are loaded by the time that require returns. Plain Kernel#warn
# during gem load IS captured, because KernelWarnTracker is installed first.
#
# Capture logic is not reimplemented: init_tracker installs the version-correct
# hooks and KernelWarnTracker, and add / after_run collect and write.
#
# Kept compatible with the gem's supported Rubies (>= 2.0): no safe-navigation,
# no squiggly heredocs, stdlib only.
require "deprecation_tracker"
require "deprecation_tracker/boot_capture"

app_root = ENV["DEPRECATION_BOOT_APP_ROOT"] || Dir.pwd
application_path = File.expand_path(File.join(app_root, "config", "application"))

unless File.exist?("#{application_path}.rb")
  STDERR.puts "deprecations boot: no config/application.rb under #{app_root}. " \
    "Run this from a Rails app root, or pass --app-root."
  exit DeprecationTracker::BootCapture::NO_APP_EXIT
end

# Strips the absolute Rails.root prefix (the same gsub the RSpec/Minitest setups
# use) so the shitlist stores project-relative, committable paths. Rails is not
# loaded yet when this lambda is built, and warnings can arrive before Rails.root
# exists (gem-require time), so resolve it per message and pass the message
# through untouched until it does.
transform_message = lambda do |message|
  if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
    message.gsub("#{Rails.root}/", "")
  else
    message
  end
end

# Installs KernelWarnTracker before the app requires a single gem, so plain
# Kernel#warn deprecations from gem load are recorded too. The deprecator hooks
# init_tracker also installs find nothing yet (no app, so no deprecators); the
# config assignment below is what covers those.
tracker = DeprecationTracker.init_tracker(
  :shitlist_path => ENV.fetch(DeprecationTracker::BootCapture::OUTPUT_ENV),
  :mode => "save",
  :transform_message => transform_message
)
tracker.bucket = "boot"
collector = lambda { |message, _callstack = nil, _deprecation_horizon = nil, _gem_name = nil| tracker.add(message) }

# Loads config/boot.rb (Bundler, bootsnap) and config/application.rb (which runs
# Bundler.require, so all gems load here) and defines the application class. No
# initializer has run yet.
require application_path

application = Rails.application

# Configure the capture BEFORE initialize!, through config rather than by touching
# the deprecators directly. Rails' own `active_support.deprecation_behavior`
# initializer assigns behavior from these config values (and silences everything
# when report_deprecations is false), so anything set on the deprecators now would
# be overwritten by it. Setting the config instead means Rails installs our
# collector for us, and on 7.1+ the collection propagates it to every deprecator a
# gem or engine registers later.
#
# Apps mid-upgrade commonly configure one of these, and each would defeat capture:
#   * silenced (report_deprecations = false) -- Reporting#warn returns early on
#     `silenced` before behavior is consulted, so nothing is recorded (false clean);
#   * :raise -- the first warning aborts the boot before after_run, and the CLI is
#     left blaming a generic boot failure.
# We only want to RECORD warnings here, not silence or fail on them.
#
# report_deprecations / disallowed_deprecation only exist on newer Rails; on older
# ones config.active_support is an OrderedOptions, so the unknown keys are simply
# ignored rather than raising.
#
# Note: this prints deprecations to stderr even for apps that normally silence them.
application.config.active_support.report_deprecations = true
application.config.active_support.deprecation = [:stderr, collector]
application.config.active_support.disallowed_deprecation = [:stderr, collector]

# Assigns the collector onto whatever deprecators exist at that moment, replacing the
# behavior list rather than appending, so nothing collects twice.
install_collector = lambda do
  if defined?(Rails.application.deprecators)
    application.deprecators.silenced = false
    application.deprecators.behavior = [:stderr, collector]
    application.deprecators.disallowed_behavior = [:stderr, collector]
  elsif defined?(ActiveSupport) && defined?(ActiveSupport::Deprecation)
    ActiveSupport::Deprecation.silenced = false
    ActiveSupport::Deprecation.behavior = [:stderr, collector]
    if ActiveSupport::Deprecation.respond_to?(:disallowed_behavior=)
      ActiveSupport::Deprecation.disallowed_behavior = [:stderr, collector]
    end
  end
end

# The config above is not enough on its own: config/environments/<env>.rb is loaded
# DURING initialize! (the :load_environment_config initializer), and a line as ordinary
# as `config.active_support.deprecation = :stderr` there replaces our collector before a
# single app initializer has run. So re-install after that file is loaded, from a railtie
# initializer ordered right behind it. Railtie subclasses defined before initialize! are
# picked up, which is why this is declared here rather than in the gem's normal code.
module DeprecationTracker::BootCapture::Collector
  class Railtie < Rails::Railtie
    initializer "deprecation_tracker.boot_capture", :after => :load_environment_config do
      DeprecationTracker::BootCapture::Collector.install.call
    end
  end

  def self.install
    @install
  end

  def self.install=(callable)
    @install = callable
  end
end
DeprecationTracker::BootCapture::Collector.install = install_collector

# And once more immediately before eager-load, for apps whose config/initializers touch
# deprecation settings after the railtie initializer above has run. Rails fires this hook
# from the finisher, right before it eager-loads (which is where the environments that
# eager-load at boot do it), so it lands after every initializer and before the class
# bodies are evaluated.
ActiveSupport.on_load(:before_eager_load) { install_collector.call }

application.initialize!

# Last re-install, covering the environments that do NOT eager-load during boot: there
# the before_eager_load hook never fired, and config/initializers have had their chance
# to assign ActiveSupport::Deprecation directly, bypassing config. On 7.1+ this also
# picks up every deprecator registered by a gem or engine while initializing.
install_collector.call

# Eager-load so declaration-time warnings (associations, scopes, callbacks) fire.
# Safe to call even when the environment already eager-loaded during initialize!
# (config.eager_load = true, or Rails 3.x cache_classes): loading is idempotent, and
# because we attached before initialize! those warnings were captured either way.
# That is why this approach needs no "this environment eager-loads at boot" refusal.
application.eager_load!
tracker.after_run
