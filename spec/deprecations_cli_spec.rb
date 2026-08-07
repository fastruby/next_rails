# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "deprecation_tracker/boot_capture"

# Smoke tests that actually execute exe/deprecations. Everything here runs the real
# script in a subprocess, so it catches the class of breakage unit tests on lib/
# cannot: a missing require, a mode that raises before doing any work, a flag guard
# that never fires. Two shipped bugs (an undeclared `rainbow` require and a
# NoMethodError in `run`) survived precisely because nothing ever loaded this file.
RSpec.describe "exe/deprecations" do
  def cli_path
    File.expand_path("../exe/deprecations", __dir__)
  end

  def shitlist_path
    "spec/support/deprecation_warning.shitlist.json"
  end

  # Runs the CLI in `chdir` and returns [stdout, stderr, exitstatus].
  def run_cli(args, chdir:, env: {})
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, cli_path, *args, chdir: chdir)
    [stdout, stderr, status.exitstatus]
  end

  # A stand-in for `bundle` on PATH, so the boot branches can be driven without a
  # Rails app. `behavior` is the body of a /bin/sh script.
  def stub_bundle(dir, behavior)
    bin = File.join(dir, "fake_bin")
    Dir.mkdir(bin) unless File.directory?(bin)
    path = File.join(bin, "bundle")
    File.write(path, "#!/bin/sh\n#{behavior}\n")
    File.chmod(0o755, path)
    { "PATH" => "#{bin}:#{ENV["PATH"]}" }
  end

  around do |example|
    Dir.mktmpdir("deprecations-cli") do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, "spec", "support"))
      example.run
    end
  end

  attr_reader :dir

  def write_shitlist(relative, contents)
    path = File.join(dir, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(contents))
    path
  end

  let(:shitlist) do
    write_shitlist(
      shitlist_path,
      "./spec/models/user_spec.rb" => ["DEPRECATION WARNING: default_timezone"],
      "./spec/models/post_spec.rb" => ["DEPRECATION WARNING: partial rendering"]
    )
  end

  describe "info" do
    it "summarizes the shitlist" do
      shitlist
      stdout, _stderr, status = run_cli(["info"], chdir: dir)

      expect(status).to eq(0)
      expect(stdout).to include("Ten most common deprecation warnings:")
      expect(stdout).to include("default_timezone")
      expect(stdout).to include("partial rendering")
    end

    it "narrows the output with --pattern" do
      shitlist
      stdout, _stderr, status = run_cli(["info", "--pattern", "default_timezone"], chdir: dir)

      expect(status).to eq(0)
      expect(stdout).to include("default_timezone")
      expect(stdout).not_to include("partial rendering")
    end

    it "labels spec-file buckets as test files" do
      shitlist
      stdout, _stderr, = run_cli(["info", "--verbose"], chdir: dir)

      expect(stdout).to include("Test files: ")
      expect(stdout).to include("user_spec.rb")
      expect(stdout).not_to include("Source:")
    end

    it "aborts with a readable message when the shitlist is missing" do
      _stdout, stderr, status = run_cli(["info"], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("No shitlist found at")
      expect(stderr).not_to include("Errno::ENOENT")
    end

    it "exits non-zero when no message matches --pattern" do
      shitlist
      _stdout, stderr, status = run_cli(["info", "--pattern", "nothing-matches-this"], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("No test files with deprecations")
    end
  end

  describe "run" do
    # Regression: run called DeprecationTracker.sanitize_mode while the CLI only
    # required valid_modes, so every invocation died with NoMethodError before doing
    # any work. Reaching the mode validation at all proves the method resolves.
    it "validates --tracker-mode instead of raising NoMethodError" do
      shitlist
      _stdout, stderr, status = run_cli(["run", "--tracker-mode", "bogus"], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("Invalid --tracker-mode")
      expect(stderr).to include("save, compare")
      expect(stderr).not_to include("NoMethodError")
    end
  end

  describe "merge" do
    it "writes the merged shard files to the canonical shitlist" do
      write_shitlist(
        "spec/support/deprecation_warning.shitlist.node-1.json",
        "./spec/models/user_spec.rb" => ["DEPRECATION WARNING: from shard 1"]
      )
      write_shitlist(
        "spec/support/deprecation_warning.shitlist.node-2.json",
        "./spec/models/post_spec.rb" => ["DEPRECATION WARNING: from shard 2"]
      )

      stdout, _stderr, status = run_cli(["merge"], chdir: dir)

      expect(status).to eq(0)
      expect(stdout).to include("Merged 2 shard files")
      merged = JSON.parse(File.read(File.join(dir, shitlist_path)))
      expect(merged.fetch("./spec/models/user_spec.rb")).to eq(["DEPRECATION WARNING: from shard 1"])
      expect(merged.fetch("./spec/models/post_spec.rb")).to eq(["DEPRECATION WARNING: from shard 2"])
    end

    # Documents current behavior: merge builds the result from the shard files alone
    # and overwrites the canonical shitlist. Entries only present in the canonical
    # file are dropped, not merged.
    it "overwrites entries already in the canonical shitlist" do
      shitlist
      write_shitlist(
        "spec/support/deprecation_warning.shitlist.node-1.json",
        "./spec/models/user_spec.rb" => ["DEPRECATION WARNING: from shard 1"]
      )

      _stdout, _stderr, status = run_cli(["merge"], chdir: dir)

      expect(status).to eq(0)
      merged = JSON.parse(File.read(File.join(dir, shitlist_path)))
      expect(merged.fetch("./spec/models/user_spec.rb")).to eq(["DEPRECATION WARNING: from shard 1"])
      expect(merged).not_to have_key("./spec/models/post_spec.rb")
    end
  end

  describe "mode handling" do
    it "exits non-zero with usage when no mode is given" do
      _stdout, stderr, status = run_cli([], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("Must pass a mode")
    end

    it "exits non-zero on an unknown mode" do
      _stdout, stderr, status = run_cli(["nonsense"], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("Unknown mode")
    end
  end

  describe "boot" do
    let(:output_path) { File.join(dir, "spec/support/deprecation_warning.boot.shitlist.json") }
    let(:partial_path) { "#{output_path}.partial" }

    before { File.write(output_path, JSON.generate("boot" => ["PREVIOUS CAPTURE"])) }

    it "rejects --pattern, which it cannot apply" do
      _stdout, stderr, status = run_cli(["boot", "--pattern", "anything"], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("--pattern is not supported with 'boot'")
    end

    it "tells the runner where the app root is" do
      env = stub_bundle(dir, 'echo "{\"boot\":[\"root=$DEPRECATION_BOOT_APP_ROOT\"]}" > "$DEPRECATION_BOOT_OUTPUT"')

      stdout, _stderr, status = run_cli(["boot"], chdir: dir, env: env)

      expect(status).to eq(0)
      # Compared through realpath: on macOS the tmpdir is reached via a /private symlink.
      expect(stdout).to include("root=#{File.realpath(dir)}")
    end

    it "promotes the partial and summarizes it when the boot succeeds" do
      env = stub_bundle(dir, 'echo \'{"boot":["DEPRECATION WARNING: captured"]}\' > "$DEPRECATION_BOOT_OUTPUT"')

      stdout, _stderr, status = run_cli(["boot"], chdir: dir, env: env)

      expect(status).to eq(0)
      expect(stdout).to include("Boot-time deprecations written to")
      expect(stdout).to include("captured")
      expect(JSON.parse(File.read(output_path))).to eq("boot" => ["DEPRECATION WARNING: captured"])
      expect(File.exist?(partial_path)).to be(false)
    end

    it "reports a clean boot when the capture is empty" do
      env = stub_bundle(dir, 'echo \'{}\' > "$DEPRECATION_BOOT_OUTPUT"')

      stdout, _stderr, status = run_cli(["boot"], chdir: dir, env: env)

      expect(status).to eq(0)
      expect(stdout).to include("Boot completed cleanly")
      expect(File.exist?(partial_path)).to be(false)
    end

    it "keeps the previous capture when the app fails to boot" do
      env = stub_bundle(dir, "echo 'boom' >&2; exit 1")

      _stdout, stderr, status = run_cli(["boot"], chdir: dir, env: env)

      expect(status).to eq(1)
      expect(stderr).to include("Boot did not complete")
      expect(JSON.parse(File.read(output_path))).to eq("boot" => ["PREVIOUS CAPTURE"])
      expect(File.exist?(partial_path)).to be(false)
    end

    it "surfaces the runner's own explanation when it refuses to capture" do
      exit_code = DeprecationTracker::BootCapture::NO_APP_EXIT
      env = stub_bundle(dir, "echo 'no config/application.rb under here' >&2; exit #{exit_code}")

      _stdout, stderr, status = run_cli(["boot"], chdir: dir, env: env)

      expect(status).to eq(exit_code)
      expect(stderr).to include("no config/application.rb")
      # The generic guess must not bury the runner's specific explanation.
      expect(stderr).not_to include("Boot did not complete")
      expect(JSON.parse(File.read(output_path))).to eq("boot" => ["PREVIOUS CAPTURE"])
      expect(File.exist?(partial_path)).to be(false)
    end
  end
end
