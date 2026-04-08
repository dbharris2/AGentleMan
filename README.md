# Secret Agent Man

A macOS app for managing Claude Code and Codex agent sessions with a Slack-like interface.

## Features

- **Multi-agent management** — create, switch, rename, and remove agents across different project folders
- **Provider selection** — choose Claude or Codex per agent
- **Embedded terminal** — full interactive Claude Code or Codex CLI session via SwiftTerm
- **Split shell** — a second terminal below the agent session for running git/jj commands in the agent's directory
- **Colored diff view** — unified and side-by-side diff views with per-file filtering
- **PR status tracking** — live CI check status, additions/deletions, reviewer avatars, and PR state per folder via `gh` CLI
- **Ghostty theme support** — 460+ terminal themes bundled with the app (no Ghostty installation required)
- **Plans panel** — browse and read Claude Code plans, with Codex-aware fallback messaging
- **VCS integration** — shows jj commit descriptions or git branch names per folder
- **Session persistence** — agents and sessions survive app restarts with provider-specific resume/recovery behavior
- **Auto mode** — Claude launches with `--enable-auto-mode`; Codex launches with `--full-auto`
- **Collapsible folders** — sidebar folder sections collapse to hide agents, with open/closed folder icons
- **Keyboard shortcuts** — Cmd+1-9 to switch agents, Cmd+N for new agent
- **Provider-aware metadata** — skills/plugins/settings adapt to the selected provider

## Requirements

- macOS 14.0+
- [Claude Code](https://claude.ai/download) CLI and/or Codex CLI installed
- [`gh` CLI](https://cli.github.com) (optional, for PR status tracking)

## Setup

```bash
brew install xcodegen just   # If not already installed
just xcode                   # Generates project + opens in Xcode
```

## Building

```bash
just build    # Generate project + build
just run      # Build + launch app
just test     # Run unit tests
just lint     # Check formatting + linting
just format   # Auto-fix formatting
just clean    # Remove build artifacts
```

## Installation

Download the latest release from [Releases](https://github.com/dbharris2/SecretAgentMan/releases), extract the zip, and move **SecretAgentMan.app** to your Applications folder.

Before opening, run this in Terminal to remove the quarantine flag:

```bash
xattr -cr /Applications/SecretAgentMan.app
```

## Architecture

- **SwiftUI** with three-column `NavigationSplitView`
- **SwiftTerm** for embedded terminal emulation
- **MarkdownUI** for plan rendering
- **XcodeGen** for project generation

```
Sources/SecretAgentMan/
  SecretAgentManApp.swift          — App entry point
  Models/                          — Agent, AgentState, FileChange, PRCheckStatus
  Services/                        — Process management, diff, themes, PR status, shell
  ViewModels/                      — AgentStore (observable state)
  Views/
    Sidebar/                       — Activity bar, agent list, plan list
    Center/                        — Diff views, plan detail, changes
    Terminal/                      — Agent terminal, shell terminal
    Common/                        — Persistent split view, status badge
```

## Data Storage

- **Agent config** — `~/Library/Application Support/SecretAgentMan/agents.json`
- **Settings** — UserDefaults (theme, Claude plugin directory, selected agent, split positions)
- **Sessions** — Claude sessions in `~/.claude/projects/`, Codex sessions in `~/.codex/sessions/`

## License

MIT
