class DeprecationTracker
  VALID_MODES = %i[save compare].freeze

  # Human-readable list of valid modes for error messages and CLI help text.
  def self.valid_modes_display
    @valid_modes_display ||= VALID_MODES.map(&:to_s).join(", ")
  end

  def self.valid_mode?(mode)
    mode && VALID_MODES.include?(mode.to_sym)
  end
end
