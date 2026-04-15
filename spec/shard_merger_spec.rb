# frozen_string_literal: true

require "spec_helper"

require "json"
require "tempfile"
require_relative "../lib/deprecation_tracker/shard_merger"

RSpec.describe DeprecationTracker::ShardMerger do
  let(:base_path) do
    dir = Dir.tmpdir
    File.join(dir, "shitlist-#{Process.pid}-#{rand(1000)}.json")
  end

  after do
    FileUtils.rm_f(base_path)
    Dir.glob("#{base_path.chomp('.json')}.node-*.json").each { |f| FileUtils.rm_f(f) }
  end

  def write_shard(index, data)
    path = "#{base_path.chomp('.json')}.node-#{index}.json"
    File.write(path, JSON.pretty_generate(data))
    path
  end

  subject { described_class.new(base_path) }

  it "merges multiple shard files into the canonical file" do
    write_shard(0, { "bucket 1" => ["a"], "bucket 2" => ["b"] })
    write_shard(1, { "bucket 3" => ["c"] })

    output = subject.merge
    result = output[:result]

    expect(result).to eq(
      "bucket 1" => ["a"],
      "bucket 2" => ["b"],
      "bucket 3" => ["c"]
    )
    expect(output[:shards]).to eq(2)
    expect(JSON.parse(File.read(base_path))).to eq(result)
  end

  it "deep-merges overlapping buckets by concatenating and sorting messages" do
    write_shard(0, { "bucket 1" => ["b", "a"] })
    write_shard(1, { "bucket 1" => ["c", "a"] })

    result = subject.merge[:result]

    expect(result).to eq("bucket 1" => ["a", "a", "b", "c"])
  end

  it "warns and returns empty result when no shards exist" do
    expect { output = subject.merge }.to output(/No shards found/).to_stderr

    output = subject.merge

    expect(output[:result]).to eq({})
    expect(output[:shards]).to eq(0)
    expect(File.exist?(base_path)).to be false
  end

  it "warns and returns empty result when directory does not exist" do
    merger = described_class.new("/nonexistent/path/shitlist.json")

    expect { output = merger.merge }.to output(/Directory does not exist/).to_stderr

    output = merger.merge

    expect(output[:result]).to eq({})
    expect(output[:shards]).to eq(0)
  end

  it "handles a single shard file" do
    write_shard(0, { "bucket 1" => ["a"] })

    output = subject.merge

    expect(output[:result]).to eq("bucket 1" => ["a"])
    expect(output[:shards]).to eq(1)
  end

  it "deletes shard files when delete_shards is true" do
    shard0 = write_shard(0, { "bucket 1" => ["a"] })
    shard1 = write_shard(1, { "bucket 2" => ["b"] })

    merger = described_class.new(base_path, delete_shards: true)
    merger.merge

    expect(File.exist?(shard0)).to be false
    expect(File.exist?(shard1)).to be false
    expect(File.exist?(base_path)).to be true
  end

  it "preserves shard files by default" do
    shard0 = write_shard(0, { "bucket 1" => ["a"] })

    subject.merge

    expect(File.exist?(shard0)).to be true
  end

  it "sorts buckets alphabetically" do
    write_shard(0, { "z_bucket" => ["a"] })
    write_shard(1, { "a_bucket" => ["b"] })

    result = subject.merge[:result]

    expect(result.keys).to eq(["a_bucket", "z_bucket"])
  end

  it "raises an error for invalid JSON in a shard file" do
    shard_path = "#{base_path.chomp('.json')}.node-0.json"
    File.write(shard_path, "not valid json")

    expect { subject.merge }.to raise_error(/Invalid JSON in shard file/)
  end
end
