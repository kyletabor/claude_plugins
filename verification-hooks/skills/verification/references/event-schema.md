# Verification Hooks — Event Schema Reference

Every hook writes one JSONL line per firing to `~/.local/log/verification-hooks.jsonl`.

## Required Fields (Every Event)

| Field | Type | Purpose |
|-------|------|---------|
| `ts` | ISO 8601 | When the hook fired |
| `session_id` | string | Which Claude session |
| `gate` | enum | Which gate: `bd_close`, `task_complete`, `stop`, `infra`, `logger` |
| `action` | enum | What happened: `blocked`, `allowed`, `skipped`, `error`, `logged` |
| `duration_ms` | int | How long the hook took (optional for logger) |

## Gate-Specific Detail Fields

### bd_close events

```json
{
  "ts": "2026-03-26T15:30:00-04:00",
  "session_id": "abc123",
  "gate": "bd_close",
  "action": "blocked",
  "duration_ms": 45,
  "details": {
    "issue_ids": "beads-abc,beads-def",
    "reason": "no VERIFIED note",
    "command": "bd close beads-abc beads-def"
  }
}
```

### task_complete events

```json
{
  "ts": "2026-03-26T15:31:00-04:00",
  "session_id": "abc123",
  "gate": "task_complete",
  "action": "allowed",
  "duration_ms": 12000,
  "details": {
    "task_id": "task-123",
    "verdict": "ok",
    "reason": "3 files changed, tests pass, matches task description",
    "files_changed": 3
  }
}
```

### stop events

```json
{
  "ts": "2026-03-26T15:32:00-04:00",
  "session_id": "abc123",
  "gate": "stop",
  "action": "allowed",
  "duration_ms": 2000,
  "details": {
    "uncommitted_files": 0,
    "verdict": "ok",
    "reason": "no file changes detected"
  }
}
```

### infra events

```json
{
  "ts": "2026-03-26T15:33:00-04:00",
  "session_id": "abc123",
  "gate": "infra",
  "action": "blocked",
  "details": {
    "trigger": "batch_operation",
    "command": "npx qmd embed",
    "single_item_test": false
  }
}
```

### logger events

```json
{
  "ts": "2026-03-26T15:34:00-04:00",
  "session_id": "abc123",
  "gate": "logger",
  "action": "logged",
  "details": {
    "tool": "Edit",
    "file": "src/config.ts"
  }
}
```

### error events (when the hook itself fails)

```json
{
  "ts": "2026-03-26T15:35:00-04:00",
  "session_id": "abc123",
  "gate": "bd_close",
  "action": "error",
  "details": {
    "error": "bd show failed: command not found",
    "fallback": "allowed"
  }
}
```

## Querying the Log

All analysis uses `jq` one-liners:

```bash
LOG=~/.local/log/verification-hooks.jsonl

# Gate fire counts
jq -s 'group_by(.gate) | map({gate: .[0].gate, count: length})' "$LOG"

# Block rate per gate
jq -s 'group_by(.gate) | map({gate: .[0].gate, total: length, blocked: ([.[] | select(.action == "blocked")] | length)})' "$LOG"

# All blocks in the last 24 hours
jq --arg since "$(date -Iseconds -d '24 hours ago')" 'select(.action == "blocked" and .ts > $since)' "$LOG"

# Errors only
jq 'select(.action == "error")' "$LOG"

# Events per session
jq -s 'group_by(.session_id) | map({session: .[0].session_id, events: length}) | sort_by(-.events)' "$LOG"
```
