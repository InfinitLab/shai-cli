# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shai::InstallRegistry do
  let(:registry) { described_class.new }

  describe "#add" do
    it "records a new installation" do
      registry.add("owner/slug", "/tmp/test")
      expect(registry.has?("owner/slug")).to be true
    end

    it "stores the expanded path" do
      registry.add("owner/slug", "/tmp/test")
      expect(registry.path_for("owner/slug")).to eq("/tmp/test")
    end

    it "persists to disk" do
      registry.add("owner/slug", "/tmp/test")

      reloaded = described_class.new
      expect(reloaded.has?("owner/slug")).to be true
      expect(reloaded.path_for("owner/slug")).to eq("/tmp/test")
    end

    it "overwrites existing entries for the same slug" do
      registry.add("owner/slug", "/tmp/old")
      registry.add("owner/slug", "/tmp/new")
      expect(registry.path_for("owner/slug")).to eq("/tmp/new")
    end
  end

  describe "#remove" do
    before { registry.add("owner/slug", "/tmp/test") }

    it "removes the entry" do
      registry.remove("owner/slug")
      expect(registry.has?("owner/slug")).to be false
    end

    it "returns the removed entry" do
      result = registry.remove("owner/slug")
      expect(result).to include("path" => "/tmp/test")
    end

    it "returns nil for non-existent entry" do
      expect(registry.remove("nonexistent")).to be_nil
    end

    it "persists removal to disk" do
      registry.remove("owner/slug")
      reloaded = described_class.new
      expect(reloaded.has?("owner/slug")).to be false
    end
  end

  describe "#path_for" do
    it "returns the path for a registered slug" do
      registry.add("owner/slug", "/home/user")
      expect(registry.path_for("owner/slug")).to eq("/home/user")
    end

    it "returns nil for unregistered slug" do
      expect(registry.path_for("nonexistent")).to be_nil
    end
  end

  describe "#all" do
    it "returns all registered installations" do
      registry.add("owner/first", "/tmp/a")
      registry.add("owner/second", "/tmp/b")

      all = registry.all
      expect(all.keys).to contain_exactly("owner/first", "owner/second")
    end

    it "returns empty hash when nothing is registered" do
      expect(registry.all).to eq({})
    end
  end

  describe "#has?" do
    it "returns true for registered slugs" do
      registry.add("owner/slug", "/tmp/test")
      expect(registry.has?("owner/slug")).to be true
    end

    it "returns false for unregistered slugs" do
      expect(registry.has?("nonexistent")).to be false
    end
  end

  describe "file_path" do
    it "stores in the config directory" do
      expect(registry.file_path).to eq(File.join(Shai.configuration.config_dir, "installations.yml"))
    end
  end

  describe "corrupted file handling" do
    it "recovers from corrupted YAML" do
      FileUtils.mkdir_p(Shai.configuration.config_dir)
      File.write(registry.file_path, "not: [valid: yaml: {{")

      reloaded = described_class.new
      expect(reloaded.all).to eq({})
    end
  end
end
