# Claude Plugins Repo

Marketplace of Claude Code plugins. GitHub: kyletabor/claude_plugins, marketplace name: kyle-plugins.

## Repo Structure

```
claude_plugins/
  .claude-plugin/
    marketplace.json       # Marketplace manifest — ALL plugins must be registered here
  hooks/
    hooks.json             # Root-level hooks (SessionStart validation)
  scripts/
    validate-marketplace.sh  # Checks for unregistered plugin dirs on session start
  capa/                    # CAPA process (corrective/preventive action)
  capture/                 # Quick-capture inbox via capture-mcp MCP server
  dev-process/             # Structured dev pipeline (spec, review, verification)
  educate-me/              # 1-on-1 MECE tutor
  gastown/                 # Multi-agent orchestration (ABANDONED — do not invest)
  handoff/                 # Session context save/restore
  secret-vault/            # Secret interception and redaction
  session-historian/       # Session history reader and analyzer
```

Each plugin has its own `.claude-plugin/plugin.json` and contains some combination of `skills/`, `commands/`, `hooks/`, and `agents/` directories.

## Plugin Update Workflow

1. Edit files in this repo (~/projects/claude_plugins/).
2. Bump the version in BOTH the plugin's `.claude-plugin/plugin.json` AND the matching entry in `.claude-plugin/marketplace.json`. They must match.
   - Patch (0.1.0 -> 0.1.1): Bug fixes
   - Minor (0.1.0 -> 0.2.0): New features, new skills/agents/commands
   - Major (0.1.0 -> 1.0.0): Breaking changes
3. Commit and push to GitHub.
4. Start a new Claude Code session. It fetches the new version from the marketplace.

Claude Code caches plugins by version. Without a version bump, the cache will not refresh even after pushing changes.

## Critical: marketplace.json Registration

Every plugin directory with a `.claude-plugin/plugin.json` MUST have a matching entry in `.claude-plugin/marketplace.json`. Without it, the plugin is invisible to Claude Code. This has caused silent failures multiple times.

A SessionStart hook runs `scripts/validate-marketplace.sh` to warn about unregistered plugins, but it is informational only and does not block.

When adding a new plugin:
1. Create the directory with `.claude-plugin/plugin.json`.
2. Add a corresponding entry to `.claude-plugin/marketplace.json` with matching name and version.
3. Verify by running: `bash scripts/validate-marketplace.sh`

## Testing Plugins

After making changes, verify the plugin works:

1. Run the marketplace validator: `CLAUDE_PLUGIN_ROOT=. bash scripts/validate-marketplace.sh`
2. Confirm version match: check that the version in the plugin's `plugin.json` matches its entry in `marketplace.json`.
3. Commit, push, then start a fresh Claude Code session.
4. Invoke the changed skill or command and confirm it behaves as expected.
5. For plugins with test suites (e.g., session-historian/tests/), run those tests directly.
