# frozen_string_literal: true

module NextRails
  # Lightweight ANSI color/style wrapper with chainable style methods.
  # Wrap a string with `NextRails::Tint["text"]` then chain styles:
  #
  #   NextRails::Tint["hello"].red.bold
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

    def self.[](string)
      new(string)
    end

    def initialize(string)
      @string = string.to_s
      @codes = []
    end

    CODES.each_key do |style|
      define_method(style) do
        @codes << CODES[style]
        self
      end
    end

    def to_s
      return @string if @codes.empty?
      "\e[#{@codes.join(";")}m#{@string}\e[0m"
    end
    alias_method :to_str, :to_s
  end
end
