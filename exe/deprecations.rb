#!/usr/bin/env ruby
require "json"
require "colorize"
require "optparse"
require "set"

def run_tests(deprecation_warnings, opts = {})
  tracker_mode = opts[:tracker_mode]
  next_mode = opts[:next_mode]
  rspec_command = if next_mode
    "bin/next rspec"
  else
    "bundle exec rspec"
  end

  command = "DEPRECATION_TRACKER=#{tracker_mode} #{rspec_command} #{deprecation_warnings.keys.join(" ")}"
  puts command
  exec command
end

def print_info(deprecation_warnings, opts = {})
  verbose = !!opts[:verbose]
  frequency_by_message = deprecation_warnings.each_with_object({}) do |(test_file, messages), hash|
    messages.each do |message|
      hash[message] ||= { test_files: Set.new, occurrences: 0 }
      hash[message][:test_files] << test_file
      hash[message][:occurrences] += 1
    end
  end.sort_by {|message, data| data[:occurrences] }.reverse.to_h

  puts "Ten most common deprecation warnings:".underline
  frequency_by_message.take(10).each do |message, data|
    puts "Occurrences: #{data.fetch(:occurrences)}".bold
    puts "Test files: #{data.fetch(:test_files).to_a.join(" ")}" if verbose
    puts message.red
    puts "----------"
  end
end

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = <<-MESSAGE
    Usage: #{__FILE__.to_s} [options] [mode]

      Parses the deprecation warning shitlist and show info or run tests.

    Examples:
      bin/deprecations info # Show top ten deprecations
      bin/deprecations --next info # Show top ten deprecations for Rails 5
      bin/deprecations --pattern "ActiveRecord::Base" --verbose info # Show full details on deprecations matching pattern
      bin/deprecations --tracker-mode save --pattern "pass" run # Run tests that output deprecations matching pattern and update shitlist
      bin/deprecations info --shitlist-path ./spec/support/deprecations.log.json # Show top ten deprecations for a given file.

    Modes:
      info
        Show information on the ten most frequent deprceation warnings.

      run
        Run tests that are known to cause deprecation warnings. Use --pattern to filter what tests are run.

    Options:
  MESSAGE

  opts.on("--next", "Run against the next shitlist") do |next_mode|
    options[:next] = next_mode
  end

  opts.on("--tracker-mode MODE", "Set DEPRECATION_TRACKER in test mode. Options: save or compare") do |tracker_mode|
    options[:tracker_mode] = tracker_mode
  end

  opts.on("--pattern RUBY_REGEX", "Filter deprecation warnings with a pattern.") do |pattern|
    options[:pattern] = pattern
  end

  opts.on("--verbose", "show more information") do
    options[:verbose] = true
  end

  opts.on("--shitlist-path", "Set a custom path for the deprecations shitlist json file") do |shitlist_path|
    options[:shitlist_path] = shitlist_path
  end

  opts.on_tail("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end

option_parser.parse!

options[:mode] = ARGV.last

default_path = options[:next] ? "spec/support/deprecation_warning.next.shitlist.json" : "spec/support/deprecation_warning.shitlist.json"
shitlist_path = options.fetch(:shitlist_path, default_path)

pattern_string = options.fetch(:pattern, ".+")
pattern = /#{pattern_string}/

deprecation_warnings = JSON.parse(File.read(shitlist_path)).each_with_object({}) do |(test_file, messages), hash|
  filtered_messages = messages.select {|message| message.match(pattern) }
  hash[test_file] = filtered_messages if !filtered_messages.empty?
end

if deprecation_warnings.empty?
  abort "No test files with deprecations matching #{pattern.inspect}."
  exit 2
end

case options.fetch(:mode, "info")
when "run" then run_tests(deprecation_warnings, next_mode: options[:next], tracker_mode: options[:tracker_mode])
when "info" then print_info(deprecation_warnings, verbose: options[:verbose])
when nil
  STDERR.puts "Must pass a mode: run or info".red
  puts option_parser
  exit 1
else
  STDERR.puts "Unknown mode: #{options[:mode]}".red
  exit 1
end
