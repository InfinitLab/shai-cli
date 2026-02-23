# frozen_string_literal: true

require "yaml"
require "time"
require "fileutils"

module Shai
  class InstallRegistry
    def initialize
      @file_path = File.join(Shai.configuration.config_dir, "installations.yml")
      @data = load_data
    end

    attr_reader :file_path

    def add(slug, path)
      @data["projects"][slug] = {
        "path" => File.expand_path(path),
        "installed_at" => Time.now.iso8601
      }
      save!
    end

    def remove(slug)
      removed = @data["projects"].delete(slug)
      save! if removed
      removed
    end

    def path_for(slug)
      @data.dig("projects", slug, "path")
    end

    def all
      @data["projects"].dup
    end

    def has?(slug)
      @data["projects"].key?(slug)
    end

    private

    def load_data
      return default_data unless File.exist?(@file_path)

      raw = YAML.safe_load_file(@file_path) || {}
      raw.is_a?(Hash) && raw["projects"].is_a?(Hash) ? raw : default_data
    rescue
      default_data
    end

    def default_data
      {"projects" => {}}
    end

    def save!
      FileUtils.mkdir_p(File.dirname(@file_path))
      File.write(@file_path, YAML.dump(@data))
    end
  end
end
