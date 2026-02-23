# frozen_string_literal: true

require "thor"
require_relative "commands/auth"
require_relative "commands/configurations"
require_relative "commands/sync"
require_relative "commands/config"
require_relative "commands/skills"
require_relative "ui"

module Shai
  class CLI < Thor
    include Commands::Auth
    include Commands::Configurations
    include Commands::Sync
    include Commands::Config
    include Commands::Skills

    def self.exit_on_failure?
      true
    end

    # Custom help to group commands by category
    def self.help(shell, subcommand = false)
      shell.say "shai - Manage AI agent configurations"
      shell.say ""
      shell.say "USAGE:"
      shell.say "  shai <command> [options]"
      shell.say ""
      shell.say "AUTHENTICATION:"
      shell.say "  login              Log in via browser (device flow)"
      shell.say "  login --password   Log in with email/password directly"
      shell.say "  logout             Log out and remove stored credentials"
      shell.say "  whoami             Show current authentication status"
      shell.say ""
      shell.say "DISCOVERY:"
      shell.say "  list               List your configurations"
      shell.say "  search <query>     Search public configurations"
      shell.say "  open <config>      Open a configuration in the browser"
      shell.say ""
      shell.say "USING CONFIGURATIONS:"
      shell.say "  install <config>   Install a configuration (--global, --local, or --path)"
      shell.say "  uninstall <config> Remove an installed configuration"
      shell.say ""
      shell.say "SKILLS:"
      shell.say "  skills             List all AI agent skills and their status"
      shell.say "  skills enable <n>  Enable a disabled skill (--global, --local, --agent)"
      shell.say "  skills disable <n> Disable an enabled skill (--global, --local, --agent)"
      shell.say ""
      shell.say "AUTHORING CONFIGURATIONS (create and publish):"
      shell.say "  init               Initialize a new configuration"
      shell.say "  push               Push local changes to remote"
      shell.say "  status             Show local changes vs remote"
      shell.say "  diff               Show diff between local and remote"
      shell.say "  config show        Show configuration details"
      shell.say "  config set <k> <v> Update configuration metadata"
      shell.say "  delete <slug>      Delete a configuration from remote"
      shell.say ""
      shell.say "OPTIONS:"
      shell.say "  -h, --help         Show help for a command"
      shell.say "  -v, --version      Show version"
      shell.say "  --verbose          Enable verbose output"
      shell.say "  --no-color         Disable colored output"
      shell.say ""
      shell.say "EXAMPLES:"
      shell.say "  shai login"
      shell.say "  shai search \"claude code\""
      shell.say "  shai open anthropic/claude-expert"
      shell.say "  shai install anthropic/claude-expert"
      shell.say "  shai init"
      shell.say "  shai push"
      shell.say ""
      shell.say "Run 'shai help <command>' for more information on a command."
    end

    class_option :verbose, type: :boolean, default: false, desc: "Enable verbose output"
    class_option :no_color, type: :boolean, default: false, desc: "Disable colored output"

    desc "version", "Show version"
    map %w[-v --version] => :version
    def version
      puts "shai #{Shai::VERSION}"
    end

    private

    def ui
      @ui ||= UI.new(color: !options[:no_color])
    end

    def api
      Shai.api_client
    end

    def credentials
      Shai.credentials
    end

    def require_auth!
      return if credentials.authenticated?

      ui.error("Not logged in. Run `shai login` to authenticate.")
      exit EXIT_AUTH_REQUIRED
    end
  end
end
