# Verification Hooks Plugin

This plugin enforces independent work verification at task boundaries via Claude Code hooks.

## What It Does

When Claude claims work is done (bd close, TaskComplete, SubagentStop), a fresh
Sonnet agent checks if the work actually matches requirements. This is architectural enforcement,
not a skippable suggestion.

## Gates

- **bd close** (PreToolUse): Blocks unless the issue has a `VERIFIED:` note. Instructs Claude to
  spawn the independent-verifier agent first.
  - **Exceptions**: Duplicate issues (labeled `duplicate-of:`) are allowed through and logged.
  - **Circuit breaker**: After 3 blocks on the same issue, agent can override with `--reason`.
- **TaskCompleted**: Sonnet agent automatically verifies completed tasks.
- **SubagentStop**: Sonnet agent automatically verifies subagent work.

## Data Location

All events log to `~/.local/share/verification-hooks/events.jsonl`. This directory should be
included in backups. A symlink at `~/.local/log/verification-hooks.jsonl` provides backward
compatibility.

Exception events (`action: "exception_allowed"`) are the highest-value audit items:
```bash
jq 'select(.action == "exception_allowed")' ~/.local/share/verification-hooks/events.jsonl
```

## Fail-Open

Hook errors never block work. They exit 0 and log an error event for later review.
