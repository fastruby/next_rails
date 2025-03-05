if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start do
    # Disambiguates individual test runs
    command_name "Job #{ENV["TEST_ENV_NUMBER"]}" if ENV["TEST_ENV_NUMBER"]

    if ENV['CI']
      formatter SimpleCov::Formatter::SimpleFormatter
    else
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::SimpleFormatter,
        SimpleCov::Formatter::HTMLFormatter
      ])
    end

    track_files "lib/**/*.rb"
  end
end

require "bundler/setup"
require "next_rails"

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    stub_request(:get, /rubygems.org\/api\/v2\/rubygems\/rails\/versions/).
      with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'rubygems.org', 'User-Agent'=>'Ruby'}).
      to_return(status: 200, body: "{\"ruby_version\": \">= 2.7.0\"}", headers: {})

    stub_request(:get, /rubygems.org\/api\/v1\/versions\/rails.json/).
      with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'rubygems.org', 'User-Agent'=>'Ruby'}).
      to_return(status: 200, body: "[{\"number\": \"7.0.0\"}, {\"number\": \"6.1.6\"}]", headers: {})
  end
end

def with_env(env_hash)
  stub_const("ENV", ENV.to_hash.merge!(env_hash))
end

def with_captured_stdout
  old_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_stdout
end
