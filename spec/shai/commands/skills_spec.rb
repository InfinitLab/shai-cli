# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Skills commands" do
  let(:cli) { Shai::CLI.new }
  let(:ui) { instance_double(Shai::UI) }

  before do
    allow(cli).to receive(:ui).and_return(ui)

    # Default UI mocks
    allow(ui).to receive(:info)
    allow(ui).to receive(:error)
    allow(ui).to receive(:success)
    allow(ui).to receive(:warning)
    allow(ui).to receive(:blank)
    allow(ui).to receive(:header)
    allow(ui).to receive(:table)
  end

  let(:global_skill_enabled) do
    Shai::Skill.new(
      name: "code-review",
      scope: :global,
      enabled: true,
      path: "/home/.claude/skills/code-review/SKILL.md",
      source: nil,
      agent: "claude"
    )
  end

  let(:global_skill_disabled) do
    Shai::Skill.new(
      name: "refactoring",
      scope: :global,
      enabled: false,
      path: "/home/.claude/skills/refactoring/SKILL.md.disabled",
      source: nil,
      agent: "claude"
    )
  end

  let(:local_skill_enabled) do
    Shai::Skill.new(
      name: "api-design",
      scope: :local,
      enabled: true,
      path: "/project/.claude/skills/api-design/SKILL.md",
      source: nil,
      agent: "claude"
    )
  end

  let(:codex_skill_enabled) do
    Shai::Skill.new(
      name: "deploy-check",
      scope: :global,
      enabled: true,
      path: "/home/.agents/skills/deploy-check/SKILL.md",
      source: nil,
      agent: "codex"
    )
  end

  let(:scanner) { instance_double(Shai::SkillScanner) }

  before do
    allow(Shai::SkillScanner).to receive(:new).and_return(scanner)
    # Default: stub InstalledProjects to return empty for source population
    empty_installed = instance_double(Shai::InstalledProjects, empty?: true, project_slugs: [])
    allow(Shai::InstalledProjects).to receive(:new).and_return(empty_installed)
  end

  describe "#skills" do
    context "with unknown subcommand" do
      it "displays error message" do
        expect(ui).to receive(:error).with(/Unknown subcommand/)
        expect { cli.skills("unknown") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#skills list" do
    context "with no skills" do
      before do
        allow(scanner).to receive(:scan_all).and_return([])
      end

      it "displays no skills message with all agent paths" do
        expect(ui).to receive(:info).with("No skills found.")
        expect(ui).to receive(:info).with(/\.claude\/skills.*claude/)
        expect(ui).to receive(:info).with(/\.agents\/skills.*codex/)
        cli.skills
      end
    end

    context "with skills in both scopes" do
      before do
        allow(scanner).to receive(:scan_all).and_return([
          global_skill_enabled,
          global_skill_disabled,
          local_skill_enabled
        ])
      end

      it "displays grouped tables with Agent column" do
        expect(ui).to receive(:header).with("Global skills")
        expect(ui).to receive(:table).with(
          ["Skill", "Status", "Agent", "Source"],
          [["code-review", "enabled", "claude", "-"], ["refactoring", "disabled", "claude", "-"]]
        )

        expect(ui).to receive(:header).with("Local skills")
        expect(ui).to receive(:table).with(
          ["Skill", "Status", "Agent", "Source"],
          [["api-design", "enabled", "claude", "-"]]
        )

        cli.skills
      end

      it "displays summary count" do
        expect(ui).to receive(:info).with("2 enabled, 1 disabled")
        cli.skills
      end
    end

    context "with skills from multiple agents" do
      before do
        allow(scanner).to receive(:scan_all).and_return([
          global_skill_enabled,
          codex_skill_enabled
        ])
      end

      it "displays all agents in same table" do
        expect(ui).to receive(:table).with(
          ["Skill", "Status", "Agent", "Source"],
          [["code-review", "enabled", "claude", "-"], ["deploy-check", "enabled", "codex", "-"]]
        )
        cli.skills
      end
    end

    context "with only global skills" do
      before do
        allow(scanner).to receive(:scan_all).and_return([global_skill_enabled])
      end

      it "does not display local section" do
        expect(ui).to receive(:header).with("Global skills")
        expect(ui).not_to receive(:header).with("Local skills")
        cli.skills
      end
    end

    context "with source from installed projects" do
      before do
        skill = Shai::Skill.new(
          name: "code-review",
          scope: :global,
          enabled: true,
          path: "/home/.claude/skills/code-review/SKILL.md",
          source: nil,
          agent: "claude"
        )
        allow(scanner).to receive(:scan_all).and_return([skill])

        installed = instance_double(Shai::InstalledProjects,
          empty?: false,
          project_slugs: ["anthropic/best-rules"],
          files_for_project: [".claude/skills/code-review/SKILL.md"])
        allow(Shai::InstalledProjects).to receive(:new).and_return(installed)
      end

      it "populates source column from installed projects" do
        expect(ui).to receive(:table).with(
          ["Skill", "Status", "Agent", "Source"],
          [["code-review", "enabled", "claude", "anthropic/best-rules"]]
        )
        cli.skills
      end
    end
  end

  describe "#skills enable" do
    context "with missing name" do
      it "displays usage error" do
        expect(ui).to receive(:error).with(/Usage:/)
        expect { cli.skills("enable") }.to raise_error(SystemExit)
      end
    end

    context "when skill is found and disabled" do
      before do
        allow(scanner).to receive(:find).with("refactoring", scope: nil, agent: nil).and_return([global_skill_disabled])
        allow(scanner).to receive(:enable!).with(global_skill_disabled).and_return(true)
      end

      it "enables the skill with agent in message" do
        expect(scanner).to receive(:enable!).with(global_skill_disabled)
        expect(ui).to receive(:success).with("Enabled skill 'refactoring' (global, claude)")
        cli.skills("enable", "refactoring")
      end
    end

    context "when skill is already enabled" do
      before do
        allow(scanner).to receive(:find).with("code-review", scope: nil, agent: nil).and_return([global_skill_enabled])
      end

      it "displays info message with agent" do
        expect(ui).to receive(:info).with("Skill 'code-review' is already enabled (global, claude)")
        cli.skills("enable", "code-review")
      end
    end

    context "when skill is not found" do
      before do
        allow(scanner).to receive(:find).with("nonexistent", scope: nil, agent: nil).and_return([])
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.skills("enable", "nonexistent") }.to raise_error(SystemExit)
      end
    end

    context "when skill exists in both scopes without flag" do
      before do
        allow(scanner).to receive(:find).with("code-review", scope: nil, agent: nil).and_return([
          global_skill_enabled,
          local_skill_enabled.tap { |s| s.name = "code-review" }
        ])
      end

      it "displays ambiguity error" do
        expect(ui).to receive(:error).with(/multiple scopes/)
        expect(ui).to receive(:info).with(/--global or --local/)
        expect { cli.skills("enable", "code-review") }.to raise_error(SystemExit)
      end
    end

    context "when skill exists in multiple agents without --agent flag" do
      let(:claude_skill) do
        Shai::Skill.new(name: "shared", scope: :global, enabled: false,
          path: "/home/.claude/skills/shared/SKILL.md.disabled", source: nil, agent: "claude")
      end
      let(:codex_skill) do
        Shai::Skill.new(name: "shared", scope: :global, enabled: false,
          path: "/home/.agents/skills/shared/SKILL.md.disabled", source: nil, agent: "codex")
      end

      before do
        allow(scanner).to receive(:find).with("shared", scope: nil, agent: nil).and_return([claude_skill, codex_skill])
      end

      it "displays ambiguity error mentioning agents" do
        expect(ui).to receive(:error).with(/multiple agents/)
        expect(ui).to receive(:info).with(/--agent <agent>/)
        expect { cli.skills("enable", "shared") }.to raise_error(SystemExit)
      end
    end

    context "with --global flag" do
      let(:cli) { Shai::CLI.new([], {global: true}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
        allow(scanner).to receive(:find).with("refactoring", scope: :global, agent: nil).and_return([global_skill_disabled])
        allow(scanner).to receive(:enable!).with(global_skill_disabled).and_return(true)
      end

      it "searches only global scope" do
        expect(scanner).to receive(:find).with("refactoring", scope: :global, agent: nil)
        cli.skills("enable", "refactoring")
      end
    end

    context "with --local flag" do
      let(:cli) { Shai::CLI.new([], {local: true}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
        allow(scanner).to receive(:find).with("api-design", scope: :local, agent: nil).and_return([local_skill_enabled])
      end

      it "searches only local scope" do
        expect(scanner).to receive(:find).with("api-design", scope: :local, agent: nil)
        cli.skills("enable", "api-design")
      end
    end

    context "with --agent flag" do
      let(:cli) { Shai::CLI.new([], {agent: "codex"}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
        allow(scanner).to receive(:find).with("deploy-check", scope: nil, agent: "codex").and_return([codex_skill_enabled])
      end

      it "searches only specified agent" do
        expect(scanner).to receive(:find).with("deploy-check", scope: nil, agent: "codex")
        cli.skills("enable", "deploy-check")
      end
    end

    context "with --agent and --global flags" do
      let(:cli) { Shai::CLI.new([], {agent: "claude", global: true}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
        allow(scanner).to receive(:find).with("code-review", scope: :global, agent: "claude").and_return([global_skill_enabled])
      end

      it "combines scope and agent filters" do
        expect(scanner).to receive(:find).with("code-review", scope: :global, agent: "claude")
        cli.skills("enable", "code-review")
      end
    end

    context "with unknown --agent value" do
      let(:cli) { Shai::CLI.new([], {agent: "unknown"}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
      end

      it "displays error about unknown agent" do
        expect(ui).to receive(:error).with(/Unknown agent 'unknown'/)
        expect { cli.skills("enable", "some-skill") }.to raise_error(SystemExit)
      end
    end

    context "with both --global and --local" do
      let(:cli) { Shai::CLI.new([], {global: true, local: true}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
      end

      it "displays conflicting options error" do
        expect(ui).to receive(:error).with(/Cannot use --global and --local together/)
        expect { cli.skills("enable", "code-review") }.to raise_error(SystemExit)
      end
    end
  end

  describe "#skills disable" do
    context "with missing name" do
      it "displays usage error" do
        expect(ui).to receive(:error).with(/Usage:/)
        expect { cli.skills("disable") }.to raise_error(SystemExit)
      end
    end

    context "when skill is found and enabled" do
      before do
        allow(scanner).to receive(:find).with("code-review", scope: nil, agent: nil).and_return([global_skill_enabled])
        allow(scanner).to receive(:disable!).with(global_skill_enabled).and_return(true)
      end

      it "disables the skill with agent in message" do
        expect(scanner).to receive(:disable!).with(global_skill_enabled)
        expect(ui).to receive(:success).with("Disabled skill 'code-review' (global, claude)")
        cli.skills("disable", "code-review")
      end
    end

    context "when skill is already disabled" do
      before do
        allow(scanner).to receive(:find).with("refactoring", scope: nil, agent: nil).and_return([global_skill_disabled])
      end

      it "displays info message with agent" do
        expect(ui).to receive(:info).with("Skill 'refactoring' is already disabled (global, claude)")
        cli.skills("disable", "refactoring")
      end
    end

    context "when skill is not found" do
      before do
        allow(scanner).to receive(:find).with("nonexistent", scope: nil, agent: nil).and_return([])
      end

      it "displays error and exits" do
        expect(ui).to receive(:error).with(/not found/)
        expect { cli.skills("disable", "nonexistent") }.to raise_error(SystemExit)
      end
    end

    context "with --global flag" do
      let(:cli) { Shai::CLI.new([], {global: true}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
        allow(scanner).to receive(:find).with("code-review", scope: :global, agent: nil).and_return([global_skill_enabled])
        allow(scanner).to receive(:disable!).with(global_skill_enabled).and_return(true)
      end

      it "searches only global scope" do
        expect(scanner).to receive(:find).with("code-review", scope: :global, agent: nil)
        cli.skills("disable", "code-review")
      end
    end

    context "with --agent flag" do
      let(:cli) { Shai::CLI.new([], {agent: "codex"}) }

      before do
        allow(cli).to receive(:ui).and_return(ui)
        allow(scanner).to receive(:find).with("deploy-check", scope: nil, agent: "codex").and_return([codex_skill_enabled])
        allow(scanner).to receive(:disable!).with(codex_skill_enabled).and_return(true)
      end

      it "disables the codex skill" do
        expect(scanner).to receive(:disable!).with(codex_skill_enabled)
        expect(ui).to receive(:success).with("Disabled skill 'deploy-check' (global, codex)")
        cli.skills("disable", "deploy-check")
      end
    end
  end
end
