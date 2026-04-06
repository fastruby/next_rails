# frozen_string_literal: true

require "spec_helper"

require "json"
require "tempfile"
require_relative "../lib/deprecation_tracker/shard_merger"

RSpec.describe DeprecationTracker::ShardMerger do
  let(:base_path) { Tempfile.new("shitlist").path }
  let(:ext) { File.extname(base_path) }
  let(:shard_prefix) { base_path.chomp(ext) }

  after do
    FileUtils.rm_f(base_path)
    Dir.glob("#{shard_prefix}.node-*#{ext}").each { |f| FileUtils.rm_f(f) }
  end

  def write_shard(index, data)
    path = "#{shard_prefix}.node-#{index}#{ext}"
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

  it "returns an empty hash and writes empty JSON when no shards exist" do
    output = subject.merge

    expect(output[:result]).to eq({})
    expect(output[:shards]).to eq(0)
    expect(JSON.parse(File.read(base_path))).to eq({})
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

    subject.merge(delete_shards: true)

    expect(File.exist?(shard0)).to be false
    expect(File.exist?(shard1)).to be false
    expect(File.exist?(base_path)).to be true
  end

  it "preserves shard files when delete_shards is false" do
    shard0 = write_shard(0, { "bucket 1" => ["a"] })

    subject.merge(delete_shards: false)

    expect(File.exist?(shard0)).to be true
  end

  it "sorts buckets alphabetically" do
    write_shard(0, { "z_bucket" => ["a"] })
    write_shard(1, { "a_bucket" => ["b"] })

    result = subject.merge[:result]

    expect(result.keys).to eq(["a_bucket", "z_bucket"])
  end
end
