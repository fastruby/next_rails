# frozen_string_literal: true

require "spec_helper"

require_relative "../../lib/deprecation_tracker/boot_capture"

RSpec.describe DeprecationTracker::BootCapture do
  describe ".boot_command" do
    it "runs the gem's runner script under RAILS_ENV=test" do
      command = described_class.boot_command(output_path: "spec/support/deprecation_warning.boot.shitlist.json")
      expect(command).to start_with("RAILS_ENV=test ")
      expect(command).to include("bundle exec rails runner #{described_class::RUNNER_PATH}")
      expect(command).to include("DEPRECATION_BOOT_OUTPUT=spec/support/deprecation_warning.boot.shitlist.json")
    end

    it "selects the next bundle with BUNDLE_GEMFILE, not bin/next" do
      # bin/next may not exist in every project; BUNDLE_GEMFILE is what it wraps.
      command = described_class.boot_command(output_path: "out.json", next_mode: true)
      expect(command).to include("BUNDLE_GEMFILE=Gemfile.next")
      expect(command).to include("bundle exec rails runner")
      expect(command).not_to include("bin/next")
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
    it "points at a real, gem-shipped script (no temp file written at runtime)" do
      expect(File.file?(described_class::RUNNER_PATH)).to be(true)
    end

    it "is valid Ruby" do
      expect { RubyVM::InstructionSequence.compile(File.read(described_class::RUNNER_PATH)) }.not_to raise_error
    end

    it "reuses DeprecationTracker rather than reimplementing capture, and always eager-loads" do
      script = File.read(described_class::RUNNER_PATH)
      expect(script).to include("require \"deprecation_tracker\"")
      expect(script).to include("DeprecationTracker.init_tracker")
      expect(script).to include("tracker.bucket =")
      expect(script).to include("Rails.application.eager_load!")
      expect(script).to include("tracker.after_run")
      # Reads the same output env the command sets.
      expect(script).to include("ENV.fetch(\"DEPRECATION_BOOT_OUTPUT\")")
    end
  end
end
