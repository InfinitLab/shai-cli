# frozen_string_literal: true

require_relative "lib/shai/version"

Gem::Specification.new do |spec|
  spec.name = "shai-cli"
  spec.version = Shai::VERSION
  spec.authors = ["Sebastian Jimenez"]
  spec.email = ["sebastian@infinitlab.co"]

  spec.summary = "CLI tool for managing shared AI agent configurations"
  spec.description = "A command-line interface for shaicli.dev - download, share, and sync AI agent configurations (Claude, Cursor, etc.) across projects and teams."
  spec.homepage = "https://shaicli.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/infinitlab/shai-cli"
  spec.metadata["changelog_uri"] = "https://github.com/infinitlab/shai-cli/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob(%w[
    lib/**/*.rb
    bin/*
    LICENSE
    README.md
  ])
  spec.bindir = "bin"
  spec.executables = ["shai"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "faraday", "~> 2.9"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-spinner", "~> 0.9"
  spec.add_dependency "tty-table", "~> 0.12"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "diffy", "~> 3.4"
end
