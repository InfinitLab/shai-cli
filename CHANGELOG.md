# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Skills Management**: New `shai skills` command to list, enable, and disable AI agent skills. Scans multiple agent directories (Claude: `.claude/skills/`, Codex: `.agents/skills/`) in both global (`~/`) and local (`./`) scopes. Use `--agent` to target a specific agent. Disabling a skill renames `SKILL.md` to `SKILL.md.disabled` to hide it from the agent's discovery without deleting it.
- **Global vs Local Installs**: `shai install` now supports `--global` (install to `~/`) and `--local` (install to `./`) flags. When neither is specified, the CLI prompts the user to choose. Global installs are useful for AI agent config files that should apply across all projects.
- **Install Registry**: A central registry at `~/.config/shai/installations.yml` tracks where each configuration was installed. `shai uninstall` now automatically finds the right directory without needing `--path`.

### Changed

- `shai uninstall` no longer requires `--path` — it resolves the install location from the registry. `--global` and `--local` flags are available as overrides.
- `shai install --path` no longer defaults to `.` — if no location flag is provided, the user is prompted.

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
