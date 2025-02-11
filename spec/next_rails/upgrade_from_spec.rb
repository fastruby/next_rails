require "spec_helper"

RSpec.describe NextRails::UpgradeFrom do
  let(:current_version) { "6.0.0" }
  let(:response_body) do
    {
      current_latest_patch: "6.0.3.7",
      next_rails: "6.1.0",
      required_ruby: ["2.7.2"]
    }.to_json
  end

  describe ".report" do
    it "returns the next versions information" do
      response = JSON.parse(response_body)
      result = described_class.report(current_version, response)
      expect(result).to include("The latest patch for Rails 6.0.0 is 6.0.3.7.")
      expect(result).to include("The next Rails target upgrade should be 6.1.0.")
      expect(result).to include("The recommended Ruby version for the upgrade is 2.7.2.")
    end
  end

  describe "#print_versions" do
    context "when there is no next Rails version" do
      let(:response_body) do
        {
          current_latest_patch: "6.0.3.7",
          next_rails: nil,
          required_ruby: []
        }.to_json
      end

      it "returns a message indicating the current Rails version is the latest" do
        response = JSON.parse(response_body)
        result = described_class.new(current_version, response).print_versions
        expect(result).to include("You are on the most current Rails version.")
      end
    end

    context "when the current version is not the latest patch" do
      let(:current_version) { "6.0.0" }
      let(:response_body) do
        {
          current_latest_patch: "6.0.3.7",
          next_rails: "6.1.0",
          required_ruby: ["2.7.2"]
        }.to_json
      end

      it "suggests upgrading to the latest patch version first and then the next Rails version" do
        response = JSON.parse(response_body)
        result = described_class.new(current_version, response).print_versions
        expect(result).to include("The latest patch for Rails 6.0.0 is 6.0.3.7.")
        expect(result).to include("It is strongly recommended to upgrade to the latest patch before upgrading to the next Rails version.")
        expect(result).to include("The next Rails target upgrade should be 6.1.0.")
      end
    end

    context "when the current version is the latest patch" do
      let(:current_version) { "6.0.3.7" }
      let(:response_body) do
        {
          current_latest_patch: "6.0.3.7",
          next_rails: "6.1.0",
          required_ruby: ["2.7.2"]
        }.to_json
      end

      it "suggests upgrading to the next Rails version" do
        response = JSON.parse(response_body)
        result = described_class.new(current_version, response).print_versions
        expect(result).to include("Your application is running the latest patch version 6.0.3.7, which is great!")
        expect(result).to include("The next Rails target upgrade should be 6.1.0.")
      end
    end

    context "when there is a detail message in the response" do
      let(:response_body) do
        { detail: "Some detail message" }.to_json
      end

      it "returns the detail message" do
        response = JSON.parse(response_body)
        result = described_class.new(current_version, response).print_versions
        expect(result).to eq("Some detail message")
      end
    end
  end
end
