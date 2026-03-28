# Verification Hooks v1.2.0 — Audit Fixes Design Spec

## Goal

Fix 5 issues discovered during the first verification-hooks audit (total_recall session). Improve traceability, reduce false positives, add escape hatches for legitimate edge cases, and consolidate all data in a persistent, backup-friendly location.

## Scope

- **In scope**: Session ID traceability, command matching fix, duplicate exception, circuit breaker, exception logging, data location consolidation
- **Out of scope**: TaskCompleted/SubagentStop agent hooks, Stop hook changes (already removed), new hook types

## Current State Verification

- `log-event.sh:12` reads `CLAUDE_SESSION_ID` env var — never set, always "unknown"
- Hook stdin JSON includes `session_id` field (confirmed in plugin-dev hook-development skill docs)
- `verify-before-close.sh:24` uses `grep -q "bd close"` — matches anywhere in command string
- `bd duplicate` command adds `duplicate-of:<id>` label and auto-closes
- `bd close` supports `--reason` flag
- Current log path: `~/.local/log/verification-hooks.jsonl`
- No circuit breaker mechanism exists

## Files to Modify

| File | Action | Purpose |
|------|--------|---------|
| `verification-hooks/scripts/log-event.sh` | Modify | Read session_id from stdin; update log path |
| `verification-hooks/hooks/verify-before-close.sh` | Modify | Smart matching, duplicate exception, circuit breaker |
| `verification-hooks/hooks/verification-logger.sh` | Modify | Pass stdin to log-event for session_id |
| `verification-hooks/.claude-plugin/plugin.json` | Modify | Version 1.1.0 → 1.2.0 |
| `.claude-plugin/marketplace.json` | Modify | Version 1.1.0 → 1.2.0 |

## Technical Design

### R1: Session ID Traceability

**Problem**: `log-event.sh` reads `$CLAUDE_SESSION_ID` env var which is never set.

**Fix**: Read `session_id` from hook stdin JSON instead. This requires the calling scripts to pass stdin content to `log_event`.

**Change to log-event.sh**:
- Add a function `extract_session_id()` that reads session_id from a passed JSON string
- `log_event` takes an optional second argument: the raw stdin JSON
- Extract `session_id` from that JSON, fallback to env var, fallback to "unknown"

**Change to callers** (verify-before-close.sh, verification-logger.sh):
- Both already read stdin into `$INPUT`. Pass `$INPUT` to `log_event` calls.

**Assumptions**: Claude Code always includes `session_id` in hook stdin JSON. If absent, falls back to "unknown" (same as today). Detectable immediately via log queries.

**Failure mode**: If Claude Code changes stdin format, we get "unknown" — fail-open, same behavior as today. No regression.

### R2: Smart Command Matching

**Problem**: `grep -q "bd close"` matches anywhere in command text.

**Fix**: Parse the command to check that `bd close` is the actual command being invoked:
1. Strip leading whitespace
2. Check command starts with `bd close` or contains `&& bd close` / `; bd close`
3. Extract arguments after `bd close`
4. Filter out flags (starting with `-`)
5. Validate remaining args look like issue IDs (contain at least one hyphen)

**Assumptions**: Issue IDs always contain hyphens (e.g., `kyle-dev-infra-abc`). Commands don't use `bd close` as a variable name or in heredocs.

**Failure mode**: An unanticipated command format bypasses the check. Mitigated by fail-open — if no valid IDs parsed, we skip the gate and log.

### R3: Duplicate Close Exception

**Problem**: Closing duplicate issues triggers the verification gate unnecessarily.

**Fix**: Before blocking, run `bd show <id>` and check for `duplicate-of:` in labels. If found:
- Allow the close
- Log as `action: "exception_allowed"`, `reason: "duplicate_close"`

**Assumptions**: Duplicates are always marked via `bd duplicate` (which adds the label). Manual `bd close` on an unlabeled duplicate will still be blocked.

**Failure mode**: `bd show` output format changes. Mitigated by fail-open — if we can't detect the label, we block (conservative default).

### R4: Circuit Breaker

**Problem**: Same issue blocked repeatedly with no escape.

**Fix**: Count previous blocks for this session+issue from the JSONL log:
```bash
count=$(jq -s "[.[] | select(.session_id==\"$SID\" and .gate==\"bd_close\" and .action==\"blocked\" and (.details.issue_ids | contains(\"$ID\")))] | length" "$LOG")
```

If count >= 3:
- Change block message: "Blocked 3+ times. Include --reason to override."
- If agent includes `--reason` flag: allow through, log as `exception_allowed` with `reason: "circuit_breaker"` and the agent's stated reason
- Reset is implicit (new session = new counts via session_id scoping)

**No separate state files**. The JSONL log IS the state. Query it on each invocation.

**Performance**: Log auto-rotates at 10K lines (keeps 5K). jq on 5K lines takes <100ms. Acceptable given bd show already takes 100-300ms.

**Assumptions**: Log is not corrupted. Session ID is available (R1). jq is installed.

**Failure mode**: If jq fails or log is unreadable, count defaults to 0 (conservative — keeps blocking). Logged as error.

### R5: Data Location Consolidation

**Problem**: Log at `~/.local/log/verification-hooks.jsonl` is mixed with other system logs. Not clearly backup-able.

**Fix**: Move to `~/.local/share/verification-hooks/events.jsonl`.
- `~/.local/share/` is the XDG standard for persistent application data
- Dedicated directory = easy backup target, no pollution
- Create symlink at old path for backward compatibility
- Update `log-event.sh` default path

**Backup inclusion**: Document that `~/.local/share/verification-hooks/` should be in backup config.

### R6: Exception Event Schema

New action type `"exception_allowed"` with structured details:

```json
{
  "gate": "bd_close",
  "action": "exception_allowed",
  "duration_ms": 150,
  "details": {
    "reason": "duplicate_close" | "circuit_breaker",
    "issue_ids": "kyle-dev-infra-abc",
    "agent_reason": "...",
    "block_count": 3,
    "command": "bd close ..."
  },
  "ts": "ISO-8601",
  "session_id": "uuid"
}
```

Query: `jq 'select(.action == "exception_allowed")'` surfaces all exceptions.

## Acceptance Criteria (Executable)

- R1: When a hook fires, the log entry contains the actual session UUID (not "unknown")
- R2: When running `bd close --help`, the gate does NOT fire (exit 0, no block message)
- R2: When running `git commit -m "fixed bd close gate"`, the gate does NOT fire
- R2: When running `bd close kyle-dev-infra-abc`, the gate fires correctly
- R3: When closing an issue with `duplicate-of:` label, the gate allows and logs `exception_allowed`
- R4: After 3 blocks on the same issue in the same session, the block message includes circuit breaker instructions
- R4: When agent provides `--reason` after breaker threshold, the gate allows and logs `exception_allowed` with the reason
- R5: Log file is at `~/.local/share/verification-hooks/events.jsonl`
- R5: Old path symlinked for backward compatibility
- R6: All exceptions have `action: "exception_allowed"` and are queryable via jq

## Test Plan

1. Unit: Test command matching against known false positive patterns
2. Unit: Test duplicate label detection
3. Unit: Test circuit breaker count logic
4. Integration: Run verify-before-close.sh with mock stdin containing session_id
5. Integration: Simulate 4 blocks on same issue, verify breaker activates on 4th
6. Verify log entries contain real session IDs
