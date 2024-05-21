require "colorize"
require "cgi"
require "erb"
require "json"
require "net/http"

module NextRails
  module BundleReport
    extend self

    def compatibility(rails_version: nil, include_rails_gems: nil, gemfile_path: nil, gemfile_lock_path: nil)
      incompatible_gems = NextRails::GemInfo.all(gemfile_path, gemfile_lock_path).reject do |gem|
        gem.compatible_with_rails?(rails_version: rails_version) || (!include_rails_gems && gem.from_rails?)
      end.sort_by { |gem| gem.name }

      incompatible_gems.each { |gem| gem.find_latest_compatible(rails_version: rails_version) }

      incompatible_gems_by_state = incompatible_gems.group_by { |gem| gem.state(rails_version) }

      { incompatible_gems_by_state: incompatible_gems_by_state, incompatible_gems: incompatible_gems, rails_version: rails_version }
    end

    def erb_output(incompatible_gems_by_state, incompatible_gems, rails_version)
      template = <<-ERB
<% if incompatible_gems_by_state[:found_compatible] -%>
<%= "=> Incompatible with Rails #{rails_version} (with new versions that are compatible):".white.bold %>
<%= "These gems will need to be upgraded before upgrading to Rails #{rails_version}.".italic %>

<% incompatible_gems_by_state[:found_compatible].each do |gem| -%>
<%= gem_header(gem) %> - upgrade to <%= gem.latest_compatible_version.version %>
<% end -%>

<% end -%>
<% if incompatible_gems_by_state[:incompatible] -%>
<%= "=> Incompatible with Rails #{rails_version} (with no new compatible versions):".white.bold %>
<%= "These gems will need to be removed or replaced before upgrading to Rails #{rails_version}.".italic %>

<% incompatible_gems_by_state[:incompatible].each do |gem| -%>
<%= gem_header(gem) %> - new version, <%= gem.latest_version.version %>, is not compatible with Rails #{rails_version}
<% end -%>

<% end -%>
<% if incompatible_gems_by_state[:no_new_version] -%>
<%= "=> Incompatible with Rails #{rails_version} (with no new versions):".white.bold %>
<%= "These gems will need to be upgraded by us or removed before upgrading to Rails #{rails_version}.".italic %>
<%= "This list is likely to contain internal gems, like Cuddlefish.".italic %>

<% incompatible_gems_by_state[:no_new_version].each do |gem| -%>
<%= gem_header(gem) %> - new version not found
<% end -%>

<% end -%>
<%= incompatible_gems.length.to_s.red %> gems incompatible with Rails <%= rails_version %>
      ERB

      erb_version = ERB.version
      if erb_version =~ /erb.rb \[([\d\.]+) .*\]/
        erb_version = $1
      end

      if Gem::Version.new(erb_version) < Gem::Version.new("2.2")
        ERB.new(template, nil, "-").result(binding)
      else
        ERB.new(template, trim_mode: "-").result(binding)
      end
    end

    def gem_header(_gem)
      header = "#{_gem.name} #{_gem.version}".bold
      header << " (loaded from git)".magenta if _gem.sourced_from_git?
      header
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
          #{header.bold.white}: released #{gem.age} (latest version, #{gem.latest_version.version}, released #{gem.latest_version.age})
        MESSAGE
      end

      percentage_out_of_date = ((out_of_date_gems.count / total_gem_count.to_f) * 100).round
      footer = <<-MESSAGE
        #{sourced_from_git_count.to_s.yellow} gems are sourced from git
        #{out_of_date_gems.count.to_s.red} of the #{total_gem_count} gems are out-of-date (#{percentage_out_of_date}%)
      MESSAGE

      puts ''
      puts footer
    end
  end
end