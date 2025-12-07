# frozen_string_literal: true

require "pastel"
require "tty-prompt"
require "tty-spinner"
require "tty-table"

module Shai
  class UI
    def initialize(color: true)
      @pastel = Pastel.new(enabled: color)
      @prompt = TTY::Prompt.new
    end

    # Output helpers
    def success(message)
      puts @pastel.green("✓ #{message}")
    end

    def error(message)
      puts @pastel.red("Error: #{message}")
    end

    def warning(message)
      puts @pastel.yellow("Warning: #{message}")
    end

    def info(message)
      puts message
    end

    def blank
      puts
    end

    def header(title)
      puts @pastel.bold(title)
    end

    def indent(text, spaces: 2)
      prefix = " " * spaces
      puts text.lines.map { |line| "#{prefix}#{line}" }.join
    end

    # Formatting
    def dim(text)
      @pastel.dim(text)
    end

    def bold(text)
      @pastel.bold(text)
    end

    def cyan(text)
      @pastel.cyan(text)
    end

    def yellow(text)
      @pastel.yellow(text)
    end

    def green(text)
      @pastel.green(text)
    end

    def red(text)
      @pastel.red(text)
    end

    # Interactive prompts
    def ask(question, **options)
      @prompt.ask(question, **options)
    end

    def mask(question, **options)
      @prompt.mask(question, **options)
    end

    def yes?(question, default: false)
      @prompt.yes?(question, default: default)
    end

    def select(question, choices, **options)
      @prompt.select(question, choices, **options)
    end

    # Spinner for async operations
    def spinner(message)
      spinner = TTY::Spinner.new("[:spinner] #{message}", format: :dots)
      spinner.auto_spin
      result = yield
      spinner.success
      result
    rescue => e
      spinner.error
      raise e
    end

    # Table output
    def table(headers, rows)
      table = TTY::Table.new(header: headers, rows: rows)
      puts table.render(:unicode, padding: [0, 1])
    end

    # Diff output
    def diff(text)
      text.each_line do |line|
        case line[0]
        when "+"
          puts @pastel.green(line)
        when "-"
          puts @pastel.red(line)
        when "@"
          puts @pastel.cyan(line)
        else
          puts line
        end
      end
    end

    # Configuration display
    def display_configuration(config, detailed: false)
      name = config["slug"] || config["name"]
      owner = config.dig("owner", "username")
      full_name = owner ? "#{owner}/#{name}" : name
      visibility = config["visibility"]
      stars = config["stars_count"] || 0
      description = config["description"]

      line = "  #{full_name}"
      line += " (#{visibility})" if visibility == "private"
      line += " #{yellow("★")} #{stars}" if stars.positive?
      puts line

      if description && !description.empty?
        puts "  #{dim(description)}"
      end

      if detailed
        tags = config["tags"] || []
        puts "  #{dim("Tags: #{tags.join(", ")}")}" if tags.any?
      end
    end

    # Tree display
    def display_tree(items, prefix: "")
      items.each_with_index do |item, index|
        is_last = index == items.length - 1
        connector = is_last ? "└── " : "├── "
        puts "#{prefix}#{connector}#{item}"
      end
    end

    # File operation display
    def display_file_operation(operation, path)
      case operation
      when :created
        puts "  #{green("Created")} #{path}"
      when :modified
        puts "  #{yellow("Modified")} #{path}"
      when :deleted
        puts "  #{red("Deleted")} #{path}"
      when :uploaded
        puts "  #{cyan("Uploading")} #{path}"
      when :would_create
        puts "  #{path}"
      when :conflict
        puts "  #{red(path)}"
      end
    end
  end
end
