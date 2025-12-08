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

    context "when .shai-installed already exists" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "/tmp/test"})
        allow(File).to receive(:expand_path).with("/tmp/test").and_return("/tmp/test")
        allow(File).to receive(:exist?).with("/tmp/test/.shai-installed").and_return(true)
        allow(File).to receive(:exist?).with("/tmp/test/.shairc").and_return(false)
        allow(YAML).to receive(:safe_load_file).with("/tmp/test/.shai-installed").and_return({"slug" => "existing-config"})
      end

      it "displays error and suggests uninstall" do
        expect(ui).to receive(:error).with(/already present/)
        expect(ui).to receive(:indent).with(/shai uninstall existing-config/)
        expect { cli.install("my-config") }.to raise_error(SystemExit)
      end
    end

    context "when .shairc already exists" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "/tmp/test"})
        allow(File).to receive(:expand_path).with("/tmp/test").and_return("/tmp/test")
        allow(File).to receive(:exist?).with("/tmp/test/.shai-installed").and_return(false)
        allow(File).to receive(:exist?).with("/tmp/test/.shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with("/tmp/test/.shairc").and_return({"slug" => "authored-config"})
      end

      it "displays error and suggests uninstall" do
        expect(ui).to receive(:error).with(/already present/)
        expect(ui).to receive(:indent).with(/shai uninstall authored-config/)
        expect { cli.install("my-config") }.to raise_error(SystemExit)
      end
    end

    context "when existing config but force option is used" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: true, path: "/tmp/test"})
        allow(File).to receive(:expand_path).with("/tmp/test").and_return("/tmp/test")
        allow(File).to receive(:exist?).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
      end

      it "proceeds with installation" do
        expect(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
        expect(ui).to receive(:success).with(/Installed/)
        cli.install("my-config")
      end
    end
  end

  describe "#search" do
    context "with tag filtering" do
      let(:configs) do
        [{"name" => "Tagged Config", "slug" => "tagged-config"}]
      end

      before do
        allow(cli).to receive(:options).and_return({tag: ["claude"]})
        allow(api).to receive(:search_configurations).with(query: nil, tags: ["claude"]).and_return(configs)
      end

      it "searches by tags" do
        expect(ui).to receive(:header).with(/Search results/)
        cli.search
      end
    end

    context "when network error occurs" do
      before do
        allow(api).to receive(:search_configurations).and_raise(Shai::NetworkError, "Connection failed")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/Connection failed/)
        expect { cli.search("query") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#list" do
    context "when network error occurs" do
      before do
        allow(api).to receive(:list_configurations).and_raise(Shai::NetworkError, "Connection failed")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/Connection failed/)
        expect { cli.list }.to raise_error(SystemExit)
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

    context "with force option and existing files" do
      before do
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
        allow(cli).to receive(:options).and_return({dry_run: false, force: true, path: "/tmp/test"})
        allow(File).to receive(:exist?).and_return(true)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
      end

      it "overwrites files without prompting" do
        expect(ui).not_to receive(:select)
        expect(FileUtils).to receive(:mkdir_p).at_least(:once)
        expect(ui).to receive(:success).with(/Installed/)
        cli.install("my-config")
      end
    end

    context "with permission denied" do
      before do
        allow(api).to receive(:get_tree).with("private-config").and_raise(Shai::PermissionDeniedError, "Access denied")
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "."})
      end

      it "displays permission error" do
        expect(ui).to receive(:error).with(/permission/)
        expect { cli.install("private-config") }.to raise_error(SystemExit)
      end
    end

    context "with owner/slug format" do
      before do
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
        allow(cli).to receive(:options).and_return({dry_run: true, force: false, path: "."})
      end

      it "parses owner/slug format" do
        expect(ui).to receive(:header).with(/Would install/)
        cli.install("anthropic/my-config")
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

    context "when user confirms removal" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "/tmp/test"})
        allow(File).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:empty?).and_return(true)
        allow(File).to receive(:delete)
        allow(Dir).to receive(:rmdir)
        allow(ui).to receive(:yes?).and_return(true)
      end

      it "removes files and folders" do
        expect(File).to receive(:delete).at_least(:once)
        expect(ui).to receive(:success).with(/Uninstalled/)
        cli.uninstall("my-config")
      end
    end

    context "when user cancels removal" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "/tmp/test"})
        allow(File).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(ui).to receive(:yes?).and_return(false)
      end

      it "displays cancelled message" do
        expect(File).not_to receive(:delete)
        expect(ui).to receive(:info).with(/cancelled/)
        cli.uninstall("my-config")
      end
    end

    context "when no files found locally" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "/tmp/empty"})
        allow(File).to receive(:exist?).and_return(false)
        allow(Dir).to receive(:exist?).and_return(false)
      end

      it "displays no files message" do
        expect(ui).to receive(:info).with(/No files/)
        cli.uninstall("my-config")
      end
    end

    context "when configuration not found" do
      before do
        allow(api).to receive(:get_tree).with("nonexistent").and_raise(Shai::NotFoundError, "Not found")
        allow(cli).to receive(:options).and_return({dry_run: false, path: "."})
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.uninstall("nonexistent") }.to raise_error(SystemExit)
      end
    end
  end
end
