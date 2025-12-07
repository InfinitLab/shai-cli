# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Sync commands" do
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
    allow(ui).to receive(:indent)
    allow(ui).to receive(:header)
    allow(ui).to receive(:display_file_operation)
    allow(ui).to receive(:diff)
    allow(ui).to receive(:spinner).and_yield
    allow(ui).to receive(:ask)
    allow(ui).to receive(:select)
  end

  describe "#status" do
    context "when no .shairc file exists" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/No .shairc file found/)
        expect { cli.status }.to raise_error(SystemExit)
      end
    end

    context "when up to date" do
      let(:shairc_content) { "slug: my-config\ninclude:\n  - .claude/**\n" }
      let(:remote_tree) do
        [
          {"kind" => "folder", "path" => ".claude"},
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Config"}
        ]
      end

      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Config")
        allow(File).to receive(:dirname).and_call_original
      end

      it "displays up to date message" do
        expect(ui).to receive(:info).with(/Up to date/)
        cli.status
      end
    end
  end

  describe "#push" do
    context "when no .shairc file exists" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/No .shairc file found/)
        expect { cli.push }.to raise_error(SystemExit)
      end
    end

    context "with dry-run option" do
      let(:shairc_content) { "slug: my-config\ninclude:\n  - .claude/**\n" }

      before do
        allow(cli).to receive(:options).and_return({dry_run: true, message: nil})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Config")
        allow(File).to receive(:dirname).and_call_original
      end

      it "shows what would be pushed without making changes" do
        expect(ui).to receive(:header).with(/Would push/)
        expect(ui).to receive(:info).with(/No changes made/)
        cli.push
      end
    end
  end

  describe "#diff" do
    context "when no .shairc file exists" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/No .shairc file found/)
        expect { cli.diff }.to raise_error(SystemExit)
      end
    end

    context "when no differences" do
      let(:remote_tree) do
        [
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Config"}
        ]
      end

      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Config")
        allow(File).to receive(:dirname).and_call_original
      end

      it "displays no differences message" do
        expect(ui).to receive(:info).with(/No differences found/)
        cli.diff
      end
    end
  end

  describe "#init" do
    context "when .shairc already exists" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/already exists/)
        expect { cli.init }.to raise_error(SystemExit)
      end
    end

    context "when creating new configuration" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
        allow(ui).to receive(:ask).with("Configuration name:").and_return("My Config")
        allow(ui).to receive(:ask).with(/Description/).and_return("A description")
        allow(ui).to receive(:select).and_return("private")
        allow(ui).to receive(:ask).with("Include paths (glob patterns, comma-separated):", default: ".claude/**,.cursor/**").and_return(".claude/**,.cursor/**")
        allow(File).to receive(:write)
        allow(api).to receive(:create_configuration).and_return({
          "configuration" => {"slug" => "my-config"}
        })
      end

      it "creates configuration and writes .shairc file" do
        expect(api).to receive(:create_configuration).with(
          name: "My Config",
          description: "A description",
          visibility: "private"
        )
        expect(File).to receive(:write).with(".shairc", anything)
        expect(ui).to receive(:success).with(/Created my-config/)
        cli.init
      end
    end

    context "when API returns validation error" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
        allow(ui).to receive(:ask).and_return("", "desc")
        allow(ui).to receive(:select).and_return("private")
        allow(api).to receive(:create_configuration).and_raise(Shai::InvalidConfigurationError, "Name can't be blank")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/Name can't be blank/)
        expect { cli.init }.to raise_error(SystemExit)
      end
    end
  end

  describe "#status" do
    context "when there are local changes" do
      let(:remote_tree) do
        [
          {"kind" => "file", "path" => ".claude/old.md", "content" => "# Old"}
        ]
      end

      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/new.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/new.md").and_return("# New")
        allow(File).to receive(:dirname).and_call_original
      end

      it "displays local changes" do
        expect(ui).to receive(:info).with(/Local changes/)
        cli.status
      end
    end

    context "when configuration not found on remote" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "nonexistent"})
        allow(api).to receive(:get_tree).and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.status }.to raise_error(SystemExit)
      end
    end
  end

  describe "#push" do
    context "when no files match include patterns" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, message: nil})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".nonexistent/**"]})
        allow(Dir).to receive(:glob).and_return([])
      end

      it "displays warning about no files" do
        expect(ui).to receive(:warning).with(/No files found/)
        expect { cli.push }.to raise_error(SystemExit)
      end
    end

    context "when push succeeds" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, message: nil})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Config")
        allow(File).to receive(:dirname).and_call_original
        allow(api).to receive(:update_tree).and_return({"message" => "success"})
      end

      it "uploads tree and displays success" do
        expect(api).to receive(:update_tree).with("my-config", anything)
        expect(ui).to receive(:success).with(/Pushed/)
        cli.push
      end
    end

    context "when push fails with not found" do
      before do
        allow(cli).to receive(:options).and_return({dry_run: false, message: nil})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "nonexistent", "include" => [".claude/**"]})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).and_return("# Config")
        allow(File).to receive(:dirname).and_call_original
        allow(api).to receive(:update_tree).and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.push }.to raise_error(SystemExit)
      end
    end
  end

  describe "#diff" do
    context "when there are modified files" do
      let(:remote_tree) do
        [
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Old Content"}
        ]
      end

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# New Content")
        allow(File).to receive(:dirname).and_call_original
      end

      it "displays diff for modified files" do
        expect(ui).to receive(:info).with(/--- remote/)
        expect(ui).to receive(:info).with(/\+\+\+ local/)
        expect(ui).to receive(:diff)
        cli.diff
      end
    end

    context "when there are new files" do
      let(:remote_tree) { [] }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/new.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/new.md").and_return("# New File")
        allow(File).to receive(:dirname).and_call_original
      end

      it "displays diff for new files" do
        expect(ui).to receive(:info).with(/--- \/dev\/null/)
        expect(ui).to receive(:info).with(/\+\+\+ local/)
        expect(ui).to receive(:diff)
        cli.diff
      end
    end
  end

  describe "#pull" do
    context "when no .shairc file exists" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(false)
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/No .shairc file found/)
        expect { cli.pull }.to raise_error(SystemExit)
      end
    end

    context "when already up to date" do
      let(:remote_tree) do
        [
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Config"}
        ]
      end

      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Config")
        allow(File).to receive(:dirname).and_call_original
      end

      it "displays up to date message" do
        expect(ui).to receive(:info).with(/Already up to date/)
        cli.pull
      end
    end

    context "with dry-run option and remote changes" do
      let(:remote_tree) do
        [
          {"kind" => "folder", "path" => ".claude"},
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Updated Content"},
          {"kind" => "file", "path" => ".claude/new.md", "content" => "# New File"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: true, force: false})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Old Content")
        allow(File).to receive(:dirname).and_call_original
      end

      it "shows what would be pulled without making changes" do
        expect(ui).to receive(:header).with(/Would pull/)
        expect(ui).to receive(:display_file_operation).with(:would_create, ".claude/new.md")
        expect(ui).to receive(:display_file_operation).with(:would_update, ".claude/config.md")
        expect(ui).to receive(:info).with(/No changes made/)
        cli.pull
      end
    end

    context "when user confirms update" do
      let(:remote_tree) do
        [
          {"kind" => "folder", "path" => ".claude"},
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Updated Content"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(Dir).to receive(:exist?).and_return(true)
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Old Content")
        allow(File).to receive(:dirname).and_call_original
        allow(File).to receive(:write)
        allow(ui).to receive(:yes?).and_return(true)
      end

      it "updates local files" do
        expect(File).to receive(:write).with(".claude/config.md", "# Updated Content")
        expect(ui).to receive(:success).with(/Pulled/)
        cli.pull
      end
    end

    context "when user cancels update" do
      let(:remote_tree) do
        [
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Updated Content"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Old Content")
        allow(File).to receive(:dirname).and_call_original
        allow(ui).to receive(:yes?).and_return(false)
      end

      it "displays cancelled message" do
        expect(File).not_to receive(:write)
        expect(ui).to receive(:info).with(/cancelled/)
        cli.pull
      end
    end

    context "with force option" do
      let(:remote_tree) do
        [
          {"kind" => "folder", "path" => ".claude"},
          {"kind" => "file", "path" => ".claude/config.md", "content" => "# Updated Content"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: true})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([".claude/config.md"])
        allow(Dir).to receive(:exist?).and_return(true)
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:read).with(".claude/config.md").and_return("# Old Content")
        allow(File).to receive(:dirname).and_call_original
        allow(File).to receive(:write)
      end

      it "overwrites files without prompting" do
        expect(ui).not_to receive(:yes?)
        expect(File).to receive(:write).with(".claude/config.md", "# Updated Content")
        expect(ui).to receive(:success).with(/Pulled/)
        cli.pull
      end
    end

    context "when configuration not found" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "nonexistent"})
        allow(api).to receive(:get_tree).and_raise(Shai::NotFoundError, "Not found")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.pull }.to raise_error(SystemExit)
      end
    end

    context "when network error occurs" do
      before do
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config"})
        allow(api).to receive(:get_tree).and_raise(Shai::NetworkError, "Connection failed")
      end

      it "displays error message" do
        expect(ui).to receive(:error).with(/Connection failed/)
        expect { cli.pull }.to raise_error(SystemExit)
      end
    end

    context "with new files to create" do
      let(:remote_tree) do
        [
          {"kind" => "folder", "path" => ".claude"},
          {"kind" => "file", "path" => ".claude/new.md", "content" => "# New File"}
        ]
      end

      before do
        allow(cli).to receive(:options).and_return({dry_run: false, force: false})
        allow(File).to receive(:exist?).with(".shairc").and_return(true)
        allow(YAML).to receive(:safe_load_file).with(".shairc").and_return({"slug" => "my-config", "include" => [".claude/**"]})
        allow(api).to receive(:get_tree).with("my-config").and_return({"tree" => remote_tree})
        allow(Dir).to receive(:glob).and_return([])
        allow(Dir).to receive(:exist?).and_return(false)
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:dirname).and_call_original
        allow(File).to receive(:write)
        allow(FileUtils).to receive(:mkdir_p)
      end

      it "creates new files and folders" do
        expect(FileUtils).to receive(:mkdir_p).with(".claude")
        expect(File).to receive(:write).with(".claude/new.md", "# New File")
        expect(ui).to receive(:success).with(/Pulled/)
        cli.pull
      end
    end
  end
end
