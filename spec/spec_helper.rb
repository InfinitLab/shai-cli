# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
end

require "shai"
require "factory_bot"
require "webmock/rspec"
require "vcr"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:each) do
    # Reset Shai module state between tests
    Shai.reset!

    # Use a temp directory for credentials in tests
    temp_config_dir = Dir.mktmpdir("shai-test")
    Shai.configure do |c|
      c.config_dir = temp_config_dir
      c.api_url = "https://shai.dev"
    end
  end

  config.after(:each) do
    # Clean up temp directories
    FileUtils.rm_rf(Shai.configuration.config_dir) if Shai.configuration&.config_dir&.include?("shai-test")
  end

  # Disable external HTTP requests
  WebMock.disable_net_connect!(allow_localhost: true)

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
