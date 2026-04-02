# Next Rails

[![Continuous Integration](https://github.com/fastruby/next_rails/actions/workflows/main.yml/badge.svg)](https://github.com/fastruby/next_rails/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/next_rails.svg)](https://rubygems.org/gems/next_rails)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

A toolkit to upgrade your next Rails application. It helps you set up **dual booting**, **track deprecation warnings**, and get a **compatibility report** on outdated dependencies for any Rails application. [Learn more](https://www.fastruby.io/blog/next-rails-gem.html).

## Features

- **Dual Boot** — Run your app against two sets of dependencies (e.g. Rails 7.1 and Rails 7.2) side by side
- **Deprecation Tracking** — Capture and compare deprecation warnings across test runs (RSpec & Minitest)
- **Bundle Report** — Check gem compatibility with a target Rails or Ruby version
- **Ruby Check** — Find the minimum Ruby version compatible with a target Rails version

## Installation

Add this line to your application's Gemfile:

> [!WARNING]
> We recommend adding `next_rails` in the root of your Gemfile, not inside a group.
> This ensures `NextRails.next?` and `NextRails.current?` are available everywhere in your codebase.

```ruby
gem 'next_rails'
```

Then run:

```bash
bundle install
```

## Dual Boot

We recommend upgrading **one minor version at a time** (e.g. 7.1 → 7.2, not 6.1 → 7.0). This keeps changes small and manageable.

### Setup

> [!NOTE]
> The `next_rails --init` command will add a `next?` helper method to the top of your Gemfile, which you can use to conditionally set gem versions.

```bash
# Initialize dual boot (creates Gemfile.next and Gemfile.next.lock)
next_rails --init

# Edit your Gemfile to conditionally set gem versions using `next?`
vim Gemfile

# Install dependencies for the next version
next bundle install

# Start your server using the next Gemfile
next rails s
```

### Conditional code

When your Gemfile targets two versions, you may need to branch application code as well:

```ruby
if NextRails.next?
  # Do things "the Rails 7.2 way"
else
  # Do things "the Rails 7.1 way"
end
```

Or use `NextRails.current?` for the inverse check:

```ruby
if NextRails.current?
  # Do things "the Rails 7.1 way"
else
  # Do things "the Rails 7.2 way"
end
```

Both methods check your environment (e.g. `ENV['BUNDLE_GEMFILE']`) to determine which dependency set is active. This is useful for injecting [Ruby or Rails shims](https://www.fastruby.io/blog/rails/upgrades/rails-upgrade-shims.html).

## Bundle Report

Inspect your Gemfile and check compatibility with a target Rails or Ruby version.

```bash
# Show all out-of-date gems
bundle_report outdated

# Show all out-of-date gems in JSON format
bundle_report outdated --json

# Show gems incompatible with Rails 7.2
bundle_report compatibility --rails-version=7.2

# Show gems incompatible with Ruby 3.3
bundle_report compatibility --ruby-version=3.3

# Find minimum Ruby version compatible with Rails 7.2
bundle_report ruby_check --rails-version=7.2

# Help
bundle_report --help
```

## Deprecation Tracking

Track deprecation warnings in your test suite so you can monitor and fix them incrementally.

### RSpec

Add to `rails_helper.rb` or `spec_helper.rb`:

```ruby
RSpec.configure do |config|
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

### Minitest

Add near the top of `test_helper.rb`:

```ruby
if ENV["DEPRECATION_TRACKER"]
  DeprecationTracker.track_minitest(
    shitlist_path: "test/support/deprecation_warning.shitlist.json",
    mode: ENV["DEPRECATION_TRACKER"],
    transform_message: -> (message) { message.gsub("#{Rails.root}/", "") }
  )
end
```

> [!NOTE]
> This is currently not compatible with the `minitest/parallel_fork` gem.

### Running deprecation tracking

```bash
# Save current deprecations to the shitlist
DEPRECATION_TRACKER=save rspec

# Fail if deprecations have changed since the last save
DEPRECATION_TRACKER=compare rspec
```

### `deprecations` command

View, filter, and manage stored deprecation warnings:

```bash
deprecations info
deprecations info --pattern "ActiveRecord::Base"
deprecations run
deprecations --help
```

## CLI Reference

```bash
bundle exec next_rails --init    # Set up dual boot
bundle exec next_rails --version # Show gem version
bundle exec next_rails --help    # Show help
```

## Contributing

Bug reports and pull requests are welcome! See the [Contributing guide](CONTRIBUTING.md) for setup instructions and guidelines.

## Releases

`next_rails` follows [Semantic Versioning](https://semver.org). Given a version number `MAJOR.MINOR.PATCH`, we increment the:

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible new functionality
- **PATCH** version for backwards-compatible bug fixes

### Steps to release a new version

1. Update the version number in `lib/next_rails/version.rb`
2. Update `CHANGELOG.md` with the appropriate headers and entries
3. Commit your changes to a `release/v1.x.x` branch
4. Push your changes and submit a pull request `Release v1.x.x`
5. Merge your pull request to the `main` branch
6. Tag the latest version on `main`: `git tag v1.x.x`
7. Push the tag to GitHub: `git push --tags`
8. Build the gem: `gem build next_rails.gemspec`
9. Push to RubyGems: `gem push next_rails-1.x.x.gem`

## Maintainers

Maintained by [OmbuLabs / FastRuby.io](https://www.fastruby.io).

## History

This gem started as a fork of [`ten_years_rails`](https://github.com/clio/ten_years_rails), a companion to the "[Ten Years of Rails Upgrades](https://www.youtube.com/watch?v=6aCfc0DkSFo)" conference talk by Jordan Raine.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
