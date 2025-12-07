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
  end
end
