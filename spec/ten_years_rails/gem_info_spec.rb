require "spec_helper"
require "timecop"

RSpec.describe NextRails::GemInfo do
  let(:release_date) { Time.utc(2019, 7, 6, 0, 0, 0) }
  let(:now) { Time.utc(2019, 7, 6, 12, 0, 0) }
  let(:spec) do
    Gem::Specification.new do |s|
      s.date = release_date
    end
  end

  subject { NextRails::GemInfo.new(spec) }

  describe "#age" do
    around do |example|
      Timecop.travel(now) do
        example.run
      end
    end

    let(:result) { now.strftime("%b %e, %Y") }

    it "returns a date" do
      expect(subject.age).to eq(result)
    end
  end

  describe "#up_to_date?" do
    it "is up to date" do
      allow(Gem).to receive(:latest_spec_for).and_return(spec)
      expect(subject.up_to_date?).to be_truthy
    end
  end
end
