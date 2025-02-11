require "rainbow"
require "cgi"
require "erb"
require "json"
require "net/http"

module NextRails
  module BundleReport
    extend self

    def ruby_compatibility(ruby_version: nil)
      return unless ruby_version

      options = { ruby_version: ruby_version }
      puts RubyVersionCompatibility.new(options: options).generate
    end

    def rails_compatibility(rails_version: nil, include_rails_gems: nil)
      return unless rails_version

      options = { rails_version: rails_version, include_rails_gems: include_rails_gems }
      puts RailsVersionCompatibility.new(options: options).generate
    end

    def compatible_ruby_version(rails_version)
      # find all the versions of rails gem
      uri = URI('https://rubygems.org/api/v1/versions/rails.json')
      res = Net::HTTP.get_response(uri)
      all_versions_res = JSON.parse(res.body)

      # push all the versions in an array
      all_versions = []
      all_versions_res.each { |rv| all_versions << rv['number'] }

      rv = rails_version[:rails_version]
      matched_versions = all_versions.select { |h| h.start_with?(rv) }

      # the list can either have the exact version or the latest version in the series of versions
      # you are looking at
      # ex: matched_versions = ["6.1.4.2", "6.1.4.1", "6.1.4"]
      # if you have passed "6.1.4" and the list has the exact version, it will match and send
      # the ruby version for it bu tif you had passed "6.1", then it will look for the
      # latest version matching "6.1" which is "6.1.4.2" in this case and will return ruby
      # version for it.
      exact_version = matched_versions.include?(rv) ? rv : matched_versions[0]

      if exact_version
        uri = URI("https://rubygems.org/api/v2/rubygems/rails/versions/#{exact_version}.json")
        res = Net::HTTP.get_response(uri)
        ruby_version = JSON.parse(res.body)["ruby_version"]
      else
        ruby_version = nil
      end


      if ruby_version
        puts "The required ruby version is #{ruby_version} for matched rails version #{exact_version}"
        ruby_version
      else
        puts "Could not find a compatible ruby version"
      end
    end

    def outdated(format = nil)
      gems = NextRails::GemInfo.all
      out_of_date_gems = gems.reject(&:up_to_date?).sort_by(&:created_at)
      sourced_from_git = gems.select(&:sourced_from_git?)

      if format == 'json'
        output_to_json(out_of_date_gems, gems.count, sourced_from_git.count)
      else
        output_to_stdout(out_of_date_gems, gems.count, sourced_from_git.count)
      end
    end

    def output_to_json(out_of_date_gems, total_gem_count, sourced_from_git_count)
      obj = build_json(out_of_date_gems, total_gem_count, sourced_from_git_count)
      puts JSON.pretty_generate(obj)
    end

    def build_json(out_of_date_gems, total_gem_count, sourced_from_git_count)
      output = Hash.new { [] }
      out_of_date_gems.each do |gem|
        output[:outdated_gems] += [
          {
            name: gem.name,
            installed_version: gem.version,
            installed_age: gem.age,
            latest_version: gem.latest_version.version,
            latest_age: gem.latest_version.age
          }
        ]
      end

      output.merge(
        {
          sourced_from_git_count: sourced_from_git_count,
          total_gem_count: total_gem_count
        }
      )
    end

    def output_to_stdout(out_of_date_gems, total_gem_count, sourced_from_git_count)
      out_of_date_gems.each do |gem|
        header = "#{gem.name} #{gem.version}"

        puts <<-MESSAGE
          #{Rainbow(header).bold.white}: released #{gem.age} (latest version, #{gem.latest_version.version}, released #{gem.latest_version.age})
        MESSAGE
      end

      percentage_out_of_date = ((out_of_date_gems.count / total_gem_count.to_f) * 100).round
      footer = <<-MESSAGE
        #{Rainbow(sourced_from_git_count.to_s).yellow} gems are sourced from git
        #{Rainbow(out_of_date_gems.count.to_s).red} of the #{total_gem_count} gems are out-of-date (#{percentage_out_of_date}%)
      MESSAGE

      puts ''
      puts footer
    end
  end
end
