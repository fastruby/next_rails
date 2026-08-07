# frozen_string_literal: true

require "spec_helper"

require "tmpdir"
require "fileutils"
require "rbconfig"
require_relative "../../lib/deprecation_tracker/boot_capture"

RSpec.describe DeprecationTracker::BootCapture do
  describe ".boot_command" do
    it "returns an env hash + argv for system (no shell), running the gem runner" do
      env, *argv = described_class.boot_command(output_path: "spec/support/deprecation_warning.boot.shitlist.json")
      # Plain `ruby`: the runner boots the app itself so it can attach before the
      # initializers run, which `rails runner` would have already done for us.
      expect(argv).to eq(["bundle", "exec", "ruby", described_class::RUNNER_PATH])
      expect(env["RAILS_ENV"]).to eq("test")
      expect(env["DEPRECATION_BOOT_OUTPUT"]).to eq("spec/support/deprecation_warning.boot.shitlist.json")
      expect(env["DEPRECATION_BOOT_APP_ROOT"]).to eq(Dir.pwd)
    end

    it "selects the next bundle with BUNDLE_GEMFILE + BUNDLE_CACHE_PATH, not bin/next" do
      # bin/next may not exist in every project; BUNDLE_GEMFILE is what it wraps,
      # and `next`/gem-next-diff always pair it with BUNDLE_CACHE_PATH=vendor/cache.next.
      env, *argv = described_class.boot_command(output_path: "out.json", next_mode: true)
      expect(env["BUNDLE_GEMFILE"]).to eq("Gemfile.next")
      expect(env["BUNDLE_CACHE_PATH"]).to eq("vendor/cache.next")
      expect(argv).not_to include("bin/next")
    end

    it "leaves CI alone, since an env that eager-loads at boot is captured, not refused" do
      # The runner attaches before initialize!, so config.eager_load = ENV["CI"].present?
      # eager-loading during boot is fine. Unsetting CI would only hide the config CI runs with.
      env, * = described_class.boot_command(output_path: "out.json")
      expect(env).not_to have_key("CI")
    end

    it "takes the app root from the caller so the runner can find config/application" do
      env, * = described_class.boot_command(output_path: "out.json", app_root: "/somewhere/app")
      expect(env["DEPRECATION_BOOT_APP_ROOT"]).to eq("/somewhere/app")
    end

    it "leaves BUNDLE_GEMFILE and BUNDLE_CACHE_PATH at Bundler defaults for the current bundle" do
      env, * = described_class.boot_command(output_path: "out.json")
      expect(env).not_to have_key("BUNDLE_GEMFILE")
      expect(env).not_to have_key("BUNDLE_CACHE_PATH")
    end

    it "requires output_path (declared 2.0-safe: optional kwarg + guard, not a required kwarg)" do
      expect { described_class.boot_command }.to raise_error(ArgumentError, /output_path/)
    end

    it "passes the output path as an env value, never spliced into a shell string" do
      awkward = "a path with spaces.json"
      env, *argv = described_class.boot_command(output_path: awkward)
      expect(env["DEPRECATION_BOOT_OUTPUT"]).to eq(awkward)
      expect(argv).to eq(["bundle", "exec", "ruby", described_class::RUNNER_PATH])
      expect(argv.join(" ")).not_to include(awkward)
    end
  end

  describe ".command_display" do
    it "renders a readable line and omits unset (nil) env vars" do
      display = described_class.command_display(described_class.boot_command(output_path: "out.json"))
      expect(display).to include("RAILS_ENV=test")
      expect(display).to include("DEPRECATION_BOOT_OUTPUT=out.json")
      expect(display).to include("bundle exec ruby #{described_class::RUNNER_PATH}")
    end

    it "omits unset (nil) env vars rather than rendering them as blank assignments" do
      display = described_class.command_display([{ "KEEP" => "1", "DROP" => nil }, "bundle"])
      expect(display).to include("KEEP=1")
      expect(display).not_to include("DROP")
    end
  end

  describe ".default_output_path" do
    it "follows the tracker's spec/support convention with a .boot marker" do
      expect(described_class.default_output_path).to eq("spec/support/deprecation_warning.boot.shitlist.json")
    end

    it "distinguishes the next bundle" do
      expect(described_class.default_output_path(next_mode: true)).to eq("spec/support/deprecation_warning.boot.next.shitlist.json")
    end
  end

  describe "RUNNER_PATH" do
    # Accepted limitation: the runner only does its real work against a real Rails
    # app (require config/application, initialize!, eager_load!), which this gem's
    # suite has no fixture for. The examples below assert the runner's *structure*
    # (source text): that the attach happens before the app is required, that the
    # deprecation config is set before initialize! and re-asserted after it, and that
    # capture is delegated to DeprecationTracker. spec/deprecations_cli_spec.rb covers
    # the CLI's boot branches against a stubbed `bundle`, so what is still unexercised
    # is only the runner's body inside a real Rails app.
    it "points at a real, gem-shipped script (no temp file written at runtime)" do
      expect(File.file?(described_class::RUNNER_PATH)).to be(true)
    end

    it "is valid Ruby" do
      # `ruby -c` is portable across implementations; RubyVM::InstructionSequence is MRI-only.
      expect(system(RbConfig.ruby, "-c", described_class::RUNNER_PATH, out: File::NULL)).to be(true)
    end

    it "reuses DeprecationTracker rather than reimplementing capture" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("require \"deprecation_tracker\"")
      expect(script).to include("DeprecationTracker.init_tracker")
      expect(script).to include("tracker.bucket =")
      expect(script).to include("application.eager_load!")
      expect(script).to include("tracker.after_run")
      # Reads the same output env the command sets, via the shared constant.
      expect(script).to include("ENV.fetch(DeprecationTracker::BootCapture::OUTPUT_ENV)")
      expect(described_class::OUTPUT_ENV).to eq("DEPRECATION_BOOT_OUTPUT")
    end

    it "stores project-relative paths by stripping Rails.root (committable shitlist)" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("transform_message")
      expect(script).to include('gsub("#{Rails.root}/"')
    end

    it "installs the tracker before requiring the app, so gem-load warnings are in scope" do
      # KernelWarnTracker is patched in by init_tracker; requiring config/application
      # is what loads the gems (Bundler.require), so the order here is the whole point.
      script = File.read(described_class::RUNNER_PATH)
      expect(script.index("DeprecationTracker.init_tracker")).to be < script.index("require application_path")
    end

    it "boots the app itself instead of relying on an already-initialized one" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("require application_path")
      expect(script).to include("application.initialize!")
      expect(script.index("application.initialize!")).to be < script.index("application.eager_load!")
    end

    it "configures a recording, non-silenced, non-raising setup through config before initialize!" do
      # Rails' own active_support.deprecation_behavior initializer assigns behavior from
      # these config values (and silences everything when report_deprecations is false),
      # so it would overwrite anything set on the deprecators directly beforehand. Going
      # through config means Rails installs the collector, and on 7.1+ the collection
      # propagates it to deprecators registered later.
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("config.active_support.report_deprecations = true")
      expect(script).to include("config.active_support.deprecation = [:stderr, collector]")
      expect(script).to include("config.active_support.disallowed_deprecation = [:stderr, collector]")
      expect(script.index("config.active_support.deprecation = [:stderr, collector]")).to be < script.index("application.initialize!")
    end

    it "re-installs the collector from a railtie initializer behind :load_environment_config" do
      # config/environments/<env>.rb is loaded during initialize!, and a plain
      # `config.active_support.deprecation = :stderr` there replaces the collector we
      # configured beforehand. Re-installing right after that file is loaded is what
      # keeps initializer-time and eager-load-time warnings recorded. (Seen for real:
      # a Rails 3.2 app whose test.rb sets exactly that line.)
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("class Railtie < Rails::Railtie")
      expect(script).to include(":after => :load_environment_config")
      expect(script.index("class Railtie < Rails::Railtie")).to be < script.index("application.initialize!")
    end

    it "re-installs immediately before eager-load, and again after initialize!" do
      # before_eager_load fires from the finisher after every initializer, covering the
      # environments that eager-load during boot. The call after initialize! covers the
      # ones that do not, where that hook never fires and we eager-load ourselves.
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("ActiveSupport.on_load(:before_eager_load) { install_collector.call }")
      last_call = script.rindex("install_collector.call")
      expect(last_call).to be > script.index("application.initialize!")
      expect(last_call).to be < script.index("application.eager_load!")
    end

    it "installs on both the 7.1+ deprecators collection and the older singleton" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("application.deprecators.silenced = false")
      expect(script).to include("ActiveSupport::Deprecation.silenced = false")
    end

    it "refuses with a distinct exit code when there is no app to boot" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("exit DeprecationTracker::BootCapture::NO_APP_EXIT")
      expect(script.index("NO_APP_EXIT")).to be < script.index("require application_path")
    end
  end

  describe ".partial_path_for" do
    it "is the output path plus .partial (a sibling, for a same-dir atomic rename)" do
      expect(described_class.partial_path_for("spec/support/x.json")).to eq("spec/support/x.json.partial")
    end
  end

  describe ".boot_result" do
    it "flags a missing app by its exit status, whatever else happened" do
      expect(described_class.boot_result(false, described_class::NO_APP_EXIT, false)).to eq(:no_app)
    end

    it "is :failed when the process failed or wrote no partial" do
      expect(described_class.boot_result(false, 1, true)).to eq(:failed)   # non-zero exit
      expect(described_class.boot_result(true, 0, false)).to eq(:failed)   # no output written
      expect(described_class.boot_result(nil, nil, false)).to eq(:failed)  # Ctrl-C: system -> nil
    end

    it "is :ok only when the process succeeded and the partial was written" do
      expect(described_class.boot_result(true, 0, true)).to eq(:ok)
    end
  end

  describe "DeprecationTracker save outside a test process (boot runs it via `rails runner`)" do
    it "saves from a bare Ruby process that hasn't loaded the stdlib RSpec pulls in" do
      # rails runner in a slim app is such a process; save uses Tempfile/FileUtils.
      # A subprocess is the only way to prove the requires, since RSpec has already
      # loaded them here. Fails with NameError before the requires were added.
      lib = File.expand_path("../../lib", __dir__)
      path = File.join(Dir.tmpdir, "nr-boot-#{Process.pid}-#{rand(100_000)}.json")
      script = "require 'deprecation_tracker'; " \
        "t = DeprecationTracker.new(#{path.inspect}, nil, :save); " \
        "t.bucket = 'boot'; t.add('x'); t.after_run"
      begin
        expect(system(RbConfig.ruby, "-I#{lib}", "-e", script)).to be(true)
        expect(File.exist?(path)).to be(true)
      ensure
        FileUtils.rm_f(path)
      end
    end
  end
end
