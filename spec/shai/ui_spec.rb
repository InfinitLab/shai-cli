# frozen_string_literal: true

RSpec.describe Shai::UI do
  let(:ui) { described_class.new(color: false) }

  describe "#success" do
    it "outputs success message with checkmark" do
      expect { ui.success("Done") }.to output("✓ Done\n").to_stdout
    end
  end

  describe "#error" do
    it "outputs error message with prefix" do
      expect { ui.error("Failed") }.to output("Error: Failed\n").to_stdout
    end
  end

  describe "#warning" do
    it "outputs warning message" do
      expect { ui.warning("Caution") }.to output("Warning: Caution\n").to_stdout
    end
  end

  describe "#info" do
    it "outputs plain message" do
      expect { ui.info("Hello") }.to output("Hello\n").to_stdout
    end
  end

  describe "#header" do
    it "outputs bold header" do
      expect { ui.header("Title") }.to output("Title\n").to_stdout
    end
  end

  describe "#indent" do
    it "outputs indented text" do
      expect { ui.indent("Item") }.to output("  Item\n").to_stdout
    end

    it "supports custom spacing" do
      expect { ui.indent("Item", spaces: 4) }.to output("    Item\n").to_stdout
    end
  end

  describe "#display_file_operation" do
    it "displays created files" do
      expect { ui.display_file_operation(:created, "file.txt") }
        .to output("  Created file.txt\n").to_stdout
    end

    it "displays modified files" do
      expect { ui.display_file_operation(:modified, "file.txt") }
        .to output("  Modified file.txt\n").to_stdout
    end

    it "displays deleted files" do
      expect { ui.display_file_operation(:deleted, "file.txt") }
        .to output("  Deleted file.txt\n").to_stdout
    end
  end

  describe "#display_configuration" do
    let(:config) do
      {
        "slug" => "my-config",
        "visibility" => "private",
        "stars_count" => 5,
        "description" => "Test config"
      }
    end

    it "displays configuration info" do
      output = capture_stdout { ui.display_configuration(config) }

      expect(output).to include("my-config")
      expect(output).to include("(private)")
      expect(output).to include("Test config")
    end

    context "with owner" do
      let(:config) do
        {
          "slug" => "my-config",
          "visibility" => "public",
          "stars_count" => 10,
          "owner" => {"username" => "testuser"}
        }
      end

      it "includes owner in display" do
        output = capture_stdout { ui.display_configuration(config) }

        expect(output).to include("testuser/my-config")
      end
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
