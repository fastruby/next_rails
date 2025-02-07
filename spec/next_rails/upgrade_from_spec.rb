require "spec_helper"
require "next_rails/upgrade_from"

RSpec.describe NextRails::UpgradeFrom do
  let(:current_version) { "6.0.0" }
  let(:mock_url) { "https://wwww.example.com/api/v1/next_versions" }
  let(:response_body) do
    {
      "current_latest_patch" => "6.0.3.7",
      "next_rails" => "6.1.0",
      "required_ruby" => ["2.7.2"]
    }.to_json
  end

  before do
    stub_const("NextRails::UpgradeFrom::URL", mock_url)
    stub_request(:get, mock_url)
      .with(query: { current_rails_version: current_version })
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
  end

  describe ".current_version" do
    it "returns the next versions information" do
      result = described_class.current_version(current_version)
      expect(result).to include("The latest patch for Rails 6.0.0 is 6.0.3.7.")
      expect(result).to include("The next Rails target jump should be 6.1.0.")
      expect(result).to include("The recommended Ruby version for this jump is 2.7.2.")
    end
  end

  describe "#print_versions" do
    context "when there is no next Rails version" do
      let(:response_body) do
        {
          "current_latest_patch" => "6.0.3.7",
          "next_rails" => nil,
          "required_ruby" => []
        }.to_json
      end

      it "returns a message indicating the current Rails version is the latest" do
        result = described_class.new(current_version).print_versions
        expect(result).to eq("You are on the most current Rails version.")
      end
    end

    context "when there is a next Rails version" do
      it "returns the next versions information" do
        result = described_class.new(current_version).print_versions
        expect(result).to include("The latest patch for Rails 6.0.0 is 6.0.3.7.")
        expect(result).to include("The next Rails target jump should be 6.1.0.")
        expect(result).to include("The recommended Ruby version for this jump is 2.7.2.")
      end
    end

    context "when there is a detail message in the response" do
      let(:response_body) do
        { "detail" => "Some detail message" }.to_json
      end

      it "returns the detail message" do
        result = described_class.new(current_version).print_versions
        expect(result).to eq("Some detail message")
      end
    end
  end
end
