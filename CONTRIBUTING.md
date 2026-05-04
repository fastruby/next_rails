# Contributing to next_rails

Have a fix for a problem you've been running into or an idea for a new feature you think would be useful? Bug reports and pull requests are welcome on GitHub at [https://github.com/fastruby/next_rails](https://github.com/fastruby/next_rails).

Here's what you need to do:

- Read and understand the [Code of Conduct](https://github.com/fastruby/next_rails/blob/main/CODE_OF_CONDUCT.md).
- Fork this repo and clone your fork to somewhere on your machine.
- [Ensure that you have a working environment](#setting-up-your-environment)
- Read up on [run the tests](#running-all-tests).
- Open a new branch and write a failing test for the feature or bug fix you plan on implementing.
- [Update the changelog when applicable](#a-word-on-the-changelog).
- Push to your fork and submit a pull request.
- [Make sure the test suite passes on GitHub Actions and make any necessary changes to your branch to bring it to green.](#continuous-integration).

## Setting up your environment
To install the dependencies, run:

```bash
bin/setup
```

You can also run `bin/console` for an interactive prompt that will allow you to experiment with the gem.

To install this gem onto your local machine, run:

`bundle exec rake install`.

### Running all tests

To run all of the tests, simply run:

```bash
bundle exec rake
```

### Testing against specific Ruby versions

See the [Docker Development Environment for Old Ruby Versions](https://github.com/fastruby/next_rails/wiki/Docker-Development-Environment-for-Old-Ruby-Versions) wiki page for setup and examples.

## A word on the changelog

You may also notice that we have a changelog in the form of [CHANGELOG.md](CHANGELOG.md). We use a format based on [Keep A Changelog](https://keepachangelog.com/en/1.0.0/).

The important things to keep in mind are:

- If your PR closes any open GitHub issue, make sure you include `Closes #XXXX` in your comment.
- New additions get added under the main (unreleased) heading;
- Attach a link to the PR with the following format:

* [<FEATURE | BUGFIX | CHORE>: Description of changes](github.com/link/to/pr).

## When Submitting a Pull Request:

* If your PR closes any open GitHub issues, please include `Closes #XXXX` in your comment.
* Please include a summary of the change and which issue is fixed or which feature is introduced.
* If changes to the behavior are made, clearly describe what are the changes and why.
* If changes to the UI are made, please include screenshots of the before and after.

## Continuous integration

After opening your Pull Request, please make sure that all tests pass on the CI, to make sure your changes work in all possible environments. GitHub Actions will kick in after you push up a branch or open a PR.

If the build fails, click on a failed job and scroll through its output to verify what is the problem. Push your changes to your branch until the build is green.
