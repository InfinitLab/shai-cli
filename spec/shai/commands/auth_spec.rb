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
