class DeprecationTracker
  VALID_MODES = %i[save compare].freeze

  # Human-readable list of valid modes for error messages and CLI help text.
  def self.valid_modes_display
    @valid_modes_display ||= VALID_MODES.map(&:to_s).join(", ")
  end

  def self.valid_mode?(mode)
    mode && VALID_MODES.include?(mode.to_sym)
  end

  # Returns the mode as-is, or nil when it is blank. A blank DEPRECATION_TRACKER
  # (e.g. `DEPRECATION_TRACKER= rspec`) is truthy in Ruby, so callers can use this
  # to treat an empty value as unset and fall back to the default mode.
  def self.sanitize_mode(mode)
    return if mode.nil?

    stripped = mode.to_s.strip
    stripped.empty? ? nil : stripped
  end
end
