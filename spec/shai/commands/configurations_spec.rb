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
    allow(ui).to receive(:dim) { |t| t }
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

  describe "#install" do
    let(:tree) do
      [
        {"kind" => "folder", "path" => ".claude"},
        {"kind" => "file", "path" => ".claude/settings.json", "content" => "{}"}
      ]
    end
    let(:installed_projects) { instance_double(Shai::InstalledProjects) }

    before do
      allow(Shai::InstalledProjects).to receive(:new).and_return(installed_projects)
      allow(installed_projects).to receive(:has_project?).and_return(false)
      allow(installed_projects).to receive(:find_conflicts).and_return({})
      allow(installed_projects).to receive(:add_project)
      allow(installed_projects).to receive(:project_count).and_return(1)
    end

    context "with dry-run option" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: true, force: false, path: "."})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
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

    context "when same project is already installed" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "."})
        allow(installed_projects).to receive(:has_project?).with("my-config").and_return(true)
      end

      it "displays error and suggests uninstall or force" do
        expect(ui).to receive(:error).with(/'my-config' is already installed/)
        expect(ui).to receive(:info).with(/--force to reinstall/)
        expect { cli.install("my-config") }.to raise_error(SystemExit)
      end
    end

    context "when .shairc already exists" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "/tmp/test"})
        allow(File).to receive(:exist?).with("/tmp/test/.shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with("/tmp/test/.shairc").and_return({"slug" => "authored-config"})
      end

      it "displays error about authored configuration" do
        expect(ui).to receive(:error).with(/authored configuration/)
        expect { cli.install("my-config") }.to raise_error(SystemExit)
      end
    end

    context "when force option is used" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: true, path: "/tmp/test"})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => tree})
        allow(File).to receive(:exist?).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
      end

      it "proceeds with installation" do
        expect(ui).to receive(:success).with(/Installed/)
        cli.install("my-config")
      end
    end

    context "with owner/slug format" do
      before do
        allow(api).to receive(:get_tree).with("anthropic/my-config").and_return({"tree" => tree})
        allow(cli).to receive(:options).and_return({dry_run: true, force: false, path: "."})
      end

      it "passes full owner/slug to API" do
        expect(api).to receive(:get_tree).with("anthropic/my-config")
        expect(ui).to receive(:header).with(/Would install/)
        cli.install("anthropic/my-config")
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

    context "with conflicts from another installed project" do
      let(:tree2) do
        [
          {"kind" => "folder", "path" => ".claude"},
          {"kind" => "file", "path" => ".claude/settings.json", "content" => "{\"new\": true}"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "/tmp/test"})
        allow(api).to receive(:get_tree).with("other-config").and_return({"tree" => tree2})
        allow(installed_projects).to receive(:find_conflicts).and_return({
          ".claude/settings.json" => "my-config"
        })
        allow(File).to receive(:exist?).and_return(true)
        allow(ui).to receive(:select).and_return(:no)
      end

      it "shows conflict warning with project name" do
        expect(ui).to receive(:warning).with(/conflict with already installed/)
        expect(ui).to receive(:indent).with(/\.claude\/settings\.json.*my-config/)
        cli.install("other-config")
      end
    end

    context "installing multiple projects without conflicts" do
      let(:tree2) do
        [
          {"kind" => "folder", "path" => ".cursor"},
          {"kind" => "file", "path" => ".cursor/rules.md", "content" => "# Rules"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false, path: "/tmp/test"})
        allow(api).to receive(:get_tree).with("cursor-config").and_return({"tree" => tree2})
        allow(installed_projects).to receive(:project_count).and_return(2)
        allow(File).to receive(:exist?).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
      end

      it "installs and shows count of installed projects" do
        expect(ui).to receive(:success).with(/Installed cursor-config/)
        expect(ui).to receive(:indent).with(/2 configurations now installed/)
        cli.install("cursor-config")
      end
    end
  end

  describe "#uninstall" do
    let(:installed_projects) { instance_double(Shai::InstalledProjects) }

    before do
      allow(Shai::InstalledProjects).to receive(:new).and_return(installed_projects)
    end

    context "with dry-run option" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: true, path: "/tmp"})
        allow(installed_projects).to receive(:files_for_project).with("my-config").and_return([".claude/settings.json"])
        allow(File).to receive(:exist?).and_return(true)
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
        allow(installed_projects).to receive(:files_for_project).with("my-config").and_return([".claude/settings.json"])
        allow(installed_projects).to receive(:has_project?).and_return(true)
        allow(installed_projects).to receive(:remove_project)
        allow(installed_projects).to receive(:empty?).and_return(true)
        allow(installed_projects).to receive(:delete!)
        allow(installed_projects).to receive(:project_count).and_return(0)
        allow(File).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:empty?).and_return(true)
        allow(File).to receive(:delete)
        allow(Dir).to receive(:rmdir)
        allow(ui).to receive(:yes?).and_return(true)
      end

      it "removes files and updates tracking" do
        expect(File).to receive(:delete).at_least(:once)
        expect(installed_projects).to receive(:remove_project).with("my-config")
        expect(ui).to receive(:success).with(/Uninstalled/)
        cli.uninstall("my-config")
      end
    end

    context "when user cancels removal" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "/tmp/test"})
        allow(installed_projects).to receive(:files_for_project).with("my-config").and_return([".claude/settings.json"])
        allow(File).to receive(:exist?).and_return(true)
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
        allow(installed_projects).to receive(:files_for_project).with("my-config").and_return([".claude/settings.json"])
        allow(installed_projects).to receive(:has_project?).and_return(false)
        allow(File).to receive(:exist?).and_return(false)
      end

      it "displays no files message" do
        expect(ui).to receive(:info).with(/No files/)
        cli.uninstall("my-config")
      end
    end

    context "when no configuration specified and none installed" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "."})
        allow(installed_projects).to receive(:empty?).and_return(true)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/No configurations installed/)
        expect { cli.uninstall }.to raise_error(SystemExit)
      end
    end

    context "when no configuration specified and one installed" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "/tmp/test"})
        allow(installed_projects).to receive(:empty?).and_return(false)
        allow(installed_projects).to receive(:project_count).and_return(1)
        allow(installed_projects).to receive(:project_slugs).and_return(["my-config"])
        allow(installed_projects).to receive(:files_for_project).with("my-config").and_return([".claude/settings.json"])
        allow(installed_projects).to receive(:has_project?).and_return(true)
        allow(installed_projects).to receive(:remove_project)
        allow(installed_projects).to receive(:delete!)
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:delete)
        allow(ui).to receive(:yes?).and_return(true)
      end

      it "auto-selects the only installed configuration" do
        expect(ui).to receive(:info).with(/Uninstalling my-config/)
        expect(ui).to receive(:success).with(/Uninstalled/)
        cli.uninstall
      end
    end

    context "when no configuration specified and multiple installed" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "/tmp/test"})
        allow(installed_projects).to receive(:empty?).and_return(false)
        allow(installed_projects).to receive(:project_count).and_return(2)
        allow(installed_projects).to receive(:project_slugs).and_return(["config-1", "config-2"])
        allow(ui).to receive(:select).and_return(nil) # User cancels
      end

      it "prompts user to select which to uninstall" do
        expect(ui).to receive(:info).with(/Multiple configurations/)
        expect(ui).to receive(:select).with(/Which configuration/, anything)
        expect(ui).to receive(:info).with(/cancelled/)
        cli.uninstall
      end
    end

    context "when configuration not found in tracking and remote" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, path: "."})
        allow(installed_projects).to receive(:files_for_project).with("nonexistent").and_return([])
        allow(api).to receive(:get_tree).with("nonexistent").and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.uninstall("nonexistent") }.to raise_error(SystemExit)
      end
    end
  end
end
