require "json"
require "fileutils"

class DeprecationTracker
  class ShardMerger
    attr_reader :base_path

    def initialize(base_path)
      @base_path = base_path
    end

    def merge(delete_shards: false)
      shard_files = Dir.glob(shard_glob).sort

      merged = {}
      shard_files.each do |file|
        JSON.parse(File.read(file)).each do |bucket, messages|
          merged[bucket] = (merged[bucket] || []).concat(Array(messages))
        end
      end

      result = {}
      merged.sort.each do |k, v|
        result[k] = v.sort
      end

      dirname = File.dirname(base_path)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
      File.write(base_path, JSON.pretty_generate(result))

      shard_files.each { |f| File.delete(f) } if delete_shards

      { shards: shard_files.size, result: result }
    end

    private

    def shard_glob
      ext = File.extname(base_path)
      "#{base_path.chomp(ext)}.node-*#{ext}"
    end
  end
end
