require "colorize"
require "cgi"
require "erb"
require "json"

module NextRails
  class BundleReport
    def self.compatibility(rails_version:, include_rails_gems:)
      incompatible_gems = NextRails::GemInfo.all.reject do |gem|
        gem.compatible_with_rails?(rails_version: rails_version) || (!include_rails_gems && gem.from_rails?)
      end.sort_by do |gem|
        [
          gem.latest_version.compatible_with_rails?(rails_version: rails_version) ? 0 : 1,
          gem.name
        ].join("-")
      end

      incompatible_gems_by_state = incompatible_gems.group_by { |gem| gem.state(rails_version) }

      template = <<~ERB
        <% if incompatible_gems_by_state[:latest_compatible] -%>
        <%= "=> Incompatible with Rails #{rails_version} (with new versions that are compatible):".white.bold %>
        <%= "These gems will need to be upgraded before upgrading to Rails #{rails_version}.".italic %>

        <% incompatible_gems_by_state[:latest_compatible].each do |gem| -%>
        <%= gem_header(gem) %> - upgrade to <%= gem.latest_version.version %>
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

      puts ERB.new(template, nil, "-").result(binding)
    end

    def self.gem_header(_gem)
      header = "#{_gem.name} #{_gem.version}".bold
      header << " (loaded from git)".magenta if _gem.sourced_from_git?
      header
    end

    def self.outdated
      gems = NextRails::GemInfo.all
      out_of_date_gems = gems.reject(&:up_to_date?).sort_by(&:created_at)
      sourced_from_git = gems.select(&:sourced_from_git?)

      output_to_io(out_of_date_gems, gems.count, sourced_from_git.count)
    end

    def self.outdated
      gems = NextRails::GemInfo.all
      out_of_date_gems = gems.reject(&:up_to_date?).sort_by(&:created_at)
      sourced_from_git = gems.select(&:sourced_from_git?)

      output_to_stdout(out_of_date_gems, gems.count, sourced_from_git.count)
    end

    def self.output_to_stdout(out_of_date_gems, total_gem_count, sourced_from_git_count)
      out_of_date_gems.each do |gem|
        header = "#{gem.name} #{gem.version}"

        puts <<~MESSAGE
          #{header.bold.white}: released #{gem.age} (latest version, #{gem.latest_version.version}, released #{gem.latest_version.age})
        MESSAGE
      end

      percentage_out_of_date = ((out_of_date_gems.count / total_gem_count.to_f) * 100).round
      footer = <<~MESSAGE
        #{sourced_from_git_count.to_s.yellow} gems are sourced from git
        #{out_of_date_gems.count.to_s.red} of the #{total_gem_count} gems are out-of-date (#{percentage_out_of_date}%)
      MESSAGE

      puts ''
      puts footer
    end
  end
end
