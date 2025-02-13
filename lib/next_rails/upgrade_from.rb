class NextRails::UpgradeFrom

  def initialize(current_version, response)
    @current_version = current_version
    @response = response
  end

  def self.report(current_version, response)
    new(current_version, response).print_report
  end

  def print_report
    return @response['detail'] if @response.fetch('detail', false)

    check_rails_version + check_ruby_version
  end

  private

  def ruby_version
    @response['required_ruby']
  end

  def check_rails_version
    if @response['next_rails'].nil?
      "\nYou are on the most current Rails version."
    elsif latest_patch?
      "\nYour application is running the latest patch version #{@current_version}, which is great!\n\n" +
      "The next Rails target upgrade should be #{@response['next_rails']}.\n\n"
    else
      "\nThe latest patch for Rails #{@current_version} is #{@response['current_latest_patch']}.\n\n" +
      "It is strongly recommended to upgrade to the latest patch before upgrading to the next Rails version.\n\n" +
      "The next Rails target upgrade should be #{@response['next_rails']}.\n\n"
    end
  end

  def check_ruby_version
    return "" if ruby_version.empty?

    "The required Ruby version#{'s' if ruby_version.length > 1} for the upgrade #{ruby_version.length > 1 ? 'are' : 'is' } #{ruby_version.join(', ')}.\n\n"
  end

  def latest_patch?
    @current_version == @response['current_latest_patch']
  end
end
