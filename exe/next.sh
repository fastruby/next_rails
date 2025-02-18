#!/bin/bash
if [[ "${@}" == "--init" ]]; then
  echo "The next --init command is deprecated. Please use the next_rails --init command instead."
  # Add next? top of Gemfile
  cat <<-STRING > Gemfile.tmp
def next?
  File.basename(__FILE__) == "Gemfile.next"
end
STRING
  cat Gemfile >> Gemfile.tmp
  mv Gemfile.tmp Gemfile

  ln -s Gemfile Gemfile.next

  # Initialize the Gemfile.next.lock
  # Prevents major version jumps when we start without a Gemfile.next.lock
  if [ -f "Gemfile.lock" ] && [ ! -f "Gemfile.next.lock" ]; then
    cp Gemfile.lock Gemfile.next.lock
  fi

  echo <<-MESSAGE
Created Gemfile.next (a symlink to your Gemfile). Your Gemfile has been modified to support dual-booting!

There's just one more step: modify your Gemfile to use a newer version of Rails using the \`next?\` helper method.

For example, here's how to go from 5.2.3 to 6.0:

if next?
  gem "rails", "6.0.0"
else
  gem "rails", "5.2.3"
end
MESSAGE
  exit $?
fi

if [[ "${@}" =~ ^bundle ]]; then
  BUNDLE_GEMFILE=Gemfile.next BUNDLE_CACHE_PATH=vendor/cache.next $@
else
  BUNDLE_GEMFILE=Gemfile.next BUNDLE_CACHE_PATH=vendor/cache.next bundle exec $@
fi

COMMAND_EXIT=$?

GEM_NOT_FOUND=7 # https://github.com/bundler/bundler/blob/master/lib/bundler/errors.rb#L35
EXECUTABLE_NOT_FOUND=127 # https://github.com/bundler/bundler/blob/master/lib/bundler/cli/exec.rb#L62
if [[ $COMMAND_EXIT -eq $GEM_NOT_FOUND || $COMMAND_EXIT -eq $EXECUTABLE_NOT_FOUND ]]; then
  BLUE='\033[0;34m'
  UNDERLINE_WHITE='\033[37m'
  NO_COLOR='\033[0m'

  echo -e "${BLUE}Having trouble running commands with ${UNDERLINE_WHITE}bin/next${BLUE}?"
  echo -e "Try running ${UNDERLINE_WHITE}bin/next bundle install${BLUE}, then try your command again.${NO_COLOR}"
fi

exit $COMMAND_EXIT
