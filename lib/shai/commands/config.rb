# frozen_string_literal: true

require "yaml"

module Shai
  module Commands
    module Config
      SHAIRC_FILE = ".shairc"

      def self.included(base)
        base.class_eval do
          desc "config SUBCOMMAND", "Manage configuration metadata"
          def config(subcommand = nil, *args)
            case subcommand
            when "show"
              config_show
            when "set"
              config_set(args)
            when nil
              ui.error("Missing subcommand. Use `shai config show` or `shai config set`")
              exit EXIT_INVALID_INPUT
            else
              ui.error("Unknown subcommand: #{subcommand}")
              exit EXIT_INVALID_INPUT
            end
          end

          desc "delete SLUG", "Delete a configuration"
          def delete(slug)
            require_auth!

            unless ui.yes?("Are you sure you want to delete '#{slug}'? This cannot be undone.")
              ui.info("Cancelled")
              return
            end

            begin
              ui.spinner("Deleting...") do
                api.delete_configuration(slug)
              end

              ui.success("Configuration '#{slug}' deleted")
            rescue NotFoundError
              ui.error("Configuration '#{slug}' not found.")
              exit EXIT_NOT_FOUND
            rescue PermissionDeniedError
              ui.error("You don't have permission to delete '#{slug}'.")
              exit EXIT_PERMISSION_DENIED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end
        end
      end

      private

      def config_show
        require_auth!

        shairc = load_shairc_for_config
        slug = shairc["slug"]

        begin
          response = ui.spinner("Fetching configuration...") do
            api.get_configuration(slug)
          end

          config = response["configuration"] || response

          ui.info("Configuration: #{config["slug"]}")
          ui.info("Name: #{config["name"]}")
          ui.info("Description: #{config["description"] || "(none)"}")
          ui.info("Visibility: #{config["visibility"]}")
          owner = config["owner"]
          owner_name = owner.is_a?(Hash) ? owner["username"] : owner
          ui.info("Owner: #{owner_name || credentials.username}")
          ui.info("Stars: #{config["stars_count"] || 0}")
          ui.info("URL: #{Shai.configuration.api_url}/#{credentials.username}/#{config["slug"]}")
          ui.info("Created: #{format_config_date(config["created_at"])}")
          ui.info("Updated: #{format_config_date(config["updated_at"])}")
        rescue NotFoundError
          ui.error("Configuration '#{slug}' not found.")
          exit EXIT_NOT_FOUND
        rescue NetworkError => e
          ui.error(e.message)
          exit EXIT_NETWORK_ERROR
        end
      end

      def config_set(args)
        require_auth!

        if args.length < 2
          ui.error("Usage: shai config set <key> <value>")
          ui.info("Valid keys: name, description, visibility")
          exit EXIT_INVALID_INPUT
        end

        key = args[0]
        value = args[1..].join(" ")

        valid_keys = %w[name description visibility]
        unless valid_keys.include?(key)
          ui.error("Invalid key: #{key}")
          ui.info("Valid keys: #{valid_keys.join(", ")}")
          exit EXIT_INVALID_INPUT
        end

        if key == "visibility" && !%w[public private].include?(value)
          ui.error("Visibility must be 'public' or 'private'")
          exit EXIT_INVALID_INPUT
        end

        shairc = load_shairc_for_config
        slug = shairc["slug"]

        begin
          ui.spinner("Updating...") do
            api.update_configuration(slug, key.to_sym => value)
          end

          ui.success("Updated #{key} to '#{value}'")
        rescue NotFoundError
          ui.error("Configuration '#{slug}' not found.")
          exit EXIT_NOT_FOUND
        rescue PermissionDeniedError
          ui.error("You don't have permission to modify this configuration.")
          exit EXIT_PERMISSION_DENIED
        rescue InvalidConfigurationError => e
          ui.error(e.message)
          exit EXIT_INVALID_INPUT
        rescue NetworkError => e
          ui.error(e.message)
          exit EXIT_NETWORK_ERROR
        end
      end

      def load_shairc_for_config
        unless File.exist?(SHAIRC_FILE)
          ui.error("No #{SHAIRC_FILE} file found. Run `shai init` to create one.")
          exit EXIT_INVALID_INPUT
        end

        shairc = YAML.safe_load_file(SHAIRC_FILE)

        unless shairc["slug"]
          ui.error("Invalid #{SHAIRC_FILE} file. Missing required field: slug")
          exit EXIT_INVALID_INPUT
        end

        shairc
      rescue Psych::SyntaxError => e
        ui.error("Invalid #{SHAIRC_FILE} file: #{e.message}")
        exit EXIT_INVALID_INPUT
      end

      def format_config_date(date_string)
        return "(unknown)" unless date_string

        Time.parse(date_string).strftime("%B %-d, %Y")
      rescue ArgumentError
        date_string
      end
    end
  end
end
