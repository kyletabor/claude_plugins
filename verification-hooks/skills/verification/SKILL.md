---
name: verification
description: >
  This skill should be used when the user asks about "verification hooks", "verification status",
  "analyze verification", "verification report", "check verification log", "why was my close blocked",
  "verification gate", or mentions independent verification enforcement. Also triggers when
  investigating blocked bd close, TaskCompleted, or Stop events. Provides guidance on the
  verification hooks system, troubleshooting, and monitoring.
---

# Verification Hooks

Architectural enforcement of independent work verification at task boundaries. When Claude claims
work is done (bd close, TaskComplete, or Stop after code changes), a fresh Sonnet agent checks
if the work actually matches requirements.

## Core Principle

Skills are suggestions. Hooks are enforcement. This plugin moves verification from a skippable
skill to non-bypassable architectural gates.

## How It Works

Four gates fire at natural checkpoints:

| Gate | Event | Handler | Blocks? | Purpose |
|------|-------|---------|---------|---------|
| Issue Close | PreToolUse (Bash) | command script | YES | Verify before `bd close` |
| Task Complete | TaskCompleted | Sonnet agent | YES | Verify subagent work |
| Stop | Stop | Sonnet agent | YES (once) | Catch-all for untracked work |
| Infrastructure | PreToolUse (Bash) | command script | YES | Block risky batch ops |

### bd close Gate

When `bd close <id>` runs, the PreToolUse hook checks for a `VERIFIED:` note on the issue.
If not found, it blocks and instructs Claude to spawn an independent verification agent.

To pass this gate:
1. Spawn a verification agent (Agent tool) that reads the issue criteria
2. The agent checks each criterion against actual code/state
3. If all pass: `bd update <id> --notes='VERIFIED: <timestamp> | N/N criteria passed | evidence: <summary>'`
4. Retry `bd close <id>` — the gate sees the VERIFIED note and allows it

### TaskCompleted Gate

A Sonnet agent automatically fires when any task completes. It reads the git diff, checks
if changes match the task description, and returns ok/not-ok.

### Stop Gate

Fires when Claude finishes any response. The agent checks for uncommitted git changes.
If none exist, it passes immediately. If significant work happened, it verifies correctness.

One-shot limitation: Stop can only block once per turn to prevent infinite loops.

### Infrastructure Gates

Deterministic checks for high-risk operations:
- **Batch operations**: Require single-item test before processing all items
- **Docker builds**: Logged for the Stop gate to review

## Monitoring

All events log to `~/.local/log/verification-hooks.jsonl`. Run the analysis script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-verification.sh
```

### Healthy Ranges

| Metric | Healthy | Action if Outside |
|--------|---------|-------------------|
| bd_close block rate | 10-30% | >50% = Claude not self-checking |
| stop block rate | <10% | >20% = gate too aggressive |
| avg duration (bd_close) | <100ms | Script bottleneck if slow |
| avg duration (stop agent) | 5-15s | >30s = agent doing too much |
| error rate | 0% | Any errors = fix immediately |

## Fail-Open Policy

If a hook script itself errors (jq fails, bd not found, disk full), it exits 0 (allow) and
logs an error event. Hooks never block work because the hook broke.

## Troubleshooting

**"VERIFICATION REQUIRED" on bd close:**
The issue lacks a VERIFIED note. Spawn a verification agent as instructed, or if the work
was already manually verified, add the note directly:
`bd update <id> --notes='VERIFIED: manual | evidence: <description>'`

**Stop gate blocking too often:**
Check `analyze-verification.sh` — if stop block rate >20%, the agent may need prompt tuning
to better distinguish code work from conversations.

**Hook errors in log:**
Run: `jq 'select(.action == "error")' ~/.local/log/verification-hooks.jsonl`
Common causes: jq not installed, bd not on PATH, disk full.

## Additional Resources

### Reference Files
- **`references/event-schema.md`** — Full JSONL event schema with examples per gate type
