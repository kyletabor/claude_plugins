# Verification Hooks

Independent work verification gates for Claude Code. Enforces verification at task boundaries
so AI agents can't claim "done" without proof.

## What It Does

When Claude tries to close an issue, complete a task, or stop after making code changes, this
plugin spawns a fresh Sonnet verification agent that independently checks the work against
acceptance criteria. If the work doesn't meet the criteria, the action is blocked.

## Components

- **Hooks**: PreToolUse (bd close + infra gates), TaskCompleted (agent verification),
  Stop (catch-all agent verification), PostToolUse (event logger)
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
