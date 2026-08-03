# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"

# Smoke tests that actually execute exe/deprecations. Everything here runs the real
# script in a subprocess, so it catches the class of breakage unit tests on lib/
# cannot: a missing require, or a mode that raises before doing any work. Two shipped
# bugs (an undeclared `rainbow` require and a NoMethodError in `run`) survived
# precisely because nothing ever loaded this executable.
RSpec.describe "exe/deprecations" do
  def cli_path
    File.expand_path("../exe/deprecations", __dir__)
  end

  def shitlist_path
    "spec/support/deprecation_warning.shitlist.json"
  end

  # Runs the CLI in `chdir` and returns [stdout, stderr, exitstatus].
  def run_cli(args, chdir:)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli_path, *args, chdir: chdir)
    [stdout, stderr, status.exitstatus]
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

    it "lists the test files with --verbose" do
      shitlist
      stdout, _stderr, = run_cli(["info", "--verbose"], chdir: dir)

      expect(stdout).to include("Test files: ")
      expect(stdout).to include("user_spec.rb")
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
    # any work. Reaching the mode validation at all proves the tracker is loaded.
    it "validates --tracker-mode instead of raising NoMethodError" do
      shitlist
      _stdout, stderr, status = run_cli(["run", "--tracker-mode", "bogus"], chdir: dir)

      expect(status).to eq(1)
      expect(stderr).to include("Invalid --tracker-mode")
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
end
