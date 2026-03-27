# Verification Hooks Plugin

This plugin enforces independent work verification at task boundaries via Claude Code hooks.

## What It Does

When Claude claims work is done (bd close, TaskComplete, or Stop after code changes), a fresh
Sonnet agent checks if the work actually matches requirements. This is architectural enforcement,
not a skippable suggestion.

## Gates

- **bd close**: Blocks unless the issue has a `VERIFIED:` note. Instructs Claude to spawn the
  independent-verifier agent first.
- **TaskCompleted**: Sonnet agent automatically verifies completed tasks.
- **Stop**: Sonnet agent checks for uncommitted changes and verifies significant work.
- **Infrastructure**: Blocks batch operations without single-item test.

## Monitoring

All events log to `~/.local/log/verification-hooks.jsonl`. This file is essential system data.
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-verification.sh` for a health report.

## Fail-Open

Hook errors never block work. They exit 0 and log an error event for later review.
