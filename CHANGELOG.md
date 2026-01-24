# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-01-24

### Added

- **Device Authorization Flow**: New `shai login --device` command for secure browser-based authentication using OAuth 2.0 Device Authorization Grant (RFC 8628). Ideal for environments where entering credentials in the terminal is not preferred.
- **Multi-Project Installs**: Install multiple configurations in the same directory without conflicts. Track which files belong to which project with automatic conflict detection and resolution.
- **Open Command**: New `shai open <configuration>` command to quickly open a configuration in your web browser. Automatically determines the correct URL based on ownership and visibility.
- **Install Analytics**: Successful installations are now tracked to show popularity metrics on the web platform.

### Changed

- Improved installation flow with better conflict handling between multiple installed projects
- Enhanced error messages for authentication and permission issues

## [0.1.1] - 2025-12-15

### Changed

- `shai search`, `shai install`, and `shai uninstall` now work without authentication for public configurations
- Updated README to clarify which commands require login

## [0.1.0] - 2024-12-09

### Added

- Initial release
- Authentication commands: `login`, `logout`, `whoami`
- Discovery commands: `list`, `search`
- Installation commands: `install`, `uninstall`
- Authoring commands: `init`, `push`, `pull`, `status`, `diff`
- Configuration management: `config show`, `config set`, `delete`
- Support for `owner/slug` format for cross-user configuration access
- HTTPS enforcement for API connections (HTTP allowed for localhost only)
- Path traversal protection for file operations
- Secure credential storage with proper file permissions

### Security

- Credentials stored with 0600 permissions
- HTTPS required for all non-localhost API connections
- Path validation prevents directory traversal attacks
