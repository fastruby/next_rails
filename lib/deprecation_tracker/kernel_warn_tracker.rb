class DeprecationTracker
  module KernelWarnTracker
    def warn(*messages, uplevel: nil, category: nil, **kwargs)
      KernelWarnTracker.callbacks.each do |callback|
        messages.each { |message| callback.call(message) }
      end

      ruby_version = Gem::Version.new(RUBY_VERSION.dup)

      if ruby_version >= Gem::Version.new("3.2.0")
        # Kernel#warn supports uplevel, category
        super(*messages, uplevel: uplevel, category: category)
      elsif ruby_version >= Gem::Version.new("2.5.0")
        # Kernel#warn supports only uplevel
        super(*messages, uplevel: uplevel)
      else
        # No keyword args supported
        super(*messages)
      end
    end
  end
end
