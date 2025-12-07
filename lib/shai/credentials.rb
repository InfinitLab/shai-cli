# frozen_string_literal: true

require "json"
require "fileutils"

module Shai
  class Credentials
    attr_reader :token, :expires_at, :user

    def initialize
      load_credentials
    end

    def authenticated?
      !!(token && !expired?)
    end

    def expired?
      return true unless expires_at

      Time.parse(expires_at) < Time.now
    end

    def save(token:, expires_at:, user:)
      @token = token
      @expires_at = expires_at
      @user = user

      ensure_config_dir
      File.write(credentials_path, credentials_json)
      File.chmod(0o600, credentials_path)
    end

    def clear
      @token = nil
      @expires_at = nil
      @user = nil

      FileUtils.rm_f(credentials_path)
    end

    def username
      user&.dig("username")
    end

    def display_name
      user&.dig("display_name")
    end

    private

    def load_credentials
      return unless File.exist?(credentials_path)

      data = JSON.parse(File.read(credentials_path))
      @token = data["token"]
      @expires_at = data["expires_at"]
      @user = data["user"]
    rescue JSON::ParserError
      clear
    end

    def credentials_json
      JSON.pretty_generate({
        token: token,
        expires_at: expires_at,
        user: user
      })
    end

    def credentials_path
      Shai.configuration.credentials_path
    end

    def ensure_config_dir
      FileUtils.mkdir_p(File.dirname(credentials_path))
    end
  end
end
