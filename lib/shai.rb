# frozen_string_literal: true

require_relative "shai/version"
require_relative "shai/configuration"
require_relative "shai/credentials"
require_relative "shai/api_client"
require_relative "shai/installed_projects"
require_relative "shai/install_registry"
require_relative "shai/skill_scanner"
require_relative "shai/cli"

module Shai
  class Error < StandardError; end

  class AuthenticationError < Error; end

  class NotFoundError < Error; end

  class PermissionDeniedError < Error; end

  class NetworkError < Error; end

  class InvalidConfigurationError < Error; end

  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message = "Too many requests", retry_after: nil)
      @retry_after = retry_after
      super(message)
    end
  end

  class DeviceFlowError < Error
    attr_reader :error_code, :interval

    def initialize(error_code, interval: nil)
      @error_code = error_code
      @interval = interval
      super(error_code)
    end

    def authorization_pending?
      error_code == "authorization_pending"
    end

    def slow_down?
      error_code == "slow_down"
    end

    def access_denied?
      error_code == "access_denied"
    end

    def expired?
      error_code == "expired_token"
    end
  end

  # Exit codes as specified in tech spec
  EXIT_SUCCESS = 0
  EXIT_GENERAL_ERROR = 1
  EXIT_AUTH_REQUIRED = 2
  EXIT_PERMISSION_DENIED = 3
  EXIT_NOT_FOUND = 4
  EXIT_NETWORK_ERROR = 5
  EXIT_INVALID_INPUT = 6

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def credentials
      @credentials ||= Credentials.new
    end

    def api_client
      @api_client ||= ApiClient.new
    end

    def reset!
      @configuration = nil
      @credentials = nil
      @api_client = nil
    end
  end
end
