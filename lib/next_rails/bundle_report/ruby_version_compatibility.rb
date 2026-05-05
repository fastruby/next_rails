require "next_rails/tint"

class NextRails::BundleReport::RubyVersionCompatibility
  MINIMAL_VERSION = 1.0
  attr_reader :gems, :options

  def initialize(gems: NextRails::GemInfo.all, options: {})
    @gems = gems
    @options = options
  end

  def generate
    (valid? ? message : invalid_message).to_s
  end

  private

  def message
    noun = incompatible.one? ? "gem" : "gems"
    parts = [NextRails::Tint("=> Incompatible gems with Ruby #{ruby_version}:").white.bold]
    incompatible.each do |gem|
      parts << NextRails::Tint("#{gem.name} - required Ruby version: #{gem.gem_specification.required_ruby_version}").magenta
    end
    parts << ""
    parts << NextRails::Tint("#{incompatible.length} incompatible #{noun} with Ruby #{ruby_version}").red
    parts.join("\n")
  end

  def incompatible
    gems.reject { |gem| gem.compatible_with_ruby?(ruby_version) }
  end

  def ruby_version
    options[:ruby_version].to_f
  end

  def invalid_message
    NextRails::Tint("=> Invalid Ruby version: #{options[:ruby_version]}.").red.bold
  end

  def valid?
    ruby_version > MINIMAL_VERSION
  end
end
