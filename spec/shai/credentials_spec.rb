# frozen_string_literal: true

RSpec.describe Shai::Credentials do
  let(:credentials) { described_class.new }

  describe "#authenticated?" do
    context "when no credentials are stored" do
      it "returns false" do
        expect(credentials.authenticated?).to be false
      end
    end

    context "when valid credentials are stored" do
      before do
        credentials.save(
          token: "test-token",
          expires_at: (Time.now + 3600).iso8601,
          user: {"username" => "testuser", "display_name" => "Test User"}
        )
      end

      it "returns true" do
        expect(credentials.authenticated?).to be true
      end
    end

    context "when credentials are expired" do
      before do
        credentials.save(
          token: "test-token",
          expires_at: (Time.now - 3600).iso8601,
          user: {"username" => "testuser", "display_name" => "Test User"}
        )
      end

      it "returns false" do
        expect(credentials.authenticated?).to be false
      end
    end
  end

  describe "#save" do
    it "stores credentials to file" do
      credentials.save(
        token: "test-token",
        expires_at: "2026-01-01T00:00:00Z",
        user: {"username" => "testuser"}
      )

      expect(File.exist?(Shai.configuration.credentials_path)).to be true
    end

    it "sets file permissions to 600" do
      credentials.save(
        token: "test-token",
        expires_at: "2026-01-01T00:00:00Z",
        user: {"username" => "testuser"}
      )

      mode = File.stat(Shai.configuration.credentials_path).mode & 0o777
      expect(mode).to eq(0o600)
    end
  end

  describe "#clear" do
    before do
      credentials.save(
        token: "test-token",
        expires_at: "2026-01-01T00:00:00Z",
        user: {"username" => "testuser"}
      )
    end

    it "removes credentials file" do
      credentials.clear

      expect(File.exist?(Shai.configuration.credentials_path)).to be false
    end

    it "clears in-memory credentials" do
      credentials.clear

      expect(credentials.token).to be_nil
      expect(credentials.user).to be_nil
    end
  end

  describe "#username" do
    context "when authenticated" do
      before do
        credentials.save(
          token: "test-token",
          expires_at: "2026-01-01T00:00:00Z",
          user: {"username" => "testuser", "display_name" => "Test User"}
        )
      end

      it "returns the username" do
        expect(credentials.username).to eq("testuser")
      end
    end

    context "when not authenticated" do
      it "returns nil" do
        expect(credentials.username).to be_nil
      end
    end
  end
end
