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
      # `rails runner` fully boots the app, which registers the deprecators the runner attaches to.
      expect(argv).to eq(["bundle", "exec", "rails", "runner", described_class::RUNNER_PATH])
      expect(env["RAILS_ENV"]).to eq("test")
      expect(env["DEPRECATION_BOOT_OUTPUT"]).to eq("spec/support/deprecation_warning.boot.shitlist.json")
      # CI unset (nil) keeps the stock Rails 7.1+ template from eager-loading at boot.
      expect(env).to have_key("CI")
      expect(env["CI"]).to be_nil
    end

    it "selects the next bundle with BUNDLE_GEMFILE + BUNDLE_CACHE_PATH, not bin/next" do
      # bin/next may not exist in every project; BUNDLE_GEMFILE is what it wraps,
      # and `next`/gem-next-diff always pair it with BUNDLE_CACHE_PATH=vendor/cache.next.
      env, *argv = described_class.boot_command(output_path: "out.json", next_mode: true)
      expect(env["BUNDLE_GEMFILE"]).to eq("Gemfile.next")
      expect(env["BUNDLE_CACHE_PATH"]).to eq("vendor/cache.next")
      expect(argv).not_to include("bin/next")
    end

    it "leaves BUNDLE_GEMFILE and BUNDLE_CACHE_PATH at Bundler defaults for the current bundle" do
      env, * = described_class.boot_command(output_path: "out.json")
      expect(env).not_to have_key("BUNDLE_GEMFILE")
      expect(env).not_to have_key("BUNDLE_CACHE_PATH")
    end

    it "requires output_path (declared 2.0-safe: optional kwarg + guard, not a required kwarg)" do
      expect { described_class.boot_command }.to raise_error(ArgumentError, /output_path/)
    end

    it "cannot be shell-injected through --output (value stays a single env entry)" do
      malicious = "x.json; rm -rf foo"
      env, *argv = described_class.boot_command(output_path: malicious)
      # The value is passed as an env var, never spliced into a shell string.
      expect(env["DEPRECATION_BOOT_OUTPUT"]).to eq(malicious)
      expect(argv).to eq(["bundle", "exec", "rails", "runner", described_class::RUNNER_PATH])
      expect(argv.join(" ")).not_to include("rm -rf")
    end
  end

  describe ".command_display" do
    it "renders a readable line and omits unset (nil) env vars" do
      display = described_class.command_display(described_class.boot_command(output_path: "out.json"))
      # CI is unset (nil); don't render it as a misleading "CI=" blank assignment.
      expect(display).not_to include("CI=")
      expect(display).to include("RAILS_ENV=test")
      expect(display).to include("DEPRECATION_BOOT_OUTPUT=out.json")
      expect(display).to include("bundle exec rails runner #{described_class::RUNNER_PATH}")
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
    # Accepted limitation: the runner only does its real work inside a booted Rails
    # app (init_tracker + eager_load!), which this gem's suite has no fixture for.
    # The examples below assert the runner's *structure* (source text) — that the
    # eager-load guard, the un-silence/behavior setup, the transform_message, and
    # the init_tracker reuse are present and correctly ordered. Behavioral coverage
    # of the running runner comes from a CLI smoke against a fixture app, which is
    # blocked until `exe/deprecations` can load (see the rainbow require fix); until
    # then these structural checks plus the maintained manual verification stand in.
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
      expect(script).to include("Rails.application.eager_load!")
      expect(script).to include("tracker.after_run")
      # Reads the same output env the command sets.
      expect(script).to include("ENV.fetch(\"DEPRECATION_BOOT_OUTPUT\")")
    end

    it "stores project-relative paths by stripping Rails.root (committable shitlist)" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("transform_message")
      expect(script).to include('gsub("#{Rails.root}/"')
    end

    it "refuses with a distinct exit code, before eager_load!, when the env eager-loads at boot" do
      # If config.eager_load is true, eager-load already ran before the tracker
      # attached — the warnings are lost, so refuse rather than say "clean," and
      # exit with EAGER_LOAD_EXIT so the CLI can surface the runner's explanation.
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("Rails.application.config.eager_load")
      expect(script).to include("exit DeprecationTracker::BootCapture::EAGER_LOAD_EXIT")
      expect(script.index("config.eager_load")).to be < script.index("Rails.application.eager_load!")
    end

    it "un-silences and forces a non-raising behavior before attaching the collector" do
      # A silenced env records nothing (Reporting#warn returns early on `silenced`)
      # and a :raise env aborts on the first warning; both defeat capture. Un-silence
      # and force :stderr / disallowed :stderr first, before init_tracker and eager_load!.
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("silenced = false")
      expect(script).to include("behavior = :stderr")
      expect(script).to include("disallowed_behavior = :stderr")
      expect(script.index("silenced = false")).to be < script.index("DeprecationTracker.init_tracker")
    end
  end

  describe ".partial_path_for" do
    it "is the output path plus .partial (a sibling, for a same-dir atomic rename)" do
      expect(described_class.partial_path_for("spec/support/x.json")).to eq("spec/support/x.json.partial")
    end
  end

  describe ".boot_result" do
    it "flags the eager-load refusal by its exit status, whatever else happened" do
      expect(described_class.boot_result(false, described_class::EAGER_LOAD_EXIT, false)).to eq(:eager_load_refused)
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
