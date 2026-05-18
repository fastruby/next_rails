class DeprecationTracker
  VALID_MODES = %i[save compare].freeze
  VALID_MODES_DISPLAY = VALID_MODES.map(&:to_s).join(", ").freeze
end
