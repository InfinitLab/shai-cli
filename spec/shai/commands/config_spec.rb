# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Config commands" do
  let(:cli) { Shai::CLI.new }
  let(:ui) { instance_double(Shai::UI) }
  let(:api) { instance_double(Shai::ApiClient) }
  let(:credentials) { instance_double(Shai::Credentials) }

  before do
    allow(cli).to receive(:ui).and_return(ui)
    allow(cli).to receive(:api).and_return(api)
    allow(cli).to receive(:credentials).and_return(credentials)
    allow(credentials).to receive(:authenticated?).and_return(true)
    allow(credentials).to receive(:username).and_return("testuser")

    # Default UI mocks
    allow(ui).to receive(:info)
    allow(ui).to receive(:error)
    allow(ui).to receive(:success)
    allow(ui).to receive(:warning)
    allow(ui).to receive(:blank)
    allow(ui).to receive(:spinner).and_yield
    allow(ui).to receive(:yes?).and_return(true)
  end

  describe "#config" do
    context "with no subcommand" do
      it "displays error message" do
        expect(ui).to receive(:error).with(/Missing subcommand/)
        expect { cli.config }.to raise_error(SystemExit)
      end
    end

    context "with unknown subcommand" do
      it "displays error message" do
        expect(ui).to receive(:error).with(/Unknown subcommand/)
        expect { cli.config("unknown") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#config show" do
    let(:config_response) do
      {
        "slug" => "my-config",
        "name" => "My Config",
        "description" => "A test configuration",
        "visibility" => "private",
        "stars_count" => 5,
        "created_at" => "2025-01-01T00:00:00Z",
        "updated_at" => "2025-01-02T00:00:00Z"
      }
    end

    before do
      allow(File).to receive(:exist?).with(".shairc").and_return(true)
      allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config"})
    end

    context "when configuration exists" do
      before do
        allow(api).to receive(:get_configuration).with("my-config").and_return(config_response)
      end

      it "displays configuration details" do
        expect(ui).to receive(:info).with(/Configuration: my-config/)
        expect(ui).to receive(:info).with(/Name: My Config/)
        expect(ui).to receive(:info).with(/Description: A test configuration/)
        expect(ui).to receive(:info).with(/Visibility: private/)
        expect(ui).to receive(:info).with(/Stars: 5/)
        cli.config("show")
      end
    end

    context "when configuration not found" do
      before do
        allow(api).to receive(:get_configuration).and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.config("show") }.to raise_error(SystemExit)
      end
    end

    context "when no .shairc file exists" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/No .shairc file found/)
        expect { cli.config("show") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#config set" do
    before do
      allow(File).to receive(:exist?).with(".shairc").and_return(true)
      allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config"})
    end

    context "with valid key and value" do
      before do
        allow(api).to receive(:update_configuration).with("my-config", name: "New Name").and_return({})
      end

      it "updates the configuration" do
        expect(api).to receive(:update_configuration).with("my-config", name: "New Name")
        expect(ui).to receive(:success).with(/Updated name/)
        cli.config("set", "name", "New Name")
      end
    end

    context "with visibility set to public" do
      before do
        allow(api).to receive(:update_configuration).with("my-config", visibility: "public").and_return({})
      end

      it "updates visibility" do
        expect(ui).to receive(:success).with(/Updated visibility/)
        cli.config("set", "visibility", "public")
      end
    end

    context "with invalid visibility value" do
      it "displays error message" do
        expect(ui).to receive(:error).with(/must be 'public' or 'private'/)
        expect { cli.config("set", "visibility", "invalid") }.to raise_error(SystemExit)
      end
    end

    context "with invalid key" do
      it "displays error message" do
        expect(ui).to receive(:error).with(/Invalid key/)
        expect { cli.config("set", "invalid_key", "value") }.to raise_error(SystemExit)
      end
    end

    context "with missing arguments" do
      it "displays usage message" do
        expect(ui).to receive(:error).with(/Usage:/)
        expect { cli.config("set", "name") }.to raise_error(SystemExit)
      end
    end

    context "when update fails with not found" do
      before do
        allow(api).to receive(:update_configuration).and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.config("set", "name", "New Name") }.to raise_error(SystemExit)
      end
    end

    context "when update fails with permission denied" do
      before do
        allow(api).to receive(:update_configuration).and_raise(Shai::PermissionDeniedError, "Denied")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/permission/)
        expect { cli.config("set", "name", "New Name") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#delete" do
    context "when user confirms deletion" do
      before do
        allow(api).to receive(:delete_configuration).with("my-config").and_return({})
      end

      it "deletes the configuration" do
        expect(api).to receive(:delete_configuration).with("my-config")
        expect(ui).to receive(:success).with(/deleted/)
        cli.delete("my-config")
      end
    end

    context "when user cancels deletion" do
      before do
        allow(ui).to receive(:yes?).and_return(false)
      end

      it "displays cancelled message" do
        expect(api).not_to receive(:delete_configuration)
        expect(ui).to receive(:info).with(/Cancelled/)
        cli.delete("my-config")
      end
    end

    context "when configuration not found" do
      before do
        allow(api).to receive(:delete_configuration).and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.delete("nonexistent") }.to raise_error(SystemExit)
      end
    end

    context "when permission denied" do
      before do
        allow(api).to receive(:delete_configuration).and_raise(Shai::PermissionDeniedError, "Denied")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/permission/)
        expect { cli.delete("other-config") }.to raise_error(SystemExit)
      end
    end

    context "when network error occurs" do
      before do
        allow(api).to receive(:delete_configuration).and_raise(Shai::NetworkError, "Connection failed")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/Connection failed/)
        expect { cli.delete("my-config") }.to raise_error(SystemExit)
      end
    end
  end
end
