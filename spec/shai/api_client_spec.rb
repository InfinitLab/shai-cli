# frozen_string_literal: true

RSpec.describe Shai::ApiClient do
  let(:client) { described_class.new }

  describe "#login" do
    context "with valid credentials" do
      before { stub_login_success }

      it "returns user data and token" do
        result = client.login(identifier: "test@example.com", password: "password123")

        expect(result["data"]["token"]).to eq("test-token-123")
        expect(result["data"]["user"]["username"]).to eq("testuser")
      end
    end

    context "with invalid credentials" do
      before { stub_login_failure }

      it "raises AuthenticationError" do
        expect {
          client.login(identifier: "test@example.com", password: "wrong")
        }.to raise_error(Shai::AuthenticationError, "Invalid credentials")
      end
    end
  end

  describe "#list_configurations" do
    before do
      # Set up authentication
      Shai.credentials.save(
        token: "test-token",
        expires_at: (Time.now + 3600).iso8601,
        user: {"username" => "testuser"}
      )
    end

    context "with configurations" do
      before do
        stub_list_configurations(configurations: [
          build(:configuration, name: "Config 1", slug: "config-1"),
          build(:configuration, name: "Config 2", slug: "config-2")
        ])
      end

      it "returns list of configurations" do
        result = client.list_configurations

        expect(result["configurations"].length).to eq(2)
        expect(result["configurations"].first["slug"]).to eq("config-1")
      end
    end

    context "with no configurations" do
      before { stub_list_configurations(configurations: []) }

      it "returns empty list" do
        result = client.list_configurations

        expect(result["configurations"]).to eq([])
      end
    end
  end

  describe "#search_configurations" do
    context "with matching results" do
      before do
        stub_search_configurations(
          query: "claude",
          configurations: [build(:configuration, :public, name: "Claude Config")]
        )
      end

      it "returns matching configurations" do
        result = client.search_configurations(query: "claude")

        expect(result["configurations"].length).to eq(1)
        expect(result["configurations"].first["name"]).to eq("Claude Config")
      end
    end
  end

  describe "#get_tree" do
    before do
      Shai.credentials.save(
        token: "test-token",
        expires_at: (Time.now + 3600).iso8601,
        user: {"username" => "testuser"}
      )
    end

    context "when configuration exists" do
      before do
        stub_get_tree(
          slug: "test-config",
          tree: [
            build(:tree_node, :folder, path: ".claude"),
            build(:tree_node, path: ".claude/settings.json")
          ]
        )
      end

      it "returns the configuration tree" do
        result = client.get_tree("test-config")

        expect(result["tree"].length).to eq(2)
        expect(result["tree"].first["kind"]).to eq("folder")
      end
    end

    context "when configuration does not exist" do
      before { stub_not_found("/api/v1/configurations/nonexistent/tree") }

      it "raises NotFoundError" do
        expect {
          client.get_tree("nonexistent")
        }.to raise_error(Shai::NotFoundError)
      end
    end
  end

  describe "#update_tree" do
    before do
      Shai.credentials.save(
        token: "test-token",
        expires_at: (Time.now + 3600).iso8601,
        user: {"username" => "testuser"}
      )
      stub_update_tree(slug: "test-config")
    end

    it "sends tree update request" do
      tree = [
        {kind: "folder", path: ".claude"},
        {kind: "file", path: ".claude/settings.json", content: "{}"}
      ]

      result = client.update_tree("test-config", tree)

      expect(result["message"]).to eq("Tree replaced successfully")
    end
  end

  describe "#create_configuration" do
    before do
      Shai.credentials.save(
        token: "test-token",
        expires_at: (Time.now + 3600).iso8601,
        user: {"username" => "testuser"}
      )
      stub_create_configuration(name: "My Config", slug: "my-config")
    end

    it "creates a new configuration" do
      result = client.create_configuration(name: "My Config")

      expect(result["configuration"]["slug"]).to eq("my-config")
    end
  end

  describe "#delete_configuration" do
    before do
      Shai.credentials.save(
        token: "test-token",
        expires_at: (Time.now + 3600).iso8601,
        user: {"username" => "testuser"}
      )
      stub_delete_configuration(slug: "test-config")
    end

    it "deletes the configuration" do
      result = client.delete_configuration("test-config")

      expect(result["message"]).to eq("Configuration deleted")
    end
  end
end
