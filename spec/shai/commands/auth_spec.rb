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
    allow(ui).to receive(:warning)
    allow(ui).to receive(:blank)
    allow(ui).to receive(:indent)
    allow(ui).to receive(:spinner).and_yield
    allow(ui).to receive(:cyan) { |t| t }
    allow(ui).to receive(:bold) { |t| t }
  end

  describe "#login with --password" do
    before do
      allow(cli).to receive(:options).and_return({password: true})
    end

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

  describe "#login with device flow (default)" do
    let(:spinner) { instance_double(TTY::Spinner) }

    before do
      allow(cli).to receive(:options).and_return({password: false})
      allow(TTY::Spinner).to receive(:new).and_return(spinner)
      allow(spinner).to receive(:auto_spin)
      allow(spinner).to receive(:success)
      allow(spinner).to receive(:error)
      # Stub sleep to make tests fast
      allow(cli).to receive(:sleep)
    end

    context "when authorization succeeds" do
      let(:device_response) do
        {
          "device_code" => "abc123devicecode",
          "user_code" => "ABCD-1234",
          "verification_uri" => "https://shaicli.dev/device",
          "verification_uri_complete" => "https://shaicli.dev/device?code=ABCD-1234",
          "expires_in" => 600,
          "interval" => 5
        }
      end

      let(:token_response) do
        {
          "data" => {
            "token" => "final_token_123",
            "expires_at" => "2025-12-31T23:59:59Z",
            "user" => {
              "username" => "testuser",
              "display_name" => "Test User"
            }
          }
        }
      end

      before do
        allow(api).to receive(:device_authorize).and_return(device_response)
        allow(ui).to receive(:yes?).and_return(false) # Don't open browser
        allow(credentials).to receive(:save)
      end

      it "displays device code instructions" do
        allow(api).to receive(:device_token).and_return(token_response)

        expect(ui).to receive(:info).with("Starting device authorization...")
        expect(ui).to receive(:info).with("To authorize this device:")
        expect(ui).to receive(:indent).with(/Visit:.*shaicli.dev\/device/)
        expect(ui).to receive(:indent).with(/Enter code:.*ABCD-1234/)

        cli.login
      end

      it "polls for token and saves credentials on approval" do
        allow(api).to receive(:device_token).and_return(token_response)

        expect(credentials).to receive(:save).with(
          token: "final_token_123",
          expires_at: "2025-12-31T23:59:59Z",
          user: {"username" => "testuser", "display_name" => "Test User"}
        )
        expect(ui).to receive(:success).with(/Logged in as testuser/)

        cli.login
      end

      it "handles authorization_pending by continuing to poll" do
        call_count = 0
        allow(api).to receive(:device_token) do
          call_count += 1
          if call_count < 3
            raise Shai::DeviceFlowError.new("authorization_pending")
          else
            token_response
          end
        end

        expect(credentials).to receive(:save)
        cli.login
      end

      it "handles slow_down by increasing interval" do
        call_count = 0
        allow(api).to receive(:device_token) do
          call_count += 1
          if call_count == 1
            raise Shai::DeviceFlowError.new("slow_down", interval: 10)
          else
            token_response
          end
        end

        expect(credentials).to receive(:save)
        cli.login
      end
    end

    context "when authorization is denied" do
      let(:device_response) do
        {
          "device_code" => "abc123devicecode",
          "user_code" => "ABCD-1234",
          "verification_uri" => "https://shaicli.dev/device",
          "interval" => 5
        }
      end

      before do
        allow(api).to receive(:device_authorize).and_return(device_response)
        allow(ui).to receive(:yes?).and_return(false)
        allow(api).to receive(:device_token).and_raise(Shai::DeviceFlowError.new("access_denied"))
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/Authorization denied/)
        expect { cli.login }.to raise_error(SystemExit)
      end
    end

    context "when device code expires" do
      let(:device_response) do
        {
          "device_code" => "abc123devicecode",
          "user_code" => "ABCD-1234",
          "verification_uri" => "https://shaicli.dev/device",
          "interval" => 5
        }
      end

      before do
        allow(api).to receive(:device_authorize).and_return(device_response)
        allow(ui).to receive(:yes?).and_return(false)
        allow(api).to receive(:device_token).and_raise(Shai::DeviceFlowError.new("expired_token"))
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/expired/)
        expect { cli.login }.to raise_error(SystemExit)
      end
    end

    context "when network error occurs during authorization" do
      before do
        allow(api).to receive(:device_authorize).and_raise(Shai::NetworkError, "Connection failed")
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/Connection failed/)
        expect { cli.login }.to raise_error(SystemExit)
      end
    end
  end

  describe "#whoami" do
    before do
      allow(cli).to receive(:options).and_return({})
    end

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
      allow(cli).to receive(:options).and_return({})
      allow(credentials).to receive(:clear)
    end

    it "clears credentials and displays success" do
      expect(credentials).to receive(:clear)
      expect(ui).to receive(:success).with(/Logged out/)
      cli.logout
    end
  end
end
