# frozen_string_literal: true

require "next_rails/options"
require "spec_helper"

RSpec.describe NextRails::Options do
  describe ".check!" do
    it "returns the options when every key is allowed" do
      expect(described_class.check!({ rails_version: "5.0" }, :rails_version, :include_rails_gems)).to eq(rails_version: "5.0")
    end

    it "accepts an empty hash" do
      expect(described_class.check!({}, :rails_version)).to eq({})
    end

    it "raises on an unknown key" do
      expect { described_class.check!({ rails_versoin: "5.0" }, :rails_version) }
        .to raise_error(ArgumentError, "unknown keyword: :rails_versoin")
    end

    it "lists every unknown key" do
      expect { described_class.check!({ a: 1, b: 2 }, :rails_version) }
        .to raise_error(ArgumentError, "unknown keywords: :a, :b")
    end

    it "raises when the options are not a hash" do
      expect { described_class.check!(true, :delete_shards) }
        .to raise_error(ArgumentError, "expected an options Hash, got true")
    end
  end

  it "makes the methods that take options reject misspelled keys" do
    expect { DeprecationTracker.merge_shards("/tmp/shitlist.json", delete_shard: true) }
      .to raise_error(ArgumentError, "unknown keyword: :delete_shard")
    expect { DeprecationTracker.new("/tmp/shitlist.json", nil, :save, nodeindex: "0") }
      .to raise_error(ArgumentError, "unknown keyword: :nodeindex")
    expect { NextRails::BundleReport.rails_compatibility(include_rails_gem: true) }
      .to raise_error(ArgumentError, "unknown keyword: :include_rails_gem")
  end
end
