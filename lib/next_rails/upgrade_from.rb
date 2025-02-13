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

  def self.update_gemfile(gems)
    gem_names = []
    gems.each do |gem|
      gem_names << gem[:name]
      NextRails::UpgradeFrom.replace_gem_with_condition(gem[:name], "gem '#{gem[:name]}', '#{gem[:version]}'")
    end

    if gem_names.any?
      puts "\nThe Gemfile has been modified to include the updated gems."
      puts "Run `bundle update #{gem_names.join(' ')} --conservative`."
    end
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

  def self.replace_gem_with_condition(gem_name, conditional_statement)
    gemfile_path = File.join(Dir.pwd, "Gemfile")
    lines = File.readlines(gemfile_path)

    lines.each_with_index do |line, index|
      if line.match?(/^\s*gem ['"]#{gem_name}['"]/)
        original_gem = line.strip
        new_block = <<~RUBY
          if next?
            #{conditional_statement}
          else
            #{original_gem}
          end
        RUBY

        lines[index] = new_block
        break
      end
    end

    File.write(gemfile_path, lines.join)
  end

end



