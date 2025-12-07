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
