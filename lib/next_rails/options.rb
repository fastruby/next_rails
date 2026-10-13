module NextRails
  # Ruby 1.9 has no keyword arguments, so methods that would take them accept a
  # trailing options hash instead. This brings back the check Ruby does for
  # keywords: an unknown key raises instead of being silently ignored.
  module Options
    def self.check!(options, *allowed)
      unless options.is_a?(Hash)
        raise ArgumentError, "expected an options Hash, got #{options.inspect}"
      end

      unknown = options.keys - allowed
      unless unknown.empty?
        raise ArgumentError, "unknown keyword#{"s" if unknown.size > 1}: #{unknown.map(&:inspect).join(", ")}"
      end

      options
    end
  end
end
