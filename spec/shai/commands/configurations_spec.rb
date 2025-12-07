# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Configurations commands" do
  let(:cli) { Shai::CLI.new }
  let(:ui) { instance_double(Shai::UI) }
  let(:api) { instance_double(Shai::ApiClient) }
  let(:credentials) { instance_double(Shai::Credentials) }

  before do
    allow(cli).to receive(:ui).and_return(ui)
    allow(cli).to receive(:api).and_return(api)
    allow(cli).to receive(:credentials).and_return(credentials)
    allow(credentials).to receive(:authenticated?).and_return(true)

    # Default UI mocks
    allow(ui).to receive(:info)
    allow(ui).to receive(:error)
    allow(ui).to receive(:success)
    allow(ui).to receive(:warning)
    allow(ui).to receive(:blank)
    allow(ui).to receive(:indent)
    allow(ui).to receive(:header)
    allow(ui).to receive(:display_configuration)
    allow(ui).to receive(:display_file_operation)
    allow(ui).to receive(:spinner).and_yield
    allow(ui).to receive(:select)
    allow(ui).to receive(:yes?)
  end

  describe "#list" do
    context "when user has configurations" do
      let(:configs) do
        [
          {"name" => "Config 1", "slug" => "config-1", "updated_at" => Time.now.iso8601},
          {"name" => "Config 2", "slug" => "config-2", "updated_at" => Time.now.iso8601}
        ]
      end

      before do
        allow(api).to receive(:list_configurations).and_return(configs)
      end

      it "displays configurations" do
        expect(ui).to receive(:header).with(/Your configurations/)
        expect(ui).to receive(:display_configuration).twice
        cli.list
      end
    end

    context "when user has no configurations" do
      before do
        allow(api).to receive(:list_configurations).and_return([])
      end

      it "displays helpful message" do
        expect(ui).to receive(:info).with(/don't have any configurations/)
        cli.list
      end
    end
  end

  describe "#search" do
    context "with matching results" do
      let(:configs) do
        [
          {"name" => "Claude Expert", "slug" => "claude-expert", "description" => "Expert config"}
        ]
      end

      before do
        allow(api).to receive(:search_configurations).with(query: "claude", tags: []).and_return(configs)
      end

      it "displays search results" do
        expect(ui).to receive(:header).with(/Search results/)
        expect(ui).to receive(:display_configuration)
        cli.search("claude")
      end
    end

    context "with no results" do
      before do
        allow(api).to receive(:search_configurations).with(query: "nonexistent", tags: []).and_return([])
      end

      it "displays no results message" do
        expect(ui).to receive(:info).with(/No configurations found/)
        cli.search("nonexistent")
      end
    end

    context "with no query or tags" do
      it "displays error" do
        expect(ui).to receive(:error).with(/Please provide/)
        expect { cli.search }.to raise_error(SystemExit)
      end
    end
  end

  describe "#install" do
    let(:tree) do
      [
        {"kind" => "folder", "path" => ".claude"},
        {"kind" => "file", "path" => ".claude/settings.json", "content" => "{}"}
      ]
    end

    before do
      allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
    end

    context "with dry-run option" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: true, force: false, path: "."})
      end

      it "shows what would be installed without making changes" do
        expect(ui).to receive(:header).with(/Would install/)
        expect(ui).to receive(:display_file_operation).with(:would_create, ".claude")
        expect(ui).to receive(:display_file_operation).with(:would_create, ".claude/settings.json")
        expect(ui).to receive(:info).with(/No changes made/)
        cli.install("my-config")
      end
    end

    context "when configuration not found" do
      before do
        allow(api).to receive(:get_tree).with("nonexistent").and_raise(Shai::NotFoundError, "Not found")
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "."})
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.install("nonexistent") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#uninstall" do
    let(:tree) do
      [
        {"kind" => "folder", "path" => ".claude"},
        {"kind" => "file", "path" => ".claude/settings.json", "content" => "{}"}
      ]
    end

    before do
      allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
    end

    context "with dry-run option" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: true, path: "/tmp"})
        allow(File).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:exist?).and_return(true)
      end

      it "shows what would be removed without making changes" do
        expect(ui).to receive(:header).with(/Would remove/)
        expect(ui).to receive(:info).with(/No changes made/)
        cli.uninstall("my-config")
      end
    end
  end
end
