# frozen_string_literal: true

require "thor"
require_relative "commands/auth"
require_relative "commands/configurations"
require_relative "commands/sync"
require_relative "commands/config"
require_relative "ui"

module Shai
  class CLI < Thor
    include Commands::Auth
    include Commands::Configurations
    include Commands::Sync
    include Commands::Config

    def self.exit_on_failure?
      true
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
