# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rake", "~> 13.0"
  gem "standard", "~> 1.40"
  gem "rubocop-rake", require: false
  gem "rubocop-rspec", require: false
end

group :test do
  gem "rspec", "~> 3.13"
  gem "factory_bot", "~> 6.4"
  gem "webmock", "~> 3.23"
  gem "simplecov", require: false
  gem "vcr", "~> 6.2"
end
