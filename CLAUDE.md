# Claude Plugins Repo

Marketplace of Claude Code plugins. GitHub: kyletabor/claude_plugins, marketplace name: kyle-plugins.

## Repo Structure

```
claude_plugins/
  .claude-plugin/
    marketplace.json       # Marketplace manifest — ALL plugins must be registered here
  <plugin>/                # One directory per plugin (15 today; see README.md for the list)
    .claude-plugin/plugin.json
    README.md
    skills/ commands/ agents/ hooks/ tests/   # some combination
  docs/                    # Guides (statusline) + design specs/plans under docs/superpowers/
  verification-hooks/scripts/validate-marketplace.sh   # Checks for unregistered plugin dirs (SessionStart hook)
```

Every plugin has its own `.claude-plugin/plugin.json` and a `README.md`. The README at the repo root splits plugins into "general purpose" and "personal / infrastructure-specific"; keep that split accurate when adding one.

## Plugin Update Workflow

1. Edit files in this repo (~/projects/claude_plugins/).
2. Bump the version in BOTH the plugin's `.claude-plugin/plugin.json` AND the matching entry in `.claude-plugin/marketplace.json`. They must match.
   - Patch (0.1.0 -> 0.1.1): Bug fixes
   - Minor (0.1.0 -> 0.2.0): New features, new skills/agents/commands
   - Major (0.1.0 -> 1.0.0): Breaking changes
3. Add or update the plugin's README.md and its row in the root README.md.
4. Commit and push to GitHub.
5. Start a new Claude Code session. It fetches the new version from the marketplace.

Claude Code caches plugins by version. Without a version bump, the cache will not refresh even after pushing changes.

## Critical: marketplace.json Registration

Every plugin directory with a `.claude-plugin/plugin.json` MUST have a matching entry in `.claude-plugin/marketplace.json`. Without it, the plugin is invisible to Claude Code. This has caused silent failures multiple times.

`verification-hooks/scripts/validate-marketplace.sh` warns about unregistered plugins. It used to run on SessionStart via the (now deprecated) `verification-hooks` plugin; run it manually as shown below.

When adding a new plugin:
1. Create the directory with `.claude-plugin/plugin.json`.
2. Add a corresponding entry to `.claude-plugin/marketplace.json` with matching name and version.
3. Verify by running: `CLAUDE_PLUGIN_ROOT=verification-hooks bash verification-hooks/scripts/validate-marketplace.sh`

## Testing Plugins

After making changes, verify the plugin works:

1. Run the marketplace validator: `CLAUDE_PLUGIN_ROOT=verification-hooks bash verification-hooks/scripts/validate-marketplace.sh`
2. Confirm version match: check that the version in the plugin's `plugin.json` matches its entry in `marketplace.json`.
3. Commit, push, then start a fresh Claude Code session.
4. Invoke the changed skill or command and confirm it behaves as expected.
5. For plugins with test suites (e.g., session-historian/tests/), run those tests directly.

## Public Repo Hygiene

This repo is public. Before committing: no secrets, emails, private hostnames (Tailscale names included), or session transcripts. Personal absolute paths are tolerated only inside plugins listed as personal/infrastructure-specific in the README.
