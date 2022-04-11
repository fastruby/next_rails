# Next Rails

This is a toolkit to upgrade your next Rails application. It will help you
set up dual booting, track deprecation warnings, and get a report on outdated
dependencies for any Rails application.

This project is a fork of [`ten_years_rails`](https://github.com/clio/ten_years_rails)

## History

This gem started as a companion to the "[Ten Years of Rails Upgrades](https://www.youtube.com/watch?v=6aCfc0DkSFo)"
conference talk by Jordan Raine.

> You'll find various utilities that we use at Clio to help us prepare for and
> complete Rails upgrades.

> These scripts are still early days and may not work in every environment or app.

> I wouldn't recommend adding this to your Gemfile long-term. Rather, try out
> the scripts and use them as a point of reference. Feel free to tweak them to
> better fit your environment.

## Usage

### `bundle_report`

Learn about your Gemfile and see what needs updating.

```bash
# Show all out-of-date gems
bundle_report outdated

# Show five oldest, out-of-date gems
bundle_report outdated | head -n 5

# Show all out-of-date gems in machine readable JSON format
bundle_report outdated --json

# Show gems that don't work with Rails 5.2.0
bundle_report compatibility --rails-version=5.2.0

# Show the usual help message
bundle_report --help
```

### Deprecation tracking

If you're using RSpec, add this snippet to `rails_helper.rb` or `spec_helper.rb` (whichever loads Rails).

```ruby
RSpec.configure do |config|
  # Tracker deprecation messages in each file
  if ENV["DEPRECATION_TRACKER"]
    DeprecationTracker.track_rspec(
      config,
      shitlist_path: "spec/support/deprecation_warning.shitlist.json",
      mode: ENV["DEPRECATION_TRACKER"],
      transform_message: -> (message) { message.gsub("#{Rails.root}/", "") }
    )
  end
end
```

We don't use MiniTest, so there isn't a prebuilt config for it but I suspect it's pretty similar to `DeprecationTracker.track_rspec`.

Once you have that, you can start using deprecation tracking in your tests:

```bash
# Run your tests and save the deprecations to the shitlist
DEPRECATION_TRACKER=save rspec
# Run your tests and raise an error when the deprecations change
DEPRECATION_TRACKER=compare rspec
```

#### `deprecations` command

Once you have stored your deprecations, you can use `deprecations` to display common warnings, run specs, or update the shitlist file.

```bash
deprecations info
deprecations info --pattern "ActiveRecord::Base"
deprecations run
deprecations --help # For more options and examples
```

Right now, the path to the shitlist is hardcoded so make sure you store yours at `spec/support/deprecations.shitlist.json`.

#### `next_rails` command

You can use `next_rails` to fetch the version of the gem installed.

```bash
next_rails --version
next_rails --help # For more options and examples
```

### Dual-boot Rails next

This command helps you dual-boot your application.

```bash
next --init         # Create Gemfile.next and Gemfile.next.lock
vim Gemfile         # Tweak your dependencies conditionally using `next?`
next bundle install # Install new gems
next rails s        # Start server using Gemfile.next
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'next_rails'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install next_rails

## Setup

Execute:

    $ next --init

Init will create a Gemfile.next and an initialized Gemfile.next.lock.
The Gemfile.next.lock is initialized with the contents of your existing 
Gemfile.lock lock file. We initialize the Gemfile.next.lock to prevent
major version jumps when running the next version of Rails.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
