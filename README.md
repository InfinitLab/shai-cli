# shai-cli

Command-line tool for managing and sharing AI agent configurations via [shaicli.dev](https://shaicli.dev).

## Installation

### Quick install (recommended)

```bash
curl -fsSL https://shaicli.dev/install.sh | bash
```

### Via RubyGems

```bash
gem install shai-cli
```

### From source

```bash
git clone https://github.com/infinitlab/shai-cli.git
cd shai-cli
bundle install
bundle exec rake install
```

## Quick Start

```bash
# Login to your shaicli.dev account
shai login

# Search for public configurations
shai search "claude code"

# Install a configuration to your project
shai install anthropic/claude-expert

# Create and share your own configuration
shai init
shai push
```

## Commands

### Authentication

| Command | Description |
|---------|-------------|
| `shai login` | Log in to shaicli.dev |
| `shai logout` | Log out and remove stored credentials |
| `shai whoami` | Show current authentication status |

```bash
$ shai whoami
Logged in as johndoe (John Doe)
Token expires: March 11, 2026

$ shai logout
✓ Logged out successfully
```

### Discovery

| Command | Description |
|---------|-------------|
| `shai list` | List your configurations |
| `shai search <query>` | Search public configurations |

### Using Configurations

| Command | Description |
|---------|-------------|
| `shai install <config>` | Install a configuration to local project |
| `shai uninstall <config>` | Remove an installed configuration |

```bash
$ shai uninstall anthropic/claude-expert
[✔] Fetching anthropic/claude-expert...
Remove 3 files and 1 folder from 'anthropic/claude-expert'? (y/N) y
Uninstalling anthropic/claude-expert...

  Deleted .claude/settings.json
  Deleted .claude/agents/BACKEND.md
  Deleted CLAUDE.md
  Deleted .claude/
  Deleted .shai-installed

✓ Uninstalled anthropic/claude-expert
```

### Authoring Configurations

| Command | Description |
|---------|-------------|
| `shai init` | Initialize a new configuration |
| `shai push` | Push local changes to remote |
| `shai status` | Show local changes vs remote |
| `shai diff` | Show diff between local and remote |
| `shai config show` | Show configuration details |
| `shai config set <key> <value>` | Update configuration metadata |
| `shai delete <slug>` | Delete a configuration from remote |

```bash
$ shai init
Configuration name: my-claude-setup
Description (optional): My personal Claude Code configuration
Visibility: public
Include paths (glob patterns, comma-separated): .claude,CLAUDE.md

[✔] Creating configuration...
✓ Created my-claude-setup
  Remote: https://shaicli.dev/johndoe/my-claude-setup

Next steps:
  1. Add or modify files matching your include patterns
  2. Run `shai push` to upload your configuration

$ shai push
Pushing to johndoe/my-claude-setup...

  Uploading .claude
  Uploading CLAUDE.md
[✔] Uploading...

✓ Pushed 2 items
  View at: https://shaicli.dev/johndoe/my-claude-setup

$ shai status
[✔] Fetching remote state...
Configuration: johndoe/my-claude-setup
Status: Local changes

Modified:
  CLAUDE.md

Run `shai push` to upload changes.

$ shai diff
[✔] Fetching remote state...
--- remote CLAUDE.md
+++ local CLAUDE.md
 Refer to .claude/agents for specialized agents.
+
+Added new guidelines for testing.

$ shai config show
[✔] Fetching configuration...
Configuration: my-claude-setup
Name: My Claude Setup
Description: My personal Claude Code configuration
Visibility: public
Owner: johndoe
Stars: 12
URL: https://shaicli.dev/johndoe/my-claude-setup
Created: December 11, 2025
Updated: December 11, 2025

$ shai config set description "Updated description"
[✔] Updating...
✓ Updated description to 'Updated description'

$ shai delete my-claude-setup
Are you sure you want to delete 'my-claude-setup'? This cannot be undone. (y/N) y
[✔] Deleting...
✓ Configuration 'my-claude-setup' deleted
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SHAI_API_URL` | API endpoint URL | `https://shaicli.dev` |
| `SHAI_CONFIG_DIR` | Directory for credentials | `~/.config/shai` |
| `SHAI_TOKEN` | Override authentication token | - |
| `NO_COLOR` | Disable colored output | - |

### .shairc File

When authoring configurations, a `.shairc` file is created in your project root:

```yaml
# .shairc - Shai configuration
slug: my-config
include:
  - .claude/**
  - .cursor/**
exclude:
  - "**/*.local.*"
  - "**/.env"
```

| Field | Description |
|-------|-------------|
| `slug` | Unique identifier for your configuration |
| `include` | Glob patterns for files to include |
| `exclude` | Glob patterns for files to exclude |

## Examples

### Install to specific directory

```bash
shai install anthropic/claude-expert --path ./my-project
```

### Preview installation without making changes

```bash
shai install anthropic/claude-expert --dry-run
```

### Force overwrite existing files

```bash
shai install anthropic/claude-expert --force
```

### Create a public configuration

```bash
shai init
# Follow prompts, select "public" visibility
shai push
```

### Update configuration metadata

```bash
shai config set name "My Updated Config"
shai config set visibility public
shai config set description "A better description"
```

## Development

### Setup

```bash
bundle install
```

### Run tests

```bash
bundle exec rspec
```

### Run linter

```bash
bundle exec standardrb
```

### Local development

Create `.env.development`:

```bash
SHAI_API_URL=http://localhost:3001
SHAI_CONFIG_DIR=.config/shai-dev
```

Run commands in development mode:

```bash
SHAI_ENV=development bundle exec bin/shai <command>
```

## License

MIT
