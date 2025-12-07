# frozen_string_literal: true

module ApiHelpers
  def stub_login_success(identifier: "test@example.com", username: "testuser")
    stub_request(:post, "https://shai.dev/api/v1/cli/session")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          data: {
            token: "test-token-123",
            expires_at: (Time.now + 365 * 24 * 60 * 60).iso8601,
            user: {
              id: 1,
              username: username,
              display_name: "Test User",
              avatar_url: nil
            }
          }
        }.to_json
      )
  end

  def stub_login_failure
    stub_request(:post, "https://shai.dev/api/v1/cli/session")
      .to_return(
        status: 401,
        headers: {"Content-Type" => "application/json"},
        body: {error: "Invalid credentials"}.to_json
      )
  end

  def stub_list_configurations(configurations: [])
    stub_request(:get, "https://shai.dev/api/v1/configurations")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {configurations: configurations}.to_json
      )
  end

  def stub_search_configurations(query: nil, configurations: [])
    url = "https://shai.dev/api/v1/configurations/search"
    url += "?q=#{query}" if query

    stub_request(:get, url)
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {configurations: configurations}.to_json
      )
  end

  def stub_get_tree(slug:, tree: [])
    stub_request(:get, "https://shai.dev/api/v1/configurations/#{slug}/tree")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {tree: tree}.to_json
      )
  end

  def stub_update_tree(slug:)
    stub_request(:put, "https://shai.dev/api/v1/configurations/#{slug}/tree")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {message: "Tree replaced successfully"}.to_json
      )
  end

  def stub_create_configuration(name:, slug:)
    stub_request(:post, "https://shai.dev/api/v1/configurations")
      .to_return(
        status: 201,
        headers: {"Content-Type" => "application/json"},
        body: {
          configuration: {
            id: 1,
            name: name,
            slug: slug,
            visibility: "private",
            description: nil,
            stars_count: 0
          }
        }.to_json
      )
  end

  def stub_get_configuration(slug:, config: nil)
    config ||= {
      id: 1,
      name: "Test Config",
      slug: slug,
      visibility: "private",
      description: "A test configuration",
      stars_count: 5,
      created_at: Time.now.iso8601,
      updated_at: Time.now.iso8601
    }

    stub_request(:get, "https://shai.dev/api/v1/configurations/#{slug}")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {configuration: config}.to_json
      )
  end

  def stub_update_configuration(slug:)
    stub_request(:put, "https://shai.dev/api/v1/configurations/#{slug}")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {message: "Configuration updated"}.to_json
      )
  end

  def stub_delete_configuration(slug:)
    stub_request(:delete, "https://shai.dev/api/v1/configurations/#{slug}")
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {message: "Configuration deleted"}.to_json
      )
  end

  def stub_not_found(path)
    stub_request(:get, "https://shai.dev#{path}")
      .to_return(
        status: 404,
        headers: {"Content-Type" => "application/json"},
        body: {error: "Not found"}.to_json
      )
  end

  def stub_permission_denied(path)
    stub_request(:get, "https://shai.dev#{path}")
      .to_return(
        status: 403,
        headers: {"Content-Type" => "application/json"},
        body: {error: "Permission denied"}.to_json
      )
  end
end

RSpec.configure do |config|
  config.include ApiHelpers
end
