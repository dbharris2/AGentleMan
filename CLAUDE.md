# SecretAgentMan

A macOS app for managing multiple Claude Code agent sessions with a Slack-like interface.

## Tech Stack

- SwiftUI with NavigationSplitView (macOS 14+)
- SwiftTerm for embedded terminal emulation
- XcodeGen for project generation

## Setup

```bash
brew install xcodegen just   # If not already installed
just xcode                   # Generates project + opens in Xcode
```

## Project Structure

- `Sources/SecretAgentMan/` - Main app source code
  - `SecretAgentManApp.swift` - App entry point with three-column layout
  - `Models/` - Data models (Agent, AgentState, FileChange)
  - `Services/` - Process management, diff service, session watcher
  - `ViewModels/` - AgentStore (observable state)
  - `Views/` - SwiftUI views organized by panel (Sidebar, Center, Terminal, Common)
- `Resources/` - Info.plist, entitlements, assets
- `project.yml` - XcodeGen project specification

## Common Commands

```bash
just build    # Generate project + build
just run      # Build + launch app
just lint     # Check formatting + linting
just format   # Auto-fix formatting
just clean    # Remove build artifacts
just xcode    # Open in Xcode
```
