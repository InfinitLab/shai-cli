# frozen_string_literal: true

require "uri"

module Shai
  class Configuration
    class InsecureConnectionError < StandardError; end

    attr_accessor :config_dir, :token
    attr_reader :api_url

    def initialize
      self.api_url = ENV.fetch("SHAI_API_URL", "https://shai.dev")
      @config_dir = expand_path(ENV.fetch("SHAI_CONFIG_DIR", default_config_dir))
      @token = ENV["SHAI_TOKEN"]
    end

    def api_url=(url)
      validate_url_security!(url)
      @api_url = url
    end

    def credentials_path
      File.join(config_dir, "credentials")
    end

    def color_enabled?
      !ENV.key?("NO_COLOR")
    end

    private

    def validate_url_security!(url)
      uri = URI.parse(url)

      # Allow HTTP only for localhost/127.0.0.1 (development)
      return if uri.scheme == "https"
      return if uri.scheme == "http" && local_host?(uri.host)

      raise InsecureConnectionError,
        "HTTPS is required for API connections. " \
        "HTTP is only allowed for localhost/127.0.0.1 during development."
    end

    def local_host?(host)
      return false if host.nil?

      # Strip brackets from IPv6 addresses (e.g., "[::1]" -> "::1")
      normalized = host.downcase.delete("[]")
      %w[localhost 127.0.0.1 ::1].include?(normalized)
    end

    def default_config_dir
      if Gem.win_platform?
        File.join(ENV.fetch("APPDATA", Dir.home), "shai")
      else
        File.join(Dir.home, ".config", "shai")
      end
    end

    def expand_path(path)
      File.expand_path(path)
    end
  end
end
