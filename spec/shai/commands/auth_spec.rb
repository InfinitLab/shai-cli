# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Auth commands" do
  let(:cli) { Shai::CLI.new }
  let(:ui) { instance_double(Shai::UI) }
  let(:api) { instance_double(Shai::ApiClient) }
  let(:credentials) { instance_double(Shai::Credentials) }

  before do
    allow(cli).to receive(:ui).and_return(ui)
    allow(cli).to receive(:api).and_return(api)
    allow(cli).to receive(:credentials).and_return(credentials)

    # Default UI mocks
    allow(ui).to receive(:info)
    allow(ui).to receive(:error)
    allow(ui).to receive(:success)
    allow(ui).to receive(:blank)
    allow(ui).to receive(:indent)
    allow(ui).to receive(:spinner).and_yield
  end

  describe "#login" do
    context "when credentials are valid" do
      let(:response) do
        {
          "data" => {
            "token" => "abc123",
            "expires_at" => "2025-12-31T23:59:59Z",
            "user" => {
              "username" => "testuser",
              "display_name" => "Test User"
            }
          }
        }
      end

      before do
        allow(ui).to receive(:ask).with("Email or username:").and_return("testuser")
        allow(ui).to receive(:mask).with("Password:").and_return("password123")
        allow(api).to receive(:login).with(identifier: "testuser", password: "password123").and_return(response)
        allow(credentials).to receive(:save)
      end

      it "saves credentials and displays success" do
        expect(credentials).to receive(:save).with(
          token: "abc123",
          expires_at: "2025-12-31T23:59:59Z",
          user: {"username" => "testuser", "display_name" => "Test User"}
        )
        expect(ui).to receive(:success).with(/Logged in as testuser/)
        cli.login
      end
    end

    context "when credentials are invalid" do
      before do
        allow(ui).to receive(:ask).with("Email or username:").and_return("baduser")
        allow(ui).to receive(:mask).with("Password:").and_return("wrongpass")
        allow(api).to receive(:login).and_raise(Shai::AuthenticationError, "Invalid")
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/Invalid credentials/)
        expect { cli.login }.to raise_error(SystemExit)
      end
    end

    context "when network error occurs" do
      before do
        allow(ui).to receive(:ask).with("Email or username:").and_return("testuser")
        allow(ui).to receive(:mask).with("Password:").and_return("password123")
        allow(api).to receive(:login).and_raise(Shai::NetworkError, "Connection failed")
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/Connection failed/)
        expect { cli.login }.to raise_error(SystemExit)
      end
    end
  end

  describe "#whoami" do
    context "when authenticated" do
      before do
        allow(credentials).to receive(:authenticated?).and_return(true)
        allow(credentials).to receive(:username).and_return("testuser")
        allow(credentials).to receive(:display_name).and_return("Test User")
        allow(credentials).to receive(:expires_at).and_return(nil)
      end

      it "displays user info" do
        expect(ui).to receive(:info).with(/Logged in as testuser/)
        cli.whoami
      end
    end

    context "when authenticated with expiration date" do
      before do
        allow(credentials).to receive(:authenticated?).and_return(true)
        allow(credentials).to receive(:username).and_return("testuser")
        allow(credentials).to receive(:display_name).and_return(nil)
        allow(credentials).to receive(:expires_at).and_return("2025-12-31T23:59:59Z")
      end

      it "displays user info with expiration" do
        expect(ui).to receive(:info).with(/Logged in as testuser/)
        expect(ui).to receive(:info).with(/Token expires:/)
        cli.whoami
      end
    end

    context "when not authenticated" do
      before do
        allow(credentials).to receive(:authenticated?).and_return(false)
      end

      it "displays info message about logging in" do
        expect(ui).to receive(:info).with(/Not logged in/)
        cli.whoami
      end
    end
  end

  describe "#logout" do
    before do
      allow(credentials).to receive(:clear)
    end

    it "clears credentials and displays success" do
      expect(credentials).to receive(:clear)
      expect(ui).to receive(:success).with(/Logged out/)
      cli.logout
    end
  end
end
