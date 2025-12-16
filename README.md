# shai-cli

Command-line tool for creating, sharing, and installing AI agent configurations.

shai lets you treat AI configurations like dotfiles: reproducible, shareable, and easy to install across machines.

Website: https://shaicli.dev

---

## Why this exists

I kept tweaking AI prompts, agent setups, and configuration files, then losing track of what actually worked. Copy-pasting from notes, Slack, or old repos didn’t scale.

shai is a small tool I built to make AI configurations:

- **Reproducible** (same setup everywhere)
- **Shareable** (public or private)
- **Easy to install** (one command)

This is an early project and intentionally minimal. It’s built to solve a real problem I had, and I’m sharing it to see if it’s useful to others.

---

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

---

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

---

## Commands

### No Login Required

These commands work without authentication for public configurations:

| Command                   | Description                                            |
| ------------------------- | ------------------------------------------------------ |
| `shai search <query>`     | Search public configurations                           |
| `shai install <config>`   | Install a public configuration (use `owner/slug` format) |
| `shai uninstall <config>` | Uninstall a public configuration                       |

```bash
# No login needed for public configs
shai search "claude code"
shai install anthropic/claude-expert
shai uninstall anthropic/claude-expert
```

---

### Authentication

| Command       | Description                           |
| ------------- | ------------------------------------- |
| `shai login`  | Log in to shaicli.dev                 |
| `shai logout` | Log out and remove stored credentials |
| `shai whoami` | Show current authentication status    |

```bash
$ shai whoami
Logged in as johndoe (John Doe)
Token expires: March 11, 2026
```

---

### Discovery

| Command               | Description                  |
| --------------------- | ---------------------------- |
| `shai list`           | List your configurations     |
| `shai search <query>` | Search public configurations |

---

### Using Configurations

| Command                   | Description                              |
| ------------------------- | ---------------------------------------- |
| `shai install <config>`   | Install a configuration to local project |
| `shai uninstall <config>` | Remove an installed configuration        |

```bash
$ shai uninstall anthropic/claude-expert
[✔] Fetching anthropic/claude-expert...
Remove 3 files and 1 folder from 'anthropic/claude-expert'? (y/N) y

✓ Uninstalled anthropic/claude-expert
```

---

### Authoring Configurations

| Command                         | Description                        |
| ------------------------------- | ---------------------------------- |
| `shai init`                     | Initialize a new configuration     |
| `shai push`                     | Push local changes to remote       |
| `shai status`                   | Show local changes vs remote       |
| `shai diff`                     | Show diff between local and remote |
| `shai config show`              | Show configuration details         |
| `shai config set <key> <value>` | Update configuration metadata      |
| `shai delete <slug>`            | Delete a configuration from remote |

---

## Configuration

### Environment Variables

| Variable          | Description                   | Default               |
| ----------------- | ----------------------------- | --------------------- |
| `SHAI_API_URL`    | API endpoint URL              | `https://shaicli.dev` |
| `SHAI_CONFIG_DIR` | Directory for credentials     | `~/.config/shai`      |
| `SHAI_TOKEN`      | Override authentication token | -                     |
| `NO_COLOR`        | Disable colored output        | -                     |

---

### .shairc File

When authoring configurations, a `.shairc` file is created in your project root:

```yaml
slug: my-config
include:
  - .claude/**
  - .cursor/**
exclude:
  - "**/*.local.*"
  - "**/.env"
```

| Field     | Description                              |
| --------- | ---------------------------------------- |
| `slug`    | Unique identifier for your configuration |
| `include` | Glob patterns for files to include       |
| `exclude` | Glob patterns for files to exclude       |

---

## Examples

```bash
# Install to a specific directory
shai install anthropic/claude-expert --path ./my-project

# Preview installation without making changes
shai install anthropic/claude-expert --dry-run

# Force overwrite existing files
shai install anthropic/claude-expert --force
```

---

## Feedback and discussion

Feedback is very welcome.

- Use **GitHub Discussions** for ideas, use cases, or open-ended thoughts
- Use **Issues** for concrete bugs, confusing behavior, or specific improvements

There are two pinned issues to guide feedback:

- **Feedback** — what’s unclear, missing, or not useful
- **Ideas** — possible improvements or directions

This project is intentionally small, so not every idea will be built. The goal right now is learning and signal.

---

## Development

```bash
bundle install
bundle exec rspec
bundle exec standardrb
```

Local development:

```bash
SHAI_API_URL=http://localhost:3001
SHAI_CONFIG_DIR=.config/shai-dev
SHAI_ENV=development bundle exec bin/shai <command>
```

---

## License

MIT
