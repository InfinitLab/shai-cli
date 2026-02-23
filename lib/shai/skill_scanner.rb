# frozen_string_literal: true

module Shai
  Skill = Struct.new(:name, :scope, :enabled, :path, :source, :agent, keyword_init: true)

  class SkillScanner
    SKILL_FILE = "SKILL.md"
    DISABLED_SUFFIX = ".disabled"

    AGENTS = [
      {name: "claude", skill_dir: ".claude/skills"},
      {name: "codex", skill_dir: ".agents/skills"}
    ].freeze

    attr_reader :local_base, :global_base

    def initialize(local_base: Dir.pwd, global_base: Dir.home)
      @local_base = File.expand_path(local_base)
      @global_base = File.expand_path(global_base)
    end

    def scan_all
      skills = []
      skills.concat(scan_scope(:global))
      skills.concat(scan_scope(:local))
      skills
    end

    def find(name, scope: nil, agent: nil)
      skills = scan_all
      skills.select! { |s| s.name == name }
      skills.select! { |s| s.scope == scope } if scope
      skills.select! { |s| s.agent == agent } if agent
      skills
    end

    def enable!(skill)
      return false if skill.enabled
      disabled_path = skill.path
      enabled_path = disabled_path.sub(/#{Regexp.escape(DISABLED_SUFFIX)}$/o, "")
      return false unless File.exist?(disabled_path)

      File.rename(disabled_path, enabled_path)
      true
    end

    def disable!(skill)
      return false unless skill.enabled
      enabled_path = skill.path
      disabled_path = "#{enabled_path}#{DISABLED_SUFFIX}"
      return false unless File.exist?(enabled_path)

      File.rename(enabled_path, disabled_path)
      true
    end

    private

    def scan_scope(scope)
      base = (scope == :global) ? global_base : local_base
      skills = []

      AGENTS.each do |agent|
        skill_dir = File.join(base, agent[:skill_dir])
        next unless Dir.exist?(skill_dir)

        Dir.children(skill_dir).sort.each do |entry|
          full_dir = File.join(skill_dir, entry)
          next unless File.directory?(full_dir)

          enabled_file = File.join(full_dir, SKILL_FILE)
          disabled_file = File.join(full_dir, "#{SKILL_FILE}#{DISABLED_SUFFIX}")

          if File.exist?(enabled_file)
            skills << Skill.new(
              name: entry,
              scope: scope,
              enabled: true,
              path: enabled_file,
              source: nil,
              agent: agent[:name]
            )
          elsif File.exist?(disabled_file)
            skills << Skill.new(
              name: entry,
              scope: scope,
              enabled: false,
              path: disabled_file,
              source: nil,
              agent: agent[:name]
            )
          end
        end
      end

      skills
    end
  end
end
