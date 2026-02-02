# Kyle's Claude Code Plugins

Personal plugin repository for custom agents, skills, and commands.

## Plugin Update Workflow

When making changes to this plugin:

1. **Make your changes** to skills/, agents/, or commands/
2. **Bump the version** in `.claude-plugin/plugin.json` (use semver)
   - Patch (0.1.0 → 0.1.1): Bug fixes
   - Minor (0.1.0 → 0.2.0): New features, new skills/agents/commands
   - Major (0.1.0 → 1.0.0): Breaking changes
3. **Commit and push** to GitHub
4. **Start a new Claude Code session** - it will fetch the new version from the marketplace

**Why version bump matters:** Claude Code caches plugins by version. Without a version bump, the cache won't refresh even after pushing changes.

## Structure

```
kyle-plugins/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata and version
├── agents/
│   └── beadsmith.md     # Work decomposition agent (isolated context)
├── skills/
│   └── beadsmith/
│       ├── SKILL.md     # Auto-activates on decomposition discussions
│       └── references/
│           └── patterns.md  # Dependency patterns and templates
├── commands/
│   └── beadsmith.md     # /beadsmith shortcut command
└── CLAUDE.md            # This file
```

## Components

### Beadsmith (skill + agent)

Decomposes epics, features, or bugs into implementable task beads.

**Architecture:** Skill-that-invokes-agent pattern
- **Skill** auto-activates when discussing work breakdown
- **Agent** runs in isolated context to avoid bloating main conversation

**Usage:**
- Auto-activates on phrases like "break this down" or "create tasks for this"
- Or explicitly: `/beadsmith <bead-id>`
- Or via Task tool: `Use the beadsmith agent to decompose <bead-id>`

## Development

This plugin is part of the Gas Town ecosystem. The source lives at:
- GitHub: https://github.com/kyletabor/claude_plugins
- Marketplace: kyle-plugins (registered in ~/.claude/plugins/known_marketplaces.json)
