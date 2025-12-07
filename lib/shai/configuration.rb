# frozen_string_literal: true

module Shai
  class Configuration
    attr_accessor :api_url, :config_dir, :token

    def initialize
      @api_url = ENV.fetch("SHAI_API_URL", "https://shai.dev")
      @config_dir = ENV.fetch("SHAI_CONFIG_DIR", default_config_dir)
      @token = ENV["SHAI_TOKEN"]
    end

    def credentials_path
      File.join(config_dir, "credentials")
    end

    def color_enabled?
      !ENV.key?("NO_COLOR")
    end

    private

    def default_config_dir
      if Gem.win_platform?
        File.join(ENV.fetch("APPDATA", Dir.home), "shai")
      else
        File.join(Dir.home, ".config", "shai")
      end
    end
  end
end
