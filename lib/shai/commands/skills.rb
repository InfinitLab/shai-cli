# frozen_string_literal: true

module Shai
  module Commands
    module Skills
      def self.included(base)
        base.class_eval do
          desc "skills [SUBCOMMAND]", "Manage AI agent skills"
          method_option :global, type: :boolean, default: false, desc: "Target global skills"
          method_option :local, type: :boolean, default: false, desc: "Target local skills"
          method_option :agent, type: :string, desc: "Target a specific agent (e.g. claude, codex)"
          def skills(subcommand = nil, *args)
            case subcommand
            when nil, "list"
              skills_list
            when "enable"
              name = args.first
              unless name
                ui.error("Usage: shai skills enable <name> [--global|--local] [--agent <agent>]")
                exit EXIT_INVALID_INPUT
              end
              skills_enable(name)
            when "disable"
              name = args.first
              unless name
                ui.error("Usage: shai skills disable <name> [--global|--local] [--agent <agent>]")
                exit EXIT_INVALID_INPUT
              end
              skills_disable(name)
            else
              ui.error("Unknown subcommand: #{subcommand}. Use `shai skills`, `shai skills enable`, or `shai skills disable`")
              exit EXIT_INVALID_INPUT
            end
          end
        end
      end

      private

      def skills_list
        scanner = SkillScanner.new
        all_skills = scanner.scan_all
        populate_sources!(all_skills)

        if all_skills.empty?
          ui.info("No skills found.")
          ui.blank
          ui.info("Skill discovery paths:")
          SkillScanner::AGENTS.each do |agent|
            ui.info("  Global: ~/#{agent[:skill_dir]}/*/SKILL.md (#{agent[:name]})")
            ui.info("  Local:  ./#{agent[:skill_dir]}/*/SKILL.md (#{agent[:name]})")
          end
          return
        end

        global_skills = all_skills.select { |s| s.scope == :global }
        local_skills = all_skills.select { |s| s.scope == :local }

        if global_skills.any?
          ui.blank
          ui.header("Global skills")
          ui.blank
          ui.table(
            ["Skill", "Status", "Agent", "Source"],
            global_skills.map { |s| skill_row(s) }
          )
        end

        if local_skills.any?
          ui.blank
          ui.header("Local skills")
          ui.blank
          ui.table(
            ["Skill", "Status", "Agent", "Source"],
            local_skills.map { |s| skill_row(s) }
          )
        end

        enabled_count = all_skills.count(&:enabled)
        disabled_count = all_skills.count { |s| !s.enabled }
        ui.blank
        ui.info("#{enabled_count} enabled, #{disabled_count} disabled")
      end

      def skills_enable(name)
        scanner, skill = resolve_skill(scanner_instance, name)
        return unless skill

        if skill.enabled
          ui.info("Skill '#{name}' is already enabled (#{skill.scope}, #{skill.agent})")
          return
        end

        scanner.enable!(skill)
        ui.success("Enabled skill '#{name}' (#{skill.scope}, #{skill.agent})")
      end

      def skills_disable(name)
        scanner, skill = resolve_skill(scanner_instance, name)
        return unless skill

        unless skill.enabled
          ui.info("Skill '#{name}' is already disabled (#{skill.scope}, #{skill.agent})")
          return
        end

        scanner.disable!(skill)
        ui.success("Disabled skill '#{name}' (#{skill.scope}, #{skill.agent})")
      end

      def scanner_instance
        SkillScanner.new
      end

      def resolve_skill(scanner, name)
        validate_scope_flags!
        validate_agent_flag!

        scope = if options[:global]
          :global
        elsif options[:local]
          :local
        end

        agent = options[:agent]

        matches = scanner.find(name, scope: scope, agent: agent)

        if matches.empty?
          ui.error("Skill '#{name}' not found. Run `shai skills` to see available skills.")
          exit EXIT_NOT_FOUND
        end

        if matches.length > 1
          ambiguous_by_scope = matches.map(&:scope).uniq.length > 1
          ambiguous_by_agent = matches.map(&:agent).uniq.length > 1

          ui.error("Skill '#{name}' exists in multiple #{ambiguous_by_agent ? "agents" : "scopes"}:")
          matches.each { |s| ui.info("  - #{s.scope}, #{s.agent} (#{s.path})") }

          hints = []
          hints << "--global or --local" if ambiguous_by_scope
          hints << "--agent <agent>" if ambiguous_by_agent
          ui.info("Use #{hints.join(" and ")} to specify which one.")
          exit EXIT_INVALID_INPUT
        end

        [scanner, matches.first]
      end

      def validate_scope_flags!
        if options[:global] && options[:local]
          ui.error("Cannot use --global and --local together")
          exit EXIT_INVALID_INPUT
        end
      end

      def validate_agent_flag!
        agent = options[:agent]
        return unless agent

        known = SkillScanner::AGENTS.map { |a| a[:name] }
        unless known.include?(agent)
          ui.error("Unknown agent '#{agent}'. Known agents: #{known.join(", ")}")
          exit EXIT_INVALID_INPUT
        end
      end

      def skill_row(skill)
        status = skill.enabled ? "enabled" : "disabled"
        source = skill.source || "-"
        [skill.name, status, skill.agent, source]
      end

      def populate_sources!(skills)
        [Dir.home, Dir.pwd].each do |base|
          installed = InstalledProjects.new(base)
          next if installed.empty?

          skills.each do |skill|
            next if skill.source

            installed.project_slugs.each do |slug|
              files = installed.files_for_project(slug)
              SkillScanner::AGENTS.each do |agent|
                skill_relative = "#{agent[:skill_dir]}/#{skill.name}/SKILL.md"
                if files.any? { |f| f == skill_relative || f.start_with?("#{agent[:skill_dir]}/#{skill.name}/") }
                  skill.source = slug
                  break
                end
              end
              break if skill.source
            end
          end
        end
      end
    end
  end
end
