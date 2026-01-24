# frozen_string_literal: true

require "yaml"
require "time"

module Shai
  class InstalledProjects
    FILENAME = ".shai-installed"
    CURRENT_VERSION = 2

    attr_reader :base_path

    def initialize(base_path)
      @base_path = File.expand_path(base_path)
      @data = load_data
    end

    def file_path
      File.join(base_path, FILENAME)
    end

    def exists?
      File.exist?(file_path)
    end

    def projects
      @data["projects"] || {}
    end

    def project_slugs
      projects.keys
    end

    def empty?
      projects.empty?
    end

    def project_count
      projects.size
    end

    def has_project?(slug)
      projects.key?(slug)
    end

    def get_project(slug)
      projects[slug]
    end

    def files_for_project(slug)
      projects.dig(slug, "files") || []
    end

    def all_installed_files
      projects.values.flat_map { |p| p["files"] || [] }
    end

    # Find which project owns a specific file
    def project_for_file(file_path)
      projects.each do |slug, data|
        return slug if (data["files"] || []).include?(file_path)
      end
      nil
    end

    # Check for conflicts between new files and already installed projects
    # Returns hash of { file_path => owning_project_slug }
    def find_conflicts(new_files)
      conflicts = {}
      new_files.each do |file|
        owner = project_for_file(file)
        conflicts[file] = owner if owner
      end
      conflicts
    end

    # Add a new project with its files
    def add_project(slug, files)
      @data["projects"][slug] = {
        "installed_at" => Time.now.iso8601,
        "files" => files.sort
      }
      save!
    end

    # Remove a project and return its files
    def remove_project(slug)
      project = @data["projects"].delete(slug)
      save! if project
      project&.dig("files") || []
    end

    # Remove specific files from a project (when being overwritten)
    def remove_files_from_project(slug, files_to_remove)
      return unless @data["projects"][slug]

      current_files = @data["projects"][slug]["files"] || []
      @data["projects"][slug]["files"] = current_files - files_to_remove

      # If no files left, remove the project entirely
      if @data["projects"][slug]["files"].empty?
        @data["projects"].delete(slug)
      end

      save!
    end

    def save!
      content = YAML.dump(@data)
      header = "# Installed by shai - do not edit manually\n"
      File.write(file_path, header + content)
    end

    def delete!
      File.delete(file_path) if exists?
    end

    private

    def load_data
      return default_data unless exists?

      raw = YAML.safe_load_file(file_path) || {}

      # Handle old format (version 1 / no version)
      if raw["version"].nil? || raw["version"] < CURRENT_VERSION
        migrate_from_v1(raw)
      else
        raw
      end
    rescue
      # If file is corrupted, start fresh
      default_data
    end

    def default_data
      {
        "version" => CURRENT_VERSION,
        "projects" => {}
      }
    end

    def migrate_from_v1(old_data)
      # Old format had: { "slug" => "name", "installed_at" => "..." }
      slug = old_data["slug"]
      installed_at = old_data["installed_at"]

      if slug
        {
          "version" => CURRENT_VERSION,
          "projects" => {
            slug => {
              "installed_at" => installed_at || Time.now.iso8601,
              "files" => [] # We don't know the files from v1, will be populated on next operation
            }
          }
        }
      else
        default_data
      end
    end
  end
end
