# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shai::SkillScanner do
  let(:tmpdir) { Dir.mktmpdir("shai-skill-test") }
  let(:global_base) { File.join(tmpdir, "home") }
  let(:local_base) { File.join(tmpdir, "project") }
  let(:scanner) { described_class.new(local_base: local_base, global_base: global_base) }

  before do
    FileUtils.mkdir_p(global_base)
    FileUtils.mkdir_p(local_base)
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def create_skill(base, name, enabled: true, agent_dir: ".claude/skills")
    dir = File.join(base, agent_dir, name)
    FileUtils.mkdir_p(dir)
    filename = enabled ? "SKILL.md" : "SKILL.md.disabled"
    path = File.join(dir, filename)
    File.write(path, "# #{name}")
    path
  end

  describe "#scan_all" do
    context "with no skills" do
      it "returns empty array" do
        expect(scanner.scan_all).to eq([])
      end
    end

    context "when skill directories do not exist" do
      it "returns empty array without error" do
        expect(scanner.scan_all).to eq([])
      end
    end

    context "with an enabled global skill" do
      before { create_skill(global_base, "code-review") }

      it "returns one enabled skill" do
        skills = scanner.scan_all
        expect(skills.length).to eq(1)
        expect(skills.first.name).to eq("code-review")
        expect(skills.first.scope).to eq(:global)
        expect(skills.first.enabled).to be true
        expect(skills.first.agent).to eq("claude")
      end
    end

    context "with a disabled global skill" do
      before { create_skill(global_base, "refactoring", enabled: false) }

      it "returns one disabled skill" do
        skills = scanner.scan_all
        expect(skills.length).to eq(1)
        expect(skills.first.name).to eq("refactoring")
        expect(skills.first.scope).to eq(:global)
        expect(skills.first.enabled).to be false
        expect(skills.first.agent).to eq("claude")
      end
    end

    context "with skills in both scopes" do
      before do
        create_skill(global_base, "code-review")
        create_skill(global_base, "refactoring", enabled: false)
        create_skill(local_base, "api-design")
      end

      it "returns all skills from both scopes" do
        skills = scanner.scan_all
        expect(skills.length).to eq(3)
        expect(skills.map(&:name)).to eq(["code-review", "refactoring", "api-design"])
      end

      it "assigns correct scopes" do
        skills = scanner.scan_all
        global = skills.select { |s| s.scope == :global }
        local = skills.select { |s| s.scope == :local }
        expect(global.length).to eq(2)
        expect(local.length).to eq(1)
      end
    end

    context "with a directory that has no SKILL.md" do
      before do
        dir = File.join(global_base, ".claude/skills/empty-dir")
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "README.md"), "not a skill")
      end

      it "silently skips the directory" do
        expect(scanner.scan_all).to eq([])
      end
    end

    context "with a non-directory entry in skill dir" do
      before do
        skill_dir = File.join(global_base, ".claude/skills")
        FileUtils.mkdir_p(skill_dir)
        File.write(File.join(skill_dir, "stray-file.txt"), "not a dir")
      end

      it "silently skips the file" do
        expect(scanner.scan_all).to eq([])
      end
    end

    context "with skills from multiple agents" do
      before do
        create_skill(global_base, "code-review", agent_dir: ".claude/skills")
        create_skill(global_base, "deploy-check", agent_dir: ".agents/skills")
      end

      it "returns skills from all agents" do
        skills = scanner.scan_all
        expect(skills.length).to eq(2)
        expect(skills.map(&:name)).to contain_exactly("code-review", "deploy-check")
      end

      it "tags each skill with its agent" do
        skills = scanner.scan_all
        claude_skill = skills.find { |s| s.name == "code-review" }
        codex_skill = skills.find { |s| s.name == "deploy-check" }
        expect(claude_skill.agent).to eq("claude")
        expect(codex_skill.agent).to eq("codex")
      end
    end

    context "with same skill name in different agents" do
      before do
        create_skill(global_base, "shared-skill", agent_dir: ".claude/skills")
        create_skill(global_base, "shared-skill", agent_dir: ".agents/skills")
      end

      it "returns both skills" do
        skills = scanner.scan_all
        expect(skills.length).to eq(2)
        expect(skills.map(&:agent)).to contain_exactly("claude", "codex")
        expect(skills.map(&:name)).to eq(["shared-skill", "shared-skill"])
      end
    end

    context "with codex skills in both scopes" do
      before do
        create_skill(global_base, "codex-global", agent_dir: ".agents/skills")
        create_skill(local_base, "codex-local", agent_dir: ".agents/skills")
      end

      it "returns codex skills from both scopes" do
        skills = scanner.scan_all
        expect(skills.length).to eq(2)
        global = skills.find { |s| s.scope == :global }
        local = skills.find { |s| s.scope == :local }
        expect(global.name).to eq("codex-global")
        expect(global.agent).to eq("codex")
        expect(local.name).to eq("codex-local")
        expect(local.agent).to eq("codex")
      end
    end
  end

  describe "#find" do
    before do
      create_skill(global_base, "code-review")
      create_skill(local_base, "code-review")
      create_skill(global_base, "debugging")
    end

    context "by name only" do
      it "returns all matches" do
        results = scanner.find("code-review")
        expect(results.length).to eq(2)
        expect(results.map(&:scope)).to contain_exactly(:global, :local)
      end

      it "returns empty for non-existent skill" do
        expect(scanner.find("nonexistent")).to eq([])
      end
    end

    context "with scope filter" do
      it "returns only global matches" do
        results = scanner.find("code-review", scope: :global)
        expect(results.length).to eq(1)
        expect(results.first.scope).to eq(:global)
      end

      it "returns only local matches" do
        results = scanner.find("code-review", scope: :local)
        expect(results.length).to eq(1)
        expect(results.first.scope).to eq(:local)
      end

      it "returns empty when no match in scope" do
        expect(scanner.find("debugging", scope: :local)).to eq([])
      end
    end

    context "with agent filter" do
      before do
        create_skill(global_base, "shared-skill", agent_dir: ".claude/skills")
        create_skill(global_base, "shared-skill", agent_dir: ".agents/skills")
      end

      it "returns only matching agent" do
        results = scanner.find("shared-skill", agent: "claude")
        expect(results.length).to eq(1)
        expect(results.first.agent).to eq("claude")
      end

      it "returns only codex matches" do
        results = scanner.find("shared-skill", agent: "codex")
        expect(results.length).to eq(1)
        expect(results.first.agent).to eq("codex")
      end

      it "returns empty when agent has no match" do
        expect(scanner.find("debugging", agent: "codex")).to eq([])
      end
    end

    context "with both scope and agent filter" do
      before do
        create_skill(global_base, "multi", agent_dir: ".claude/skills")
        create_skill(local_base, "multi", agent_dir: ".claude/skills")
        create_skill(global_base, "multi", agent_dir: ".agents/skills")
      end

      it "narrows by both filters" do
        results = scanner.find("multi", scope: :global, agent: "codex")
        expect(results.length).to eq(1)
        expect(results.first.scope).to eq(:global)
        expect(results.first.agent).to eq("codex")
      end
    end
  end

  describe "#enable!" do
    context "when skill is disabled" do
      it "renames SKILL.md.disabled to SKILL.md" do
        disabled_path = create_skill(global_base, "refactoring", enabled: false)
        skill = scanner.scan_all.first

        expect(scanner.enable!(skill)).to be true
        expect(File.exist?(disabled_path)).to be false

        enabled_path = disabled_path.sub(/\.disabled$/, "")
        expect(File.exist?(enabled_path)).to be true
      end
    end

    context "when skill is already enabled" do
      it "returns false" do
        create_skill(global_base, "code-review")
        skill = scanner.scan_all.first

        expect(scanner.enable!(skill)).to be false
      end
    end

    context "when file no longer exists" do
      it "returns false" do
        create_skill(global_base, "vanished", enabled: false)
        skill = scanner.scan_all.first
        FileUtils.rm(skill.path)

        expect(scanner.enable!(skill)).to be false
      end
    end
  end

  describe "#disable!" do
    context "when skill is enabled" do
      it "renames SKILL.md to SKILL.md.disabled" do
        enabled_path = create_skill(global_base, "code-review")
        skill = scanner.scan_all.first

        expect(scanner.disable!(skill)).to be true
        expect(File.exist?(enabled_path)).to be false
        expect(File.exist?("#{enabled_path}.disabled")).to be true
      end
    end

    context "when skill is already disabled" do
      it "returns false" do
        create_skill(global_base, "refactoring", enabled: false)
        skill = scanner.scan_all.first

        expect(scanner.disable!(skill)).to be false
      end
    end

    context "when file no longer exists" do
      it "returns false" do
        create_skill(global_base, "vanished")
        skill = scanner.scan_all.first
        FileUtils.rm(skill.path)

        expect(scanner.disable!(skill)).to be false
      end
    end
  end
end
