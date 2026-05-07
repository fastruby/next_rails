# frozen_string_literal: true

module NextRails
  # Lightweight ANSI color/style wrapper with chainable style methods.
  # Wrap a string with `NextRails::Tint("text")` then chain styles:
  #
  #   NextRails::Tint("hello").red.bold
  #
  # Instances are effectively immutable: each style method returns a new
  # `Tint` rather than mutating the receiver, so a reference can be reused
  # without styles accumulating across chains.
  class Tint
    CODES = {
      bold: 1,
      italic: 3,
      red: 31,
      green: 32,
      yellow: 33,
      blue: 34,
      magenta: 35,
      cyan: 36,
      white: 37
    }.freeze

    def initialize(string, codes = [])
      @string = string.to_s
      @codes = codes
    end

    CODES.each_key do |style|
      define_method(style) do
        self.class.new(@string, @codes + [CODES[style]])
      end
    end

    def to_s
      return @string if @codes.empty?

      "\e[#{@codes.join(";")}m#{@string}\e[0m"
    end
    alias_method :to_str, :to_s
  end

  def self.Tint(string)
    Tint.new(string)
  end
end
