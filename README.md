# Kyle's Claude Code Plugins

Personal agents, skills, and commands for Claude Code.

## Installation

Add this marketplace to Claude Code:

```bash
# Claude Code will prompt to add the marketplace
# Or manually add to ~/.claude/plugins/known_marketplaces.json
```

## Contents

### Agents (`agents/`)

- **beadsmith** - Decomposes specs into implementable task beads (runs in isolated context)

### Skills (`skills/`)

- **beadsmith** - Auto-activates on work decomposition discussions, guides when/how to use beadsmith

### Commands (`commands/`)

- `/beadsmith <bead-id>` - Shortcut to decompose an epic, feature, or bug into tasks

## Development

This repo is managed as a Gas Town rig at `~/gt/claude_plugins/`.

Changes are automatically detected by Claude Code when pushed to main.
