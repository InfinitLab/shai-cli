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

### Search by tags

```bash
shai search --tag claude --tag coding
```

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
