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

            installed = InstalledProjects.new(base_path)

            # Check if this exact project is already installed
            if installed.has_project?(display_name) && !options[:force]
              ui.error("'#{display_name}' is already installed in this directory.")
              ui.info("Use --force to reinstall, or run `shai uninstall #{display_name}` first.")
              exit EXIT_INVALID_INPUT
            end

            # Check if a .shairc exists (authored config)
            if File.exist?(shairc_path) && !options[:force]
              existing_config = begin
                YAML.safe_load_file(shairc_path)
              rescue
                {}
              end
              existing_slug = existing_config["slug"]

              if existing_slug
                ui.error("This directory contains an authored configuration (.shairc).")
                ui.indent("Existing: #{existing_slug}")
                ui.blank
                ui.info("Installing here may cause conflicts with your authored config.")
                ui.info("Use --force to install anyway.")
                exit EXIT_INVALID_INPUT
              end
            end

            begin
              response = ui.spinner("Fetching #{display_name}...") do
                api.get_tree(display_name)
              end

              tree = response["tree"]

              # Security: Validate all paths before any file operations
              validate_tree_paths!(tree, base_path)

              # Get file paths from tree (excluding folders)
              new_files = tree.reject { |n| n["kind"] == "folder" }.map { |n| n["path"] }

              # Check for conflicts with existing local files
              local_conflicts = []
              tree.each do |node|
                next if node["kind"] == "folder"
                local_path = File.join(base_path, node["path"])
                local_conflicts << node["path"] if File.exist?(local_path)
              end

              # Check for conflicts with other installed projects
              project_conflicts = installed.find_conflicts(new_files)

              if options[:dry_run]
                ui.header("Would install:")
                tree.each { |node| ui.display_file_operation(:would_create, node["path"]) }

                if project_conflicts.any?
                  ui.blank
                  ui.warning("Would conflict with installed projects:")
                  project_conflicts.each do |file, owner|
                    ui.indent("#{file} (from #{owner})")
                  end
                end

                ui.blank
                ui.info("No changes made (dry run)")
                return
              end

              # Handle conflicts
              if (local_conflicts.any? || project_conflicts.any?) && !options[:force]
                ui.blank

                if project_conflicts.any?
                  ui.warning("The following files conflict with already installed projects:")
                  project_conflicts.each do |file, owner|
                    ui.indent("#{file} #{ui.dim("(from #{owner})")}")
                  end
                  ui.blank
                end

                other_local_conflicts = local_conflicts - project_conflicts.keys
                if other_local_conflicts.any?
                  ui.warning("The following local files will be overwritten:")
                  other_local_conflicts.each { |path| ui.display_file_operation(:conflict, path) }
                  ui.blank
                end

                choice = ui.select("How would you like to proceed?", [
                  {name: "Overwrite files (conflicting projects will be updated)", value: :yes},
                  {name: "Cancel installation", value: :no},
                  {name: "Show diff", value: :diff}
                ])

                if choice == :diff
                  show_install_diff(tree, base_path, local_conflicts)
                  return unless ui.yes?("Proceed with installation?")
                elsif choice == :no
                  ui.info("Installation cancelled")
                  return
                end
              end

              ui.header("Installing #{display_name}...")
              ui.blank

              # Remove conflicting files from their original projects
              if project_conflicts.any?
                affected_projects = project_conflicts.values.uniq
                affected_projects.each do |project_slug|
                  files_to_remove = project_conflicts.select { |_, owner| owner == project_slug }.keys
                  installed.remove_files_from_project(project_slug, files_to_remove)
                end
              end

              # Create folders and files
              created_files = []
              tree.sort_by { |n| (n["kind"] == "folder") ? 0 : 1 }.each do |node|
                local_path = File.join(base_path, node["path"])

                if node["kind"] == "folder"
                  FileUtils.mkdir_p(local_path)
                  ui.display_file_operation(:created, node["path"] + "/")
                else
                  FileUtils.mkdir_p(File.dirname(local_path))
                  File.write(local_path, node["content"])
                  ui.display_file_operation(:created, node["path"])
                  created_files << node["path"]
                end
              end

              # Track the installed project
              installed.add_project(display_name, created_files)

              # Record the install for analytics (fire and forget)
              begin
                api.record_install(display_name)
              rescue
                # Silently ignore install tracking errors
              end

              ui.blank
              ui.success("Installed #{display_name}")

              if installed.project_count > 1
                ui.indent("#{installed.project_count} configurations now installed in this directory")
              end
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

          desc "open CONFIGURATION", "Open a configuration in the browser"
          def open(configuration)
            owner, slug = parse_configuration_name(configuration)
            display_name = owner ? "#{owner}/#{slug}" : slug
            base_url = Shai.configuration.api_url

            # Fetch configuration details to determine ownership and visibility
            begin
              config = ui.spinner("Fetching #{display_name}...") do
                api.get_configuration(display_name)
              end

              config_owner = config["owner"]
              config_slug = config["slug"]
              visibility = config["visibility"]
              current_username = credentials.authenticated? ? credentials.username : nil

              # Determine the appropriate URL based on ownership
              if current_username && config_owner == current_username
                # User owns this config - open in configuration_projects
                url = "#{base_url}/configuration_projects/#{config_slug}"
              elsif visibility == "public"
                # Public config owned by someone else - open in explore
                url = "#{base_url}/explore/#{config_owner}/#{config_slug}"
              else
                # Private config not owned by user - can't access
                ui.error("Configuration '#{display_name}' is private and you don't have access.")
                exit EXIT_PERMISSION_DENIED
              end

              ui.info("Opening #{display_name} in browser...")

              begin
                require "launchy"
                Launchy.open(url)
              rescue LoadError
                ui.warning("Could not open browser automatically.")
                ui.info("Visit: #{url}")
              rescue Launchy::Error => e
                ui.warning("Could not open browser: #{e.message}")
                ui.info("Visit: #{url}")
              end
            rescue NotFoundError
              if owner
                ui.error("Configuration '#{display_name}' not found.")
                ui.info("It may be private or doesn't exist.")
              else
                ui.error("Configuration '#{display_name}' not found in your projects.")
                ui.info("Use 'owner/slug' format to open someone else's public configuration.")
              end
              exit EXIT_NOT_FOUND
            rescue PermissionDeniedError
              ui.error("You don't have permission to access '#{display_name}'.")
              ui.info("This configuration may be private.")
              exit EXIT_PERMISSION_DENIED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "uninstall [CONFIGURATION]", "Remove an installed configuration from local project"
          option :dry_run, type: :boolean, default: false, desc: "Show what would be removed"
          option :path, type: :string, default: ".", desc: "Path where configuration is installed"
          def uninstall(configuration = nil)
            base_path = File.expand_path(options[:path])
            installed = InstalledProjects.new(base_path)

            # If no configuration specified, determine which to uninstall
            if configuration.nil?
              if installed.empty?
                ui.error("No configurations installed in this directory.")
                ui.info("Usage: shai uninstall <configuration>")
                exit EXIT_INVALID_INPUT
              elsif installed.project_count == 1
                configuration = installed.project_slugs.first
                ui.info("Uninstalling #{configuration}...")
              else
                ui.info("Multiple configurations installed:")
                configuration = ui.select("Which configuration do you want to uninstall?",
                  installed.project_slugs.map { |s| {name: s, value: s} } + [{name: "Cancel", value: nil}])

                if configuration.nil?
                  ui.info("Uninstall cancelled")
                  return
                end
              end
            end

            owner, slug = parse_configuration_name(configuration)
            display_name = owner ? "#{owner}/#{slug}" : slug

            # Get files to remove - either from tracking or from remote tree
            tracked_files = installed.files_for_project(display_name)

            if tracked_files.empty?
              # Fall back to fetching from remote (for v1 migrations or manual installs)
              begin
                response = ui.spinner("Fetching #{display_name}...") do
                  api.get_tree(display_name)
                end

                tree = response.is_a?(Array) ? response : response["tree"]
                validate_tree_paths!(tree, base_path)

                tracked_files = tree.reject { |n| n["kind"] == "folder" }.map { |n| n["path"] }
              rescue NotFoundError
                ui.error("Configuration '#{display_name}' not found and no tracked files.")
                exit EXIT_NOT_FOUND
              rescue PermissionDeniedError
                ui.error("You don't have permission to access '#{display_name}'.")
                exit EXIT_PERMISSION_DENIED
              rescue NetworkError => e
                ui.error(e.message)
                exit EXIT_NETWORK_ERROR
              end
            end

            # Find files that exist locally
            files_to_remove = []
            folders_to_check = Set.new

            tracked_files.each do |path|
              local_path = File.join(base_path, path)
              if File.exist?(local_path)
                files_to_remove << path
                # Track parent folders for potential removal
                dir = File.dirname(path)
                while dir != "."
                  folders_to_check << dir
                  dir = File.dirname(dir)
                end
              end
            end

            if files_to_remove.empty?
              ui.info("No files from '#{display_name}' found in #{base_path}")

              # Still remove from tracking if it exists
              if installed.has_project?(display_name)
                installed.remove_project(display_name)
                installed.delete! if installed.empty?
              end
              return
            end

            if options[:dry_run]
              ui.header("Would remove:")
              files_to_remove.each { |path| ui.display_file_operation(:would_create, path) }
              ui.blank
              ui.info("No changes made (dry run)")
              return
            end

            unless ui.yes?("Remove #{files_to_remove.length} files from '#{display_name}'?")
              ui.info("Uninstall cancelled")
              return
            end

            ui.header("Uninstalling #{display_name}...")
            ui.blank

            # Remove files
            files_to_remove.each do |path|
              local_path = File.join(base_path, path)
              File.delete(local_path)
              ui.display_file_operation(:deleted, path)
            end

            # Remove empty folders (deepest first)
            folders_to_check.to_a.sort.reverse_each do |path|
              local_path = File.join(base_path, path)
              if Dir.exist?(local_path) && Dir.empty?(local_path)
                Dir.rmdir(local_path)
                ui.display_file_operation(:deleted, path + "/")
              end
            end

            # Update tracking
            installed.remove_project(display_name)

            # Remove tracking file if no more projects
            if installed.empty?
              installed.delete!
              ui.display_file_operation(:deleted, InstalledProjects::FILENAME)
            end

            ui.blank
            ui.success("Uninstalled #{display_name}")

            if installed.project_count > 0
              ui.indent("#{installed.project_count} configuration(s) still installed")
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

      # Security: Validate that a path is safe and doesn't escape base_path
      def safe_path?(path, base_path)
        return false if path.nil? || path.empty?
        return false if path.start_with?("/") # No absolute paths
        return false if path.include?("..") # No directory traversal
        return false if path.include?("\0") # No null bytes

        # Verify resolved path stays within base_path
        full_path = File.expand_path(path, base_path)
        full_path.start_with?(File.expand_path(base_path) + "/") || full_path == File.expand_path(base_path)
      end

      def validate_tree_paths!(tree, base_path)
        tree.each do |node|
          unless safe_path?(node["path"], base_path)
            raise SecurityError, "Invalid path detected: #{node["path"].inspect}"
          end
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
