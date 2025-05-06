# main [(unreleased)](https://github.com/fastruby/next_rails/compare/v1.4.6...main)

- [BUGFIX: example](https://github.com/fastruby/next_rails/pull/<number>)
- [CHORE: Create an entry point for the BundleReport command](https://github.com/fastruby/next_rails/pull/154)

* Your changes/patches go here.

# v1.4.6 / 2025-04-15 [(commits)](https://github.com/fastruby/next_rails/compare/v1.4.5...v1.4.6)

- [BUFIX: Fix compatibilities performance bug](https://github.com/fastruby/next_rails/pull/150)

# v1.4.5 / 2025-03-07 [(commits)](https://github.com/fastruby/next_rails/compare/v1.4.4...v1.4.5)

- [Move rails_version compatibility to its own class](https://github.com/fastruby/next_rails/pull/137)

# v1.4.4 / 2025-02-26 [(commits)](https://github.com/fastruby/next_rails/compare/v1.4.3...v1.4.4)

- [FEATURE: Update deprecation tracker to support newer Rails versions (7.1+)](https://github.com/fastruby/next_rails/pull/142)

# v1.4.3 / 2025-02-20 [(commits)](https://github.com/fastruby/next_rails/compare/v1.4.2...v1.4.3)

- [Add next_rails --init](https://github.com/fastruby/next_rails/pull/139)
- [Add Ruby 3.4 support](https://github.com/fastruby/next_rails/pull/133)

# v1.4.2 / 2024-10-25 [(commits)](https://github.com/fastruby/next_rails/compare/v1.4.1...v1.4.2)

- [BUGFIX: Rainbow patch: the methods (bold & white) are not on String](https://github.com/fastruby/next_rails/pull/132)

# v1.4.1 / 2024-10-22 [(commits)](https://github.com/fastruby/next_rails/compare/v1.4.0...v1.4.1)

- [BUGFIX: Fix performance regression due to rainbow refinement](https://github.com/fastruby/next_rails/pull/131)

# v1.4.0 / 2024-09-24 [(commits)](https://github.com/fastruby/next_rails/compare/v1.3.0...v1.4.0)

- [CHORE: Use next_rails namespace on spec tests.](https://github.com/fastruby/next_rails/pull/117)
- [CHORE: Remove 2.0.0, 2.1, 2.2 Ruby support](https://github.com/fastruby/next_rails/pull/126)
- [CHORE: Update compatibility for Ruby versions to use Rainbow](https://github.com/fastruby/next_rails/pull/125)
- [FEATURE: Support compatibility for Ruby versions](https://github.com/fastruby/next_rails/pull/116)
- [CHORE: Remove GPL licensed dependency Colorize and replace it with Rainbow]

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
