module NextRails
  class GemInfo
    class NullGemInfo < GemInfo
      def initialize; end

      def age
        "-"
      end

      def created_at
        Time.now
      end

      def up_to_date?
        false
      end

      def version
        "NOT FOUND"
      end

      def unsatisfied_rails_dependencies(*)
        ["unknown"]
      end

      def state(_)
        :null
      end
    end

    RAILS_GEMS = [
      "rails",
      "activemodel",
      "activerecord",
      "actionmailer",
      "actioncable",
      "actionpack",
      "actionview",
      "activejob",
      "activestorage",
      "activesupport",
      "actionmailbox",
      "actiontext",
      "railties",
    ].freeze

    def self.all(gemfile_path, gemfile_lock_path)
      specs = if !gemfile_path.nil? && !gemfile_lock_path.nil? # Parse the specified gem file if the Gemfile and Gemfile.lock is provided
                Bundler::Definition.build(gemfile_path, gemfile_lock_path, false).specs
              else
                Gem::Specification # Parse the project's Gemfile and Gemfile.lock
              end
      specs.each.map do |gem_specification|
        new(gem_specification)
      end
    end

    attr_reader :gem_specification, :version, :name, :latest_compatible_version

    def initialize(gem_specification)
      @gem_specification = gem_specification
      @version = gem_specification.version
      @name = gem_specification.name
    end

    def age
      created_at.strftime("%b %e, %Y")
    end

    def sourced_from_git?
      !!gem_specification.git_version
    end

    def created_at
      @created_at ||= gem_specification.date
    end

    def up_to_date?
      version == latest_version.version
    end

    def from_rails?
      RAILS_GEMS.include?(name)
    end

    def state(rails_version)
      if compatible_with_rails?(rails_version: rails_version)
        :compatible
      elsif latest_compatible_version && latest_compatible_version.version == "NOT FOUND"
        :no_new_version
      elsif latest_compatible_version
        :found_compatible
      else
        :incompatible
      end
    end

    def latest_version
      latest_gem_specification = Gem.latest_spec_for(name)
      return NullGemInfo.new unless latest_gem_specification

      GemInfo.new(latest_gem_specification)
    rescue
      NullGemInfo.new
    end

    def compatible_with_rails?(rails_version: nil)
      unsatisfied_rails_dependencies(rails_version: rails_version).empty?
    end

    def unsatisfied_rails_dependencies(rails_version: nil)
      spec_compatible_with_rails?(specification: gem_specification, rails_version: rails_version)
    end

    def find_latest_compatible(rails_version: nil)
      dependency = Gem::Dependency.new(@name)
      fetcher = Gem::SpecFetcher.new

      # list all available data for released gems
      list, errors = fetcher.available_specs(:released)

      specs = []
      # filter only specs for the current gem and older versions
      list.each do |source, gem_tuples|
        gem_tuples.each do |gem_tuple|
          if gem_tuple.name == @name && gem_tuple.version > @version
            specs << source.fetch_spec(gem_tuple)
          end
        end
      end

      # if nothing is found, consider gem incompatible
      if specs.empty?
        @latest_compatible_version = NullGemInfo.new
        return
      end

      # if specs are found, look for the first one from that is compatible
      # with the desired rails version starting from the end
      specs.reverse.each do |spec|
        if spec_compatible_with_rails?(specification: spec, rails_version: rails_version).empty?
          @latest_compatible_version = spec
          break
        end
      end
    end

    def spec_compatible_with_rails?(specification: nil, rails_version: nil)
      rails_dependencies = specification.runtime_dependencies.select {|dependency| RAILS_GEMS.include?(dependency.name) }

      rails_dependencies.reject do |rails_dependency|
        rails_dependency.requirement.satisfied_by?(Gem::Version.new(rails_version))
      end
    end
  end
end
