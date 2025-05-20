# frozen_string_literal: true

require "spec_helper"

require "date"
require "tempfile"
require_relative "../lib/deprecation_tracker"

RSpec::Matchers.define_negated_matcher :not_raise_error, :raise_error

RSpec.describe DeprecationTracker do
  let(:shitlist_path) do
    shitlist_path = Tempfile.new("tmp").path
    FileUtils.rm(shitlist_path)
    shitlist_path
  end

  describe "#add" do
    it "groups messages by bucket" do
      subject = DeprecationTracker.new("/tmp/foo.txt")

      subject.bucket = "bucket 1"
      subject.add("error 1")
      subject.add("error 2")

      subject.bucket = "bucket 2"
      subject.add("error 3")
      subject.add("error 4")

      expect(subject.deprecation_messages).to eq(
        "bucket 1" => ["error 1", "error 2"],
        "bucket 2" => ["error 3", "error 4"]
      )
    end

    it "ignores messages when bucket null" do
      subject = DeprecationTracker.new("/tmp/foo.txt")

      subject.bucket = nil
      subject.add("error 1")
      subject.add("error 2")

      expect(subject.deprecation_messages).to eq({})
    end

    it "transforms messages before adding them" do
      subject = DeprecationTracker.new("/tmp/foo.txt", -> (message) { message + " foo" })

      subject.bucket = "bucket 1"
      subject.add("a")

      expect(subject.deprecation_messages).to eq(
        "bucket 1" => ["a foo"]
      )
    end
  end

  describe "#compare" do
    it "ignores buckets that have no messages" do
      setup_tracker = DeprecationTracker.new(shitlist_path)
      setup_tracker.bucket = "bucket 1"
      setup_tracker.add("a")
      setup_tracker.bucket = "bucket 2"
      setup_tracker.add("a")
      setup_tracker.save

      subject = DeprecationTracker.new(shitlist_path)

      subject.bucket = "bucket 2"
      subject.add("a")

      expect { subject.compare }.not_to raise_error
    end

    it "raises an error when recorded messages are different for a given bucket" do
      setup_tracker = DeprecationTracker.new(shitlist_path)
      setup_tracker.bucket = "bucket 1"
      setup_tracker.add("a")
      setup_tracker.save

      subject = DeprecationTracker.new(shitlist_path)

      subject.bucket = "bucket 1"
      subject.add("b")

      expect { subject.compare }.to raise_error(DeprecationTracker::UnexpectedDeprecations, /Deprecation warnings have changed/)
    end
  end

  describe "#save" do
    it "saves to disk" do
      subject = DeprecationTracker.new(shitlist_path)

      subject.bucket = "bucket 1"
      subject.add("b")
      subject.add("b")
      subject.add("a")

      subject.save

      expected_json = <<-JSON.chomp
{
  "bucket 1": [
    "a",
    "b",
    "b"
  ]
}
      JSON
      expect(File.read(shitlist_path)).to eq(expected_json)
    end

    it "creates the directory if shitlist directory does not exist" do
      FileUtils.mkdir_p("/tmp/test")
      shitlist_path = Tempfile.new("tmp", "/tmp/test").path
      FileUtils.rm(shitlist_path)
      shitlist_path
      subject = DeprecationTracker.new(shitlist_path)

      subject.bucket = "bucket 1"
      subject.add("b")
      subject.add("b")
      subject.add("a")

      subject.save

      expected_json = <<-JSON.chomp
{
  "bucket 1": [
    "a",
    "b",
    "b"
  ]
}
      JSON
      expect(File.read(shitlist_path)).to eq(expected_json)
      FileUtils.rm_r "/tmp/test"
    end

    it "combines recorded and stored messages" do
      setup_tracker = DeprecationTracker.new(shitlist_path)
      setup_tracker.bucket = "bucket 1"
      setup_tracker.add("a")
      setup_tracker.save

      subject = DeprecationTracker.new(shitlist_path)

      subject.bucket = "bucket 2"
      subject.add("a")
      subject.save

      expected_json = <<-JSON.chomp
{
  "bucket 1": [
    "a"
  ],
  "bucket 2": [
    "a"
  ]
}
      JSON
      expect(File.read(shitlist_path)).to eq(expected_json)
    end

    it "overwrites stored messages with recorded messages with the same bucket" do
      setup_tracker = DeprecationTracker.new(shitlist_path)
      setup_tracker.bucket = "bucket 1"
      setup_tracker.add("a")
      setup_tracker.save

      subject = DeprecationTracker.new(shitlist_path)

      subject.bucket = "bucket 1"
      subject.add("b")
      subject.save

      expected_json = <<-JSON.chomp
{
  "bucket 1": [
    "b"
  ]
}
      JSON
      expect(File.read(shitlist_path)).to eq(expected_json)
    end

    it "sorts by bucket" do
      subject = DeprecationTracker.new(shitlist_path)
      subject.bucket = "bucket 2"
      subject.add("a")
      subject.bucket = "bucket 1"
      subject.add("a")
      subject.save

      expected_json = <<-JSON.chomp
{
  "bucket 1": [
    "a"
  ],
  "bucket 2": [
    "a"
  ]
}
      JSON
      expect(File.read(shitlist_path)).to eq(expected_json)
    end

    it "sorts messages" do
      subject = DeprecationTracker.new(shitlist_path)
      subject.bucket = "bucket 1"
      subject.add("b")
      subject.add("c")
      subject.add("a")
      subject.save

      expected_json = <<-JSON.chomp
{
  "bucket 1": [
    "a",
    "b",
    "c"
  ]
}
      JSON
      expect(File.read(shitlist_path)).to eq(expected_json)
    end
  end

  describe "#after_run" do
    let(:shitlist_path) { "some_path" }

    it "calls save if in save mode" do
      tracker = DeprecationTracker.new(shitlist_path, nil, :save)
      expect(tracker).to receive(:save)
      expect(tracker).not_to receive(:compare)
      tracker.after_run
    end

    it "calls compare if in compare mode" do
      tracker = DeprecationTracker.new(shitlist_path, nil, "compare")
      expect(tracker).not_to receive(:save)
      expect(tracker).to receive(:compare)
      tracker.after_run
    end

    it "does not save nor compare if mode is invalid" do
      tracker = DeprecationTracker.new(shitlist_path, nil, "random_stuff")
      expect(tracker).not_to receive(:save)
      expect(tracker).not_to receive(:compare)
      tracker.after_run
    end
  end

  describe "#init_tracker" do
    it "returns a new instance of DeprecationTracker" do
      tracker = DeprecationTracker.init_tracker({mode: "save"})
      expect(tracker).to be_a(DeprecationTracker)
    end

    it "subscribes to KernelWarnTracker deprecation events" do
      expect do
        DeprecationTracker.init_tracker({mode: "save"})
      end.to change(DeprecationTracker::KernelWarnTracker.callbacks, :size).by(1)
    end

    context "when Rails.application.deprecation is not defined and ActiveSupport is defined" do
      it "sets the ActiveSupport::Deprecation behavior" do
        # Stub ActiveSupport::Deprecation with a simple behavior array
        stub_const("ActiveSupport::Deprecation", Class.new {
          def self.behavior
            @behavior ||= []
          end
        })

        expect do
          DeprecationTracker.init_tracker({mode: "save"})
        end.to change(ActiveSupport::Deprecation.behavior, :size).by(1)
      end
    end

    context "when Rails.application.deprecation is defined" do
      it "sets the behavior of each Rails.application.deprecators" do
        # Stub Rails.application.deprecators with an array of mock deprecators
        fake_deprecator_1 = double("Deprecator", behavior: [])
        fake_deprecator_2 = double("Deprecator", behavior: [])
        stub_const("Rails", Module.new)
        allow(Rails).to receive_message_chain(:application, :deprecators).and_return([fake_deprecator_1, fake_deprecator_2])

        expect do
          DeprecationTracker.init_tracker({ mode: "save" })
        end.to change(fake_deprecator_1.behavior, :size).by(1).and change(fake_deprecator_2.behavior, :size).by(1)
      end
    end
  end

  describe DeprecationTracker::KernelWarnTracker do
    it "captures Kernel#warn" do
      warn_messages = []
      DeprecationTracker::KernelWarnTracker.callbacks << -> (message) { warn_messages << message }

      expect do
        Kernel.warn "oh"
        Kernel.warn "no"
      end.to output("oh\nno\n").to_stderr

      expect(warn_messages).to eq(["oh", "no"])
    end

    it "captures Kernel.warn" do
      warn_messages = []
      DeprecationTracker::KernelWarnTracker.callbacks << -> (message) { warn_messages << message }

      expect do
        Kernel.warn "oh"
        Kernel.warn "no"
      end.to output("oh\nno\n").to_stderr

      expect(warn_messages).to eq(["oh", "no"])
    end

    describe "bug when warning uses the uplevel keyword argument" do
      context "given I setup the DeprecationTracker::KernelWarnTracker with a callback that manipulates messages as Strings" do

        DeprecationTracker::KernelWarnTracker.callbacks << -> (message) { message.gsub("Rails.root/", "") }

        context "and given that I call code that emits a warning using the uplevel keyword arg" do
          it "throws a MissingMethod Error" do
            expect { Kernel.warn("Oh no", uplevel: 1) }.to not_raise_error.and output.to_stderr
          end
        end
      end
    end

    describe "bug when warning uses unexpected keyword arguments" do
      it "does not raise an error with unknown keyword args like :deprecation, :span, :stack" do
        DeprecationTracker::KernelWarnTracker.callbacks << -> (message) { message.to_s }

        expect {
          warn("Unknown deprecation warning", deprecation: true, span: 1.2, stack: ["line1", "line2"])
        }.to not_raise_error.and output.to_stderr
      end
    end
  end
end
