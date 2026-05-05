# frozen_string_literal: true

require "next_rails/tint"
require "spec_helper"

RSpec.describe NextRails::Tint do
  it "returns the plain string when no styles are applied" do
    expect(NextRails::Tint["hello"].to_s).to eq("hello")
  end

  it "wraps the string with a single ANSI code" do
    expect(NextRails::Tint["hello"].red.to_s).to eq("\e[31mhello\e[0m")
  end

  it "chains multiple styles into one escape sequence" do
    expect(NextRails::Tint["hello"].bold.white.to_s).to eq("\e[1;37mhello\e[0m")
  end

  it "interpolates cleanly into another string" do
    expect("hi #{NextRails::Tint['there'].green}!").to eq("hi \e[32mthere\e[0m!")
  end

  it "joins with other Tints via Array#join through to_str coercion" do
    joined = [NextRails::Tint["a"].red, NextRails::Tint["b"].green].join
    expect(joined).to eq("\e[31ma\e[0m\e[32mb\e[0m")
  end
end
