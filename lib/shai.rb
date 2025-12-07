# frozen_string_literal: true

require_relative "shai/version"
require_relative "shai/configuration"
require_relative "shai/credentials"
require_relative "shai/api_client"
require_relative "shai/cli"

module Shai
  class Error < StandardError; end

  class AuthenticationError < Error; end

  class NotFoundError < Error; end

  class PermissionDeniedError < Error; end

  class NetworkError < Error; end

  class InvalidConfigurationError < Error; end

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
