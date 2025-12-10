# frozen_string_literal: true

require "faraday"
require "json"
require "uri"

module Shai
  class ApiClient
    def initialize
      @connection = build_connection
    end

    # Authentication
    def login(identifier:, password:, client_name: nil)
      client_name ||= default_client_name
      post("/api/v1/cli/session", {
        identifier: identifier,
        password: password,
        client_name: client_name
      })
    end

    # Configurations
    def list_configurations
      get("/api/v1/configurations")
    end

    def search_configurations(query: nil, tags: [])
      params = {}
      params[:q] = query if query
      params["tags[]"] = tags if tags.any?
      get("/api/v1/configurations/search", params)
    end

    def get_configuration(identifier)
      get("/api/v1/configurations/#{encode_identifier(identifier)}")
    end

    def create_configuration(name:, description: nil, visibility: "private")
      post("/api/v1/configurations", {
        configuration: {
          name: name,
          description: description,
          visibility: visibility
        }
      })
    end

    def update_configuration(identifier, **attributes)
      put("/api/v1/configurations/#{encode_identifier(identifier)}", {
        configuration: attributes
      })
    end

    def delete_configuration(identifier)
      delete("/api/v1/configurations/#{encode_identifier(identifier)}")
    end

    def get_tree(identifier)
      get("/api/v1/configurations/#{encode_identifier(identifier)}/tree")
    end

    def update_tree(identifier, tree)
      put("/api/v1/configurations/#{encode_identifier(identifier)}/tree", {tree: tree})
    end

    # Encode identifier for URL (handles owner/slug format)
    def encode_identifier(identifier)
      URI.encode_www_form_component(identifier)
    end

    private

    def build_connection
      Faraday.new(url: Shai.configuration.api_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

    def get(path, params = {})
      response = @connection.get(path, params) do |req|
        add_auth_header(req)
      end
      handle_response(response)
    end

    def post(path, body)
      response = @connection.post(path) do |req|
        add_auth_header(req)
        req.body = body
      end
      handle_response(response)
    end

    def put(path, body)
      response = @connection.put(path) do |req|
        add_auth_header(req)
        req.body = body
      end
      handle_response(response)
    end

    def delete(path)
      response = @connection.delete(path) do |req|
        add_auth_header(req)
      end
      handle_response(response)
    end

    def add_auth_header(request)
      token = Shai.configuration.token || Shai.credentials.token
      request.headers["Authorization"] = "Bearer #{token}" if token
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 401
        raise AuthenticationError, response.body&.dig("error") || "Authentication failed"
      when 403
        raise PermissionDeniedError, response.body&.dig("error") || "Permission denied"
      when 404
        raise NotFoundError, response.body&.dig("error") || "Not found"
      when 422
        raise InvalidConfigurationError, response.body&.dig("error") || "Invalid request"
      else
        raise Error, response.body&.dig("error") || "Request failed with status #{response.status}"
      end
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError
      raise NetworkError, "Could not connect to #{Shai.configuration.api_url}. Check your internet connection."
    end

    def default_client_name
      hostname = begin
        require "socket"
        Socket.gethostname
      rescue
        "Unknown"
      end
      "CLI (#{hostname})"
    end
  end
end
