class NextRails::BundleReport::RailsVersionCompatibility
  def initialize(gems: NextRails::GemInfo.all, options: {})
    @gems = gems
    @options = options
  end

  def generate
    erb_output
  end

  def incompatible_gems_by_state
    @incompatible_gems_by_state ||= begin
      incompatible_gems.each { |gem| gem.find_latest_compatible(rails_version: rails_version) }
      incompatible_gems.group_by { |gem| gem.state(rails_version) }
    end
  end

  private

  def erb_output
    template = <<-ERB
<% if incompatible_gems_by_state[:found_compatible] -%>
<%= Rainbow("=> Incompatible with Rails #{rails_version} (with new versions that are compatible):").white.bold %>
<%= Rainbow("These gems will need to be upgraded before upgrading to Rails #{rails_version}.").italic %>

<% incompatible_gems_by_state[:found_compatible].each do |gem| -%>
<%= gem_header(gem) %> - upgrade to <%= gem.latest_compatible_version.version %>
<% end -%>

<% end -%>
<% if incompatible_gems_by_state[:incompatible] -%>
<%= Rainbow("=> Incompatible with Rails #{rails_version} (with no new compatible versions):").white.bold %>
<%= Rainbow("These gems will need to be removed or replaced before upgrading to Rails #{rails_version}.").italic %>

<% incompatible_gems_by_state[:incompatible].each do |gem| -%>
<%= gem_header(gem) %> - new version, <%= gem.latest_version.version %>, is not compatible with Rails #{rails_version}
<% end -%>

<% end -%>
<% if incompatible_gems_by_state[:no_new_version] -%>
<%= Rainbow("=> Incompatible with Rails #{rails_version} (with no new versions):").white.bold %>
<%= Rainbow("These gems will need to be upgraded by us or removed before upgrading to Rails #{rails_version}.").italic %>
<%= Rainbow("This list is likely to contain internal gems, like Cuddlefish.").italic %>

<% incompatible_gems_by_state[:no_new_version].each do |gem| -%>
<%= gem_header(gem) %> - new version not found
<% end -%>

<% end -%>
<%= Rainbow(incompatible_gems.length.to_s).red %> gems incompatible with Rails <%= rails_version %>
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
    header = Rainbow("#{_gem.name} #{_gem.version}").bold
    header << Rainbow(" (loaded from git)").magenta if _gem.sourced_from_git?
    header
  end

  def incompatible_gems
    @incompatible_gems ||= @gems.reject do |gem|
      gem.compatible_with_rails?(rails_version: rails_version) || (!include_rails_gems && gem.from_rails?)
    end.sort_by { |gem| gem.name }
  end

  def rails_version
    @options[:rails_version]
  end

  def include_rails_gems
    @options[:include_rails_gems]
  end
end
