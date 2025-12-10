# frozen_string_literal: true

RSpec.describe Shai::Configuration do
  let(:config) { described_class.new }

  describe "#api_url" do
    it "defaults to https://shaicli.dev" do
      expect(config.api_url).to eq("https://shaicli.dev")
    end

    context "when SHAI_API_URL is set" do
      around do |example|
        original = ENV["SHAI_API_URL"]
        ENV["SHAI_API_URL"] = "https://staging.shaicli.dev"
        Shai.reset!
        example.run
        ENV["SHAI_API_URL"] = original
      end

      it "uses the environment variable" do
        expect(described_class.new.api_url).to eq("https://staging.shaicli.dev")
      end
    end

    context "HTTPS enforcement" do
      it "allows HTTPS URLs" do
        config.api_url = "https://api.example.com"
        expect(config.api_url).to eq("https://api.example.com")
      end

      it "allows HTTP for localhost" do
        config.api_url = "http://localhost:3000"
        expect(config.api_url).to eq("http://localhost:3000")
      end

      it "allows HTTP for 127.0.0.1" do
        config.api_url = "http://127.0.0.1:3000"
        expect(config.api_url).to eq("http://127.0.0.1:3000")
      end

      it "allows HTTP for ::1 (IPv6 localhost)" do
        config.api_url = "http://[::1]:3000"
        expect(config.api_url).to eq("http://[::1]:3000")
      end

      it "rejects HTTP for non-localhost URLs" do
        expect {
          config.api_url = "http://api.example.com"
        }.to raise_error(Shai::Configuration::InsecureConnectionError, /HTTPS is required/)
      end

      it "rejects HTTP for production-like domains" do
        expect {
          config.api_url = "http://shaicli.dev"
        }.to raise_error(Shai::Configuration::InsecureConnectionError)
      end
    end
  end

  describe "#config_dir" do
    context "on macOS/Linux" do
      it "defaults to ~/.config/shai" do
        expect(config.config_dir).to eq(File.join(Dir.home, ".config", "shai"))
      end
    end

    context "when SHAI_CONFIG_DIR is set" do
      around do |example|
        original = ENV["SHAI_CONFIG_DIR"]
        ENV["SHAI_CONFIG_DIR"] = "/custom/path"
        Shai.reset!
        example.run
        ENV["SHAI_CONFIG_DIR"] = original
      end

      it "uses the environment variable" do
        expect(described_class.new.config_dir).to eq("/custom/path")
      end
    end
  end

  describe "#credentials_path" do
    it "returns path to credentials file" do
      expect(config.credentials_path).to eq(
        File.join(config.config_dir, "credentials")
      )
    end
  end

  describe "#color_enabled?" do
    context "when NO_COLOR is not set" do
      it "returns true" do
        expect(config.color_enabled?).to be true
      end
    end

    context "when NO_COLOR is set" do
      around do |example|
        original = ENV["NO_COLOR"]
        ENV["NO_COLOR"] = "1"
        example.run
        ENV["NO_COLOR"] = original
      end

      it "returns false" do
        expect(described_class.new.color_enabled?).to be false
      end
    end
  end

  describe "#token" do
    context "when SHAI_TOKEN is set" do
      around do |example|
        original = ENV["SHAI_TOKEN"]
        ENV["SHAI_TOKEN"] = "env-token-123"
        Shai.reset!
        example.run
        ENV["SHAI_TOKEN"] = original
      end

      it "uses the environment variable" do
        expect(described_class.new.token).to eq("env-token-123")
      end
    end

    context "when SHAI_TOKEN is not set" do
      it "returns nil" do
        expect(config.token).to be_nil
      end
    end
  end
end
