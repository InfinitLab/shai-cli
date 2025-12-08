# frozen_string_literal: true

require "time"

module Shai
  module Commands
    module Configurations
      def self.included(base)
        base.class_eval do
          desc "list", "List your configurations"
          def list
            require_auth!

            begin
              response = ui.spinner("Fetching configurations...") do
                api.list_configurations
              end

              configs = response.is_a?(Array) ? response : response["configurations"]

              if configs.empty?
                ui.info("You don't have any configurations yet.")
                ui.info("Run `shai init` to create one.")
              else
                ui.header("Your configurations:")
                ui.blank
                configs.each do |config|
                  ui.display_configuration(config)
                  ui.indent("Updated: #{time_ago(config["updated_at"])}")
                  ui.blank
                end
              end
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "search QUERY", "Search public configurations"
          option :tag, type: :array, default: [], desc: "Filter by tags"
          def search(query = nil)
            tags = options[:tag] || []

            if query.nil? && tags.empty?
              ui.error("Please provide a search query or tags")
              exit EXIT_INVALID_INPUT
            end

            begin
              response = ui.spinner("Searching...") do
                api.search_configurations(query: query, tags: tags)
              end

              configs = response.is_a?(Array) ? response : response["configurations"]
              search_term = query ? "\"#{query}\"" : "tags: #{tags.join(", ")}"

              if configs.empty?
                ui.info("No configurations found for #{search_term}")
              else
                ui.header("Search results for #{search_term}:")
                ui.blank
                configs.each do |config|
                  ui.display_configuration(config, detailed: true)
                  ui.blank
                end
                ui.info("Found #{configs.length} configuration(s). Use `shai install <name>` to install.")
              end
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "install CONFIGURATION", "Install a configuration to local project"
          option :force, type: :boolean, aliases: "-f", default: false, desc: "Overwrite existing files"
          option :dry_run, type: :boolean, default: false, desc: "Show what would be installed"
          option :path, type: :string, default: ".", desc: "Install to specific directory"
          def install(configuration)
            owner, slug = parse_configuration_name(configuration)
            display_name = owner ? "#{owner}/#{slug}" : slug
            base_path = File.expand_path(options[:path])
            shairc_path = File.join(base_path, ".shairc")

            # Check if a configuration is already installed/initialized
            if File.exist?(shairc_path) && !options[:force]
              existing_config = begin
                YAML.safe_load_file(shairc_path)
              rescue
                {}
              end
              existing_slug = existing_config["slug"] || "unknown"

              ui.error("A configuration is already present in this directory.")
              ui.indent("Existing: #{existing_slug}")
              ui.blank
              ui.info("To install a different configuration:")
              ui.indent("1. Run `shai uninstall #{existing_slug}` to remove the current configuration")
              ui.indent("2. Then run `shai install #{display_name}`")
              ui.blank
              ui.info("Or use --force to install anyway (may cause conflicts)")
              exit EXIT_INVALID_INPUT
            end

            begin
              response = ui.spinner("Fetching #{display_name}...") do
                api.get_tree(slug)
              end

              tree = response["tree"]

              # Check for conflicts
              conflicts = []
              tree.each do |node|
                next if node["kind"] == "folder"

                local_path = File.join(base_path, node["path"])
                conflicts << node["path"] if File.exist?(local_path)
              end

              if options[:dry_run]
                ui.header("Would install:")
                tree.each { |node| ui.display_file_operation(:would_create, node["path"]) }
                ui.blank
                ui.info("No changes made (dry run)")
                return
              end

              # Handle conflicts
              if conflicts.any? && !options[:force]
                ui.blank
                ui.warning("The following files already exist:")
                conflicts.each { |path| ui.display_file_operation(:conflict, path) }
                ui.blank

                choice = ui.select("Overwrite existing files?", [
                  {name: "Yes", value: :yes},
                  {name: "No (abort)", value: :no},
                  {name: "Show diff", value: :diff}
                ])

                if choice == :diff
                  show_install_diff(tree, base_path, conflicts)
                  return unless ui.yes?("Overwrite existing files?")
                elsif choice == :no
                  ui.info("Installation cancelled")
                  return
                end
              end

              ui.header("Installing #{display_name}...")
              ui.blank

              # Create folders and files
              created_count = 0
              tree.sort_by { |n| (n["kind"] == "folder") ? 0 : 1 }.each do |node|
                local_path = File.join(base_path, node["path"])

                if node["kind"] == "folder"
                  FileUtils.mkdir_p(local_path)
                  ui.display_file_operation(:created, node["path"] + "/")
                else
                  FileUtils.mkdir_p(File.dirname(local_path))
                  File.write(local_path, node["content"])
                  ui.display_file_operation(:created, node["path"])
                end
                created_count += 1
              end

              ui.blank
              ui.success("Installed #{created_count} items")
            rescue NotFoundError
              ui.error("Configuration '#{display_name}' not found.")
              exit EXIT_NOT_FOUND
            rescue PermissionDeniedError
              ui.error("You don't have permission to access '#{display_name}'.")
              exit EXIT_PERMISSION_DENIED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "uninstall CONFIGURATION", "Remove an installed configuration from local project"
          option :dry_run, type: :boolean, default: false, desc: "Show what would be removed"
          option :path, type: :string, default: ".", desc: "Path where configuration is installed"
          def uninstall(configuration)
            require_auth!

            owner, slug = parse_configuration_name(configuration)
            display_name = owner ? "#{owner}/#{slug}" : slug

            begin
              response = ui.spinner("Fetching #{display_name}...") do
                api.get_tree(slug)
              end

              tree = response.is_a?(Array) ? response : response["tree"]
              base_path = File.expand_path(options[:path])

              # Find files that exist locally
              files_to_remove = []
              folders_to_remove = []

              tree.each do |node|
                local_path = File.join(base_path, node["path"])

                if node["kind"] == "folder"
                  folders_to_remove << node["path"] if Dir.exist?(local_path)
                elsif File.exist?(local_path)
                  files_to_remove << node["path"]
                end
              end

              if files_to_remove.empty? && folders_to_remove.empty?
                ui.info("No files from '#{display_name}' found in #{base_path}")
                return
              end

              if options[:dry_run]
                ui.header("Would remove:")
                files_to_remove.each { |path| ui.display_file_operation(:would_create, path) }
                folders_to_remove.sort.reverse_each { |path| ui.display_file_operation(:would_create, path + "/") }
                ui.blank
                ui.info("No changes made (dry run)")
                return
              end

              unless ui.yes?("Remove #{files_to_remove.length} files and #{folders_to_remove.length} folders from '#{display_name}'?")
                ui.info("Uninstall cancelled")
                return
              end

              ui.header("Uninstalling #{display_name}...")
              ui.blank

              # Remove files first
              files_to_remove.each do |path|
                local_path = File.join(base_path, path)
                File.delete(local_path)
                ui.display_file_operation(:deleted, path)
              end

              # Remove folders (deepest first)
              folders_to_remove.sort.reverse_each do |path|
                local_path = File.join(base_path, path)
                if Dir.exist?(local_path) && Dir.empty?(local_path)
                  Dir.rmdir(local_path)
                  ui.display_file_operation(:deleted, path + "/")
                end
              end

              ui.blank
              ui.success("Uninstalled #{display_name}")
            rescue NotFoundError
              ui.error("Configuration '#{display_name}' not found.")
              exit EXIT_NOT_FOUND
            rescue PermissionDeniedError
              ui.error("You don't have permission to access '#{display_name}'.")
              exit EXIT_PERMISSION_DENIED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end
        end
      end

      private

      def parse_configuration_name(name)
        if name.include?("/")
          name.split("/", 2)
        else
          [nil, name]
        end
      end

      def time_ago(timestamp)
        return "unknown" unless timestamp

        seconds = Time.now - Time.parse(timestamp)
        case seconds
        when 0..59
          "just now"
        when 60..3599
          "#{(seconds / 60).to_i} minutes ago"
        when 3600..86399
          hours = (seconds / 3600).to_i
          (hours == 1) ? "1 hour ago" : "#{hours} hours ago"
        when 86400..604799
          days = (seconds / 86400).to_i
          (days == 1) ? "yesterday" : "#{days} days ago"
        else
          Time.parse(timestamp).strftime("%B %-d, %Y")
        end
      rescue ArgumentError
        timestamp
      end

      def show_install_diff(tree, base_path, conflicts)
        require "diffy"

        conflicts.each do |path|
          local_path = File.join(base_path, path)
          local_content = File.read(local_path)
          remote_content = tree.find { |n| n["path"] == path }&.dig("content") || ""

          ui.info("--- local #{path}")
          ui.info("+++ remote #{path}")
          diff = Diffy::Diff.new(local_content, remote_content, context: 3)
          ui.diff(diff.to_s)
          ui.blank
        end
      end
    end
  end
end
