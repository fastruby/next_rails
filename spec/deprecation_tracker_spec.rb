require "tempfile"
require_relative "spec_helper"
require_relative "../lib/deprecation_tracker"

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
  end
end
