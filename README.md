# Next Rails

[![Continuous Integration](https://github.com/fastruby/next_rails/actions/workflows/main.yml/badge.svg)](https://github.com/fastruby/next_rails/actions/workflows/main.yml)

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

# Show gems that don't work with Ruby 3.0
bundle_report compatibility --ruby-version=3.0

# Find minimum compatible ruby version with Rails 7.0.0
bundle_report ruby_check --rails-version=7.0.0

# Show the usual help message
bundle_report --help
```

### Application usage

Every now and then it will be necessary to add code like this to your
application:

```ruby
if NextRails.next?
  # Do things "the Rails 7 way"
else
  # Do things "the Rails 6.1 way"
end
```

The `NextRails.next?` method will use your environment
(e.g. `ENV['BUNDLE_GEMFILE]`) to determine whether your application is
running with the next set of dependencies or the current set of dependencies.

This might come in handy if you need to inject
[Ruby or Rails shims](https://www.fastruby.io/blog/rails/upgrades/rails-upgrade-shims.html).

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

If using minitest, add this somewhere close to the top of your `test_helper.rb`:

```ruby
# Tracker deprecation messages in each file
if ENV["DEPRECATION_TRACKER"]
  DeprecationTracker.track_minitest(
    shitlist_path: "test/support/deprecation_warning.shitlist.json",
    mode: ENV["DEPRECATION_TRACKER"],
    transform_message: -> (message) { message.gsub("#{Rails.root}/", "") }
  )
end
```

> Keep in mind this is currently not compatible with the `minitest/parallel_fork` gem!

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

Right now, the path to the shitlist is hardcoded so make sure you store yours at `spec/support/deprecation_warning.shitlist.json`.

#### `next_rails` command

You can use `next_rails` to fetch the version of the gem installed.

```bash
next_rails --version
next_rails --help # For more options and examples
```

### Dual-boot Rails next

This command helps you dual-boot your application.

```bash
next_next --init    # Create Gemfile.next and Gemfile.next.lock
vim Gemfile         # Tweak your dependencies conditionally using `next?`
next bundle install # Install new gems
next rails s        # Start server using Gemfile.next
```

## Installation

Add this line to your application's Gemfile

> NOTE: If you add this gem to a group, make sure it is the test env group

```ruby
gem 'next_rails'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install next_rails

## Setup

Execute:

    $ next_rails --init

Init will create a Gemfile.next and an initialized Gemfile.next.lock.
The Gemfile.next.lock is initialized with the contents of your existing
Gemfile.lock lock file. We initialize the Gemfile.next.lock to prevent
major version jumps when running the next version of Rails.

## Contributing

Have a fix for a problem you've been running into or an idea for a new feature you think would be useful? Want to see how you can support `next_rails`?

Take a look at the [Contributing document](CONTRIBUTING.md) for instructions to set up the repo on your machine!

## Releases

`next_rails` adheres to [semver](https://semver.org). So given a version number MAJOR.MINOR.PATCH, we will increment the:

1. MAJOR version when you make incompatible API changes,
2. MINOR version when you add functionality in a backwards compatible manner, and
3. PATCH version when you make backwards compatible bug fixes.

Here are the steps to release a new version:

1. Update the `version.rb` file with the proper version number
2. Update `CHANGELOG.md` to have the right headers
3. Commit your changes to a `release/v-1-1-0` branch
4. Push your changes and submit a pull request
5. Merge your pull request to the `main` branch
6. Git tag the latest version of the `main` branch (`git tag v1.1.0`)
7. Push tags to GitHub (`git push --tags`)
8. Build the gem (`gem build next_rails.gemspec`)
9. Push the .gem package to Rubygems.org (`gem push next_rails-1.1.0.gem`)
10. You are all done!

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
