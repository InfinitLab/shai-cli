# frozen_string_literal: true

require "yaml"
require "diffy"

module Shai
  module Commands
    module Sync
      SHAIRC_FILE = ".shairc"

      def self.included(base)
        base.class_eval do
          desc "init", "Initialize a new configuration"
          def init
            require_auth!

            if File.exist?(SHAIRC_FILE)
              ui.error("A #{SHAIRC_FILE} file already exists in this directory.")
              ui.info("Use `shai push` to upload changes to the existing configuration.")
              exit EXIT_INVALID_INPUT
            end

            name = ui.ask("Configuration name:")
            description = ui.ask("Description (optional):")
            visibility = ui.select("Visibility:", %w[private public], default: "private")
            include_patterns = ui.ask("Include paths (glob patterns, comma-separated):", default: ".claude/**,.cursor/**")

            ui.blank

            begin
              response = ui.spinner("Creating configuration...") do
                api.create_configuration(
                  name: name,
                  description: description.to_s.empty? ? nil : description,
                  visibility: visibility
                )
              end

              config = response["configuration"] || response
              slug = config["slug"]
              username = credentials.username

              # Write .shairc file
              shairc_content = <<~YAML
                # .shairc - Shai configuration
                slug: #{slug}
                include:
                #{include_patterns.split(",").map { |p| "  - #{p.strip}" }.join("\n")}
                exclude:
                  - "**/*.local.*"
                  - "**/.env"
              YAML

              File.write(SHAIRC_FILE, shairc_content)

              ui.success("Created #{slug}")
              ui.indent("Remote: #{Shai.configuration.api_url}/#{username}/#{slug}")
              ui.blank
              ui.info("Next steps:")
              ui.indent("1. Add or modify files matching your include patterns")
              ui.indent("2. Run `shai push` to upload your configuration")
            rescue InvalidConfigurationError => e
              ui.error(e.message)
              exit EXIT_INVALID_INPUT
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "push", "Push local changes to remote"
          option :dry_run, type: :boolean, default: false, desc: "Show what would be pushed"
          option :message, type: :string, aliases: "-m", desc: "Add a message (future feature)"
          def push
            require_auth!

            shairc = load_shairc
            slug = shairc["slug"]

            # Build tree from local files
            tree = build_local_tree(shairc)

            if tree.empty?
              ui.warning("No files found matching include patterns.")
              ui.info("Check your .shairc include patterns.")
              exit EXIT_INVALID_INPUT
            end

            display_name = "#{credentials.username}/#{slug}"

            if options[:dry_run]
              ui.header("Would push to #{display_name}:")
              tree.each { |node| ui.display_file_operation(:uploaded, node[:path]) }
              ui.blank
              ui.info("No changes made (dry run)")
              return
            end

            ui.header("Pushing to #{display_name}...")
            ui.blank

            tree.each { |node| ui.display_file_operation(:uploaded, node[:path]) }

            begin
              ui.spinner("Uploading...") do
                api.update_tree(slug, tree)
              end

              ui.blank
              ui.success("Pushed #{tree.length} items")
              ui.indent("View at: #{Shai.configuration.api_url}/#{credentials.username}/#{slug}")
            rescue NotFoundError
              ui.error("Configuration '#{slug}' not found. Run `shai init` first.")
              exit EXIT_NOT_FOUND
            rescue PermissionDeniedError
              ui.error("You don't have permission to modify '#{display_name}'.")
              exit EXIT_PERMISSION_DENIED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "status", "Show local changes"
          def status
            require_auth!

            shairc = load_shairc
            slug = shairc["slug"]

            display_name = "#{credentials.username}/#{slug}"

            begin
              remote_tree = ui.spinner("Fetching remote state...") do
                api.get_tree(slug)["tree"]
              end

              local_tree = build_local_tree(shairc)

              # Compare trees
              remote_files = remote_tree.select { |n| n["kind"] == "file" }
                .each_with_object({}) { |n, h| h[n["path"]] = n["content"] }
              local_files = local_tree.select { |n| n[:kind] == "file" }
                .each_with_object({}) { |n, h| h[n[:path]] = n[:content] }

              modified = []
              new_files = []
              deleted = []

              local_files.each do |path, content|
                if remote_files.key?(path)
                  modified << path if remote_files[path] != content
                else
                  new_files << path
                end
              end

              remote_files.each_key do |path|
                deleted << path unless local_files.key?(path)
              end

              ui.header("Configuration: #{display_name}")

              if modified.empty? && new_files.empty? && deleted.empty?
                ui.info("Status: Up to date")
                ui.blank
                ui.info("No local changes detected.")
              else
                ui.info("Status: Local changes")
                ui.blank

                if modified.any?
                  ui.info("Modified:")
                  modified.each { |path| ui.indent(path) }
                  ui.blank
                end

                if new_files.any?
                  ui.info("New:")
                  new_files.each { |path| ui.indent(path) }
                  ui.blank
                end

                if deleted.any?
                  ui.info("Deleted (remote only):")
                  deleted.each { |path| ui.indent(path) }
                  ui.blank
                end

                ui.info("Run `shai push` to upload changes.")
              end
            rescue NotFoundError
              ui.error("Configuration '#{slug}' not found on remote.")
              exit EXIT_NOT_FOUND
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "pull", "Pull remote changes to local"
          option :dry_run, type: :boolean, default: false, desc: "Show what would be pulled"
          option :force, type: :boolean, default: false, aliases: "-f", desc: "Overwrite local files without prompting"
          def pull
            require_auth!

            shairc = load_shairc
            slug = shairc["slug"]

            display_name = "#{credentials.username}/#{slug}"

            begin
              remote_tree = ui.spinner("Fetching remote state...") do
                api.get_tree(slug)["tree"]
              end

              # Security: Validate all paths before any file operations
              validate_tree_paths!(remote_tree, Dir.pwd)

              local_tree = build_local_tree(shairc)

              # Build lookup maps
              remote_files = remote_tree.select { |n| n["kind"] == "file" }
                .each_with_object({}) { |n, h| h[n["path"]] = n["content"] }
              local_files = local_tree.select { |n| n[:kind] == "file" }
                .each_with_object({}) { |n, h| h[n[:path]] = n[:content] }

              # Categorize changes
              to_create = []
              to_update = []

              remote_files.each do |path, content|
                if local_files.key?(path)
                  to_update << {path: path, content: content} if local_files[path] != content
                else
                  to_create << {path: path, content: content}
                end
              end

              if to_create.empty? && to_update.empty?
                ui.info("Already up to date with #{display_name}")
                return
              end

              # Dry run mode
              if options[:dry_run]
                ui.header("Would pull from #{display_name}:")
                ui.blank
                to_create.each { |f| ui.display_file_operation(:would_create, f[:path]) }
                to_update.each { |f| ui.display_file_operation(:would_update, f[:path]) }
                ui.blank
                ui.info("No changes made (dry run)")
                return
              end

              # Check for conflicts (files that would be overwritten)
              unless options[:force] || to_update.empty?
                ui.warning("The following local files will be overwritten:")
                to_update.each { |f| ui.indent(f[:path]) }
                ui.blank

                unless ui.yes?("Continue and overwrite these files?")
                  ui.info("Pull cancelled.")
                  return
                end
              end

              # Apply changes
              ui.header("Pulling from #{display_name}...")
              ui.blank

              # Create necessary folders
              all_folders = Set.new
              (to_create + to_update).each do |file|
                parts = File.dirname(file[:path]).split("/")
                parts.each_with_index do |_, i|
                  folder_path = parts[0..i].join("/")
                  all_folders << folder_path unless folder_path == "."
                end
              end

              all_folders.sort.each do |folder|
                unless Dir.exist?(folder)
                  FileUtils.mkdir_p(folder)
                  ui.display_file_operation(:created, folder)
                end
              end

              # Create new files
              to_create.each do |file|
                File.write(file[:path], file[:content])
                ui.display_file_operation(:created, file[:path])
              end

              # Update existing files
              to_update.each do |file|
                File.write(file[:path], file[:content])
                ui.display_file_operation(:updated, file[:path])
              end

              ui.blank
              ui.success("Pulled #{to_create.length + to_update.length} items from #{display_name}")
            rescue NotFoundError
              ui.error("Configuration '#{slug}' not found on remote.")
              exit EXIT_NOT_FOUND
            rescue PermissionDeniedError
              ui.error("You don't have permission to access '#{display_name}'.")
              exit EXIT_PERMISSION_DENIED
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end

          desc "diff", "Show diff between local and remote"
          def diff
            require_auth!

            shairc = load_shairc
            slug = shairc["slug"]

            begin
              remote_tree = ui.spinner("Fetching remote state...") do
                api.get_tree(slug)["tree"]
              end

              local_tree = build_local_tree(shairc)

              remote_files = remote_tree.select { |n| n["kind"] == "file" }
                .each_with_object({}) { |n, h| h[n["path"]] = n["content"] }
              local_files = local_tree.select { |n| n[:kind] == "file" }
                .each_with_object({}) { |n, h| h[n[:path]] = n[:content] }

              has_diff = false

              # Modified files
              local_files.each do |path, content|
                if remote_files.key?(path) && remote_files[path] != content
                  has_diff = true
                  ui.info("--- remote #{path}")
                  ui.info("+++ local #{path}")
                  file_diff = Diffy::Diff.new(remote_files[path], content, context: 3)
                  ui.diff(file_diff.to_s)
                  ui.blank
                end
              end

              # New files
              local_files.each do |path, content|
                next if remote_files.key?(path)

                has_diff = true
                ui.info("--- /dev/null")
                ui.info("+++ local #{path}")
                file_diff = Diffy::Diff.new("", content, context: 3)
                ui.diff(file_diff.to_s)
                ui.blank
              end

              # Deleted files
              remote_files.each do |path, content|
                next if local_files.key?(path)

                has_diff = true
                ui.info("--- remote #{path}")
                ui.info("+++ /dev/null")
                file_diff = Diffy::Diff.new(content, "", context: 3)
                ui.diff(file_diff.to_s)
                ui.blank
              end

              ui.info("No differences found.") unless has_diff
            rescue NotFoundError
              ui.error("Configuration '#{slug}' not found on remote.")
              exit EXIT_NOT_FOUND
            rescue NetworkError => e
              ui.error(e.message)
              exit EXIT_NETWORK_ERROR
            end
          end
        end
      end

      private

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
          path = node["path"] || node[:path]
          unless safe_path?(path, base_path)
            raise SecurityError, "Invalid path detected: #{path.inspect}"
          end
        end
      end

      def load_shairc
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

      def build_local_tree(shairc)
        include_patterns = shairc["include"] || []
        exclude_patterns = shairc["exclude"] || []

        files = []
        folders = Set.new

        include_patterns.each do |pattern|
          Dir.glob(pattern).each do |path|
            next if File.directory?(path)
            next if excluded?(path, exclude_patterns)

            # Track folders
            parts = File.dirname(path).split("/")
            parts.each_with_index do |_, i|
              folder_path = parts[0..i].join("/")
              folders << folder_path unless folder_path == "."
            end

            files << {
              kind: "file",
              path: path,
              content: File.read(path)
            }
          end
        end

        tree = folders.sort.map { |f| {kind: "folder", path: f} }
        tree + files.sort_by { |f| f[:path] }
      end

      def excluded?(path, patterns)
        patterns.any? do |pattern|
          File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end
    end
  end
end
