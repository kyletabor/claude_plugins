> **DEPRECATED — 2026-09-16.** This plugin is retired and its hooks are removed (v1.6.0 is a no-op).
> Four months of logs showed the gates caught **0** real defects while producing a 64% false-block
> rate (the close gate ran `bd show` from the session cwd, not the repo), a `TaskCompleted` hook that
> never fired (beads replaces the built-in task list), and ~350ms of overhead on every tool call.
> Independent verification remains a **dev-process** step (`dev-process:independent-verifier`), and
> for unattended runs use Claude Code's native `/goal`. Uninstall with `/plugin uninstall verification-hooks@kyle-plugins`.
> The scripts and agent definition are kept for reference only.

# Verification Hooks

Independent work verification gates for Claude Code. Enforces verification at task boundaries
so AI agents can't claim "done" without proof.

## What It Does

When Claude tries to close an issue, complete a task, or stop after making code changes, this
plugin spawns a fresh Sonnet verification agent that independently checks the work against
acceptance criteria. If the work doesn't meet the criteria, the action is blocked.

## Components

- **Hooks**: SessionStart (marketplace registry check), PreToolUse (bd close + infra gates),
  TaskCompleted (agent verification), PostToolUse (event logger)
- **Skills**: Verification skill with monitoring guidance and troubleshooting
- **Agents**: Independent verifier agent (read-only, Sonnet-powered)
- **Scripts**: Shared log writer, analysis/monitoring report

## Installation

```bash
# Via kyle-plugins marketplace (if already added)
/plugin install verification-hooks@kyle-plugins

# Or add the marketplace first
/plugin marketplace add kyletabor/claude_plugins
/plugin install verification-hooks@kyle-plugins
```

## After Installation

Remove the old qa-gate.sh from your settings.json TaskCompleted hooks — this plugin replaces it.

## Monitoring

```bash
# View verification report
bash ~/.claude/plugins/cache/kyle-plugins/verification-hooks/*/scripts/analyze-verification.sh

# Or query the log directly
jq 'select(.action == "blocked")' ~/.local/log/verification-hooks.jsonl
```

## Design

Based on the verification-hooks v3 spec. Key principles:
- Architectural enforcement over instructional guidance
- Independent verification (builder != verifier)
- Verification at natural checkpoints, not every step
- Measure and adapt via JSONL monitoring
- Fail-open: hook errors never block work
