# main [(unreleased)](https://github.com/fastruby/next_rails/compare/v1.3.0...main)

* Your changes/patches go here.
- [FEATURE: Support Rails 4 and before using the DeprecationTracker](https://github.com/fastruby/next_rails/pull/109)

# v1.3.0 / 2023-06-16 [(commits)](https://github.com/fastruby/next_rails/compare/v1.2.4...v1.3.0)

- [FEATURE: Add NextRails.next? for application usage (e.g. Rails shims)](https://github.com/fastruby/next_rails/pull/97)
- [BUGFIX: Support ERB versions older than 2.2.0](https://github.com/fastruby/next_rails/pull/100)

# v1.2.4 / 2023-04-21 [(commits)](https://github.com/fastruby/next_rails/compare/v1.2.3...v1.2.4)

- [BUGFIX: Update the warn method signature to support for Ruby 3]

# v1.2.3 / 2023-04-12 [(commits)](https://github.com/fastruby/next_rails/compare/v1.2.2...v1.2.3)

- [Fix ERB deprecation warning in Ruby 3.1]

- [Remove Rails gems from compatibility check]

# v1.2.2 / 2023-03-03 [(commits)](https://github.com/fastruby/next_rails/compare/v1.2.1...v1.2.2)
* [BUGFIX: Fixed `KernelWarnTracker#warn signature to match `Kernel#warn` for ruby 2.5+](https://github.com/fastruby/next_rails/pull/82)
* [CHORE: Added updated templates for bug fixes, feature requests and pull requests](https://github.com/fastruby/next_rails/pull/64) as per [this RFC](https://github.com/fastruby/RFCs/blob/main/2021-10-13-github-templates.md)
* [FEATURE: Turn BundleReport into a module](https://github.com/fastruby/next_rails/pull/63)

# v1.2.1 / 2022-09-26 [(commits)](https://github.com/fastruby/next_rails/compare/v1.2.0...v1.2.1)

- [BUGFIX: SimpleCov was not reporting accurately due to a bug in the spec helper code](https://github.com/fastruby/next_rails/pull/66)

- [FEATURE: Better documentation for contributing and releasing versions of this gem](https://github.com/fastruby/next_rails/pull/53)

- [BUGFIX: bundle_report outdated was giving an exception due to missing method latest_version](https://github.com/fastruby/next_rails/pull/62)

- [FEATURE: `bundle_report outdated` outputs in JSON format when passed optional argument](https://github.com/fastruby/next_rails/pull/61)

# v1.2.0 / 2022-08-12 [(commits)](https://github.com/fastruby/next_rails/compare/v1.1.0...v1.2.0)

- [FEATURE: Support Ruby versions as old as Ruby 2.0](https://github.com/fastruby/next_rails/pull/54)

- [FEATURE: Better documentation for contributing and releasing versions of this gem](https://github.com/fastruby/next_rails/pull/53)

# v1.1.0 / 2022-06-30 [(commits)](https://github.com/fastruby/next_rails/compare/v1.0.5...v1.1.0)

- [FEATURE: Try to find the latest **compatible** version of a gem if the latest version is not compatible with the desired Rails version when checking compatibility](https://github.com/fastruby/next_rails/pull/49)

- [FEATURE: Added option --version to get the version of the gem being used](https://github.com/fastruby/next_rails/pull/38)

- [Added github action workflow](https://github.com/fastruby/next_rails/pull/40)

- [FEATURE: Add support to use DeprecationTracker with Minitest](Add support to use DeprecationTracker with Minitest)

- [FEATURE: Add dependabot](https://github.com/fastruby/next_rails/pull/41)

- [DOCUMENTATION: Update the code of conduct link in PR template](https://github.com/fastruby/next_rails/pull/46)

- [DOCUMENTATION: Add FEATURE REQUEST and BUG REPORT templates ](https://github.com/fastruby/next_rails/pull/48)

- [BUGFIX: Make behavior arguments optional](https://github.com/fastruby/next_rails/pull/44)

- [FEATURE: Command line option to check for recommended ruby version for the desired Rails version](https://github.com/fastruby/next_rails/pull/39)

# v1.0.5 / 2022-03-29 [(commits)](https://github.com/fastruby/next_rails/compare/v1.0.4...v1.0.5)

- [FEATURE: Initialize the Gemfile.next.lock to avoid major version jumps when used without an initial Gemfile.next.lock](https://github.com/fastruby/next_rails/pull/25)
- [FEATURE: Drop `actionview` dependency because it is not really used](https://github.com/fastruby/next_rails/pull/26)
- [BUGFIX: If shitlist path does not exist, create it for the user of the gem](https://github.com/fastruby/next_rails/pull/37)

# v1.0.4 / 2021-04-09 [(commits)](https://github.com/fastruby/next_rails/compare/v1.0.3...v1.0.4)

- [BUGFIX: Fixes issue with `bundle_report` and `actionview`](https://github.com/fastruby/next_rails/pull/22)

# v1.0.3 / 2021-04-05 [(commits)](https://github.com/fastruby/next_rails/compare/v1.0.2...v1.0.3)

- [BUGFIX: Update README.md to better document this `ten_years_rails` fork](https://github.com/fastruby/next_rails/pull/11)
- [BUGFIX: Make ActionView an optional dependency](https://github.com/fastruby/next_rails/pull/6)

# v1.0.2 / 2020-01-20

# v1.0.1 / 2019-07-26

# v1.0.0 / 2019-07-24

- Official Release
