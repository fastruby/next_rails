require "json"
require "fileutils"

class DeprecationTracker
  class ShardMerger
    attr_reader :base_path, :delete_shards

    def initialize(base_path, delete_shards: false)
      @base_path = base_path
      @delete_shards = delete_shards
    end

    def merge
      dirname = File.dirname(base_path)
      unless File.directory?(dirname)
        warn "Directory does not exist: #{dirname}"
        return { shards: 0, result: {} }
      end

      shard_files = Dir.glob(shard_glob).sort

      if shard_files.empty?
        warn "No shards found at #{shard_glob}"
        return { shards: 0, result: {} }
      end

      merged = {}
      shard_files.each do |file|
        parse_shard(file).each do |bucket, messages|
          merged[bucket] = (merged[bucket] || []).concat(Array(messages))
        end
      end

      result = {}
      merged.sort.each do |k, v|
        result[k] = v.sort
      end

      begin
        File.write(base_path, JSON.pretty_generate(result))
      rescue Errno::EACCES => e
        raise "Cannot write to #{base_path}: #{e.message}"
      end

      shard_files.each { |f| File.delete(f) } if delete_shards

      { shards: shard_files.size, result: result }
    end

    private

    def shard_glob
      "#{base_path.chomp('.json')}.node-*.json"
    end

    def parse_shard(file)
      JSON.parse(File.read(file))
    rescue Errno::ENOENT
      raise "Shard file not found: #{file}"
    rescue JSON::ParserError => e
      raise "Invalid JSON in shard file #{file}: #{e.message}"
    end
  end
end
