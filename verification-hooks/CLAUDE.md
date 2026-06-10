# Verification Hooks Plugin

This plugin enforces independent work verification at task boundaries via Claude Code hooks.

## What It Does

When Claude claims work is done (bd close, TaskComplete), a check fires that is **sized to the change** —
trivial work auto-passes, real work is verified by type (backend → tests, user-facing → UI). This is
architectural enforcement, not a skippable suggestion.

## Gates

- **bd close** (PreToolUse): Blocks unless the issue has a `VERIFIED:` note. Instructs Claude to
  spawn the independent-verifier agent first. Cheap and deterministic — the non-bypassable safety net.
  - **Exceptions**: Duplicate issues (labeled `duplicate-of:`) are allowed through and logged.
  - **Circuit breaker**: After 3 blocks on the same issue, agent can override with `--reason`.
- **TaskCompleted**: A Sonnet agent that right-sizes itself — auto-passes trivial diffs (< ~30 lines,
  docs/config only), and for real changes verifies by type (user-facing → UI/e2e evidence; backend →
  unit + integration tests on the real flow).

## Removed in v1.5

- **SubagentStop** auto-verifier: it fired a full Sonnet pass after every sub-agent, so one fan-out spawned
  dozens of redundant verifiers re-checking the same diff that `TaskCompleted` + `bd close` already cover.
  This was a major token sink with near-zero marginal catch on a reliable model. The `bd close` gate
  (deterministic) + a single risk-sized `TaskCompleted` check replace it.

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
