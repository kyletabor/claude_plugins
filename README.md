# Kyle's Claude Code Plugins

Personal agents, skills, and commands for Claude Code.

## Installation

Add this marketplace to Claude Code:

```bash
# Claude Code will prompt to add the marketplace
# Or manually add to ~/.claude/plugins/known_marketplaces.json
```

## Dependencies

This plugin uses the following Claude Code features:

- **Task tool with subagents** - Architect uses Explore and Plan subagents
- **beads (`bd` command)** - All agents create/manage beads for work tracking

## The Workflow

```
Epic → Architect → Architecture Bead → Beadmeister → Task Beads → Polecats
```

## Contents

### Agents (`agents/`)

- **architect** - Takes an epic/PRD, explores codebase, designs architecture, creates implementation legs. Does multi-pass exploration before decomposition.
- **beadmeister** - Takes legs from Architect, creates execution-ready task beads with step-by-step instructions for polecats.

### Skills (`skills/`)

- **beadmeister** - Auto-activates when converting architecture to task beads, guides usage

### Commands (`commands/`)

- `/beadmeister <architecture-bead-id>` - Create task beads from architecture

## Development

This repo is managed as a Gas Town rig at `~/gt/claude_plugins/`.

Changes are automatically detected by Claude Code when pushed to main.
