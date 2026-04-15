require "rainbow"
require "json"

# A shitlist for deprecation warnings during test runs. It has two modes: "save" and "compare"
#
# DEPRECATION_TRACKER=save
# Record deprecation warnings, grouped by spec file. After the test run, save to a file.
#
# DEPRECATION_TRACKER=compare
# Tracks deprecation warnings, grouped by spec file. After the test run, compare against shitlist of expected
# deprecation warnings. If anything is added or removed, raise an error with a diff of the changes.
#
class DeprecationTracker
  UnexpectedDeprecations = Class.new(StandardError)

  module KernelWarnTracker
    def self.callbacks
      @callbacks ||= []
    end

    def warn(*messages, uplevel: nil, category: nil, **kwargs)
      KernelWarnTracker.callbacks.each do |callback|
        messages.each { |message| callback.call(message) }
      end

      ruby_version = Gem::Version.new(RUBY_VERSION)

      if ruby_version >= Gem::Version.new("3.2.0")
        # Kernel#warn supports uplevel, category
        super(*messages, uplevel: uplevel, category: category)
      elsif ruby_version >= Gem::Version.new("2.5.0")
        # Kernel#warn supports only uplevel
        super(*messages, uplevel: uplevel)
      else
        # No keyword args supported
        super(*messages)
      end
    end
  end

  module MinitestExtension
    def self.new(deprecation_tracker)
      @@deprecation_tracker = deprecation_tracker

      Module.new do
        def before_setup
          test_file_name = method(name).source_location.first.to_s
          @@deprecation_tracker.bucket = test_file_name.gsub(Rails.root.to_s, ".")
          super
        end

        def after_teardown
          super
          @@deprecation_tracker.bucket = nil
        end
      end
    end
  end

  # There are two forms of the `warn` method: one for class Kernel and one for instances of Kernel (i.e., every Object)
  if Object.respond_to?(:prepend)
    Object.prepend(KernelWarnTracker)
  else
    Object.extend(KernelWarnTracker)
  end

  # Ruby 2.2 and lower doesn't appear to allow overriding of Kernel.warn using `singleton_class.prepend`.
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.3.0")
    Kernel.singleton_class.prepend(KernelWarnTracker)
  else
    def Kernel.warn(*args, &block)
      Object.warn(*args, &block)
    end
  end

  DEFAULT_PATH = "spec/support/deprecation_warning.shitlist.json"

  def self.init_tracker(opts = {})
    shitlist_path = opts[:shitlist_path] || DEFAULT_PATH
    mode = opts[:mode] || ENV["DEPRECATION_TRACKER"] || :save
    transform_message = opts[:transform_message]
    node_index = opts[:node_index]
    deprecation_tracker = DeprecationTracker.new(shitlist_path, transform_message, mode, node_index: node_index)
    # Since Rails 7.1 the preferred way to track deprecations is to use the deprecation trackers via
    # `Rails.application.deprecators`.
    # We fallback to tracking deprecations via the ActiveSupport singleton object if Rails.application.deprecators is
    # not defined for older Rails versions.
    if defined?(Rails) && defined?(Rails.application) && defined?(Rails.application.deprecators)
      Rails.application.deprecators.each do |deprecator|
        deprecator.behavior << -> (message, _callstack = nil, _deprecation_horizon = nil, _gem_name = nil) {
          deprecation_tracker.add(message)
        }
      end
    elsif defined?(ActiveSupport)
      ActiveSupport::Deprecation.behavior << -> (message, _callstack = nil, _deprecation_horizon = nil, _gem_name = nil) {
        deprecation_tracker.add(message)
      }
    end
    KernelWarnTracker.callbacks << -> (message) { deprecation_tracker.add(message) }

    deprecation_tracker
  end

  def self.track_rspec(rspec_config, opts = {})
    deprecation_tracker = init_tracker(opts)

    rspec_config.around do |example|
      deprecation_tracker.bucket = example.metadata.fetch(:rerun_file_path)

      begin
        example.run
      ensure
        deprecation_tracker.bucket = nil
      end
    end

    rspec_config.after(:suite) do
      deprecation_tracker.after_run
    end
  end

  def self.track_minitest(opts = {})
    tracker = init_tracker(opts)

    Minitest.after_run do
      tracker.after_run
    end

    ActiveSupport::TestCase.include(MinitestExtension.new(tracker))
  end

  def self.merge_shards(base_path, delete_shards: false)
    require_relative "deprecation_tracker/shard_merger"
    ShardMerger.new(base_path, delete_shards: delete_shards).merge[:result]
  end

  attr_reader :deprecation_messages, :shitlist_path, :transform_message, :bucket, :mode, :node_index

  def initialize(shitlist_path, transform_message = nil, mode = :save, node_index: nil)
    @shitlist_path = shitlist_path
    @transform_message = transform_message || -> (message) { message }
    @deprecation_messages = {}
    @mode = mode ? mode.to_sym : :save
    @node_index = node_index
  end

  def parallel?
    !@node_index.nil?
  end

  def shard_path
    ext = File.extname(shitlist_path)
    "#{shitlist_path.chomp(ext)}.node-#{node_index}#{ext}"
  end

  def target_path
    parallel? ? shard_path : shitlist_path
  end

  def add(message)
    return if bucket.nil?

    @deprecation_messages[bucket] << transform_message.(message)
  end

  def bucket=(value)
    @bucket = value
    @deprecation_messages[value] ||= [] unless value.nil?
  end

  def after_run
    if mode == :save
      save
    elsif mode == :compare
      compare
    end
  end

  def compare
    stored = read_json(shitlist_path)

    changed_buckets = []

    normalized_deprecation_messages.each do |bucket, messages|
      if stored[bucket] != messages
        changed_buckets << bucket
      end
    end

    if changed_buckets.any?
      message = <<-MESSAGE
        ⚠️  Deprecation warnings have changed!

        Code called by the following spec files is now generating different deprecation warnings:

        #{changed_buckets.join("\n")}

        To check your failures locally, you can run:

        DEPRECATION_TRACKER=compare bundle exec rspec #{changed_buckets.join(" ")}

        Here is a diff between what is expected and what was generated by this process:

        #{diff}

        See \e[4;37mdev-docs/testing/deprecation_tracker.md\e[0;31m for more information.
      MESSAGE

      raise UnexpectedDeprecations, Rainbow(message).red
    end
  end

  def diff
    temp_file = create_temp_file
    `git diff --no-index #{shitlist_path} #{temp_file.path}`
  ensure
    temp_file.delete
  end

  def save
    temp_file = create_temp_file
    create_if_path_does_not_exist(target_path)
    FileUtils.cp(temp_file.path, target_path)
  ensure
    temp_file.delete if temp_file
  end

  def create_if_path_does_not_exist(path)
    dirname = File.dirname(path)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
  end

  def create_temp_file
    temp_file = Tempfile.new("temp-deprecation-tracker-shitlist")
    temp_file.write(JSON.pretty_generate(normalized_deprecation_messages))
    temp_file.flush

    temp_file
  end

  # Normalize deprecation messages to reduce noise from file output and test files to be tracked with separate test runs
  def normalized_deprecation_messages
    @normalized_deprecation_messages ||= begin
      normalized = read_json(target_path).merge(deprecation_messages).each_with_object({}) do |(bucket, messages), hash|
        hash[bucket] = messages.sort
      end

      # not using `to_h` here to support older ruby versions
      {}.tap do |h|
        normalized.reject {|_key, value| value.empty? }.sort_by {|key, _value| key }.each do |k ,v|
          h[k] = v
        end
      end
    end
  end

  def read_json(path)
    return {} unless File.exist?(path)
    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    raise "#{path} is not valid JSON: #{e.message}"
  end
end
