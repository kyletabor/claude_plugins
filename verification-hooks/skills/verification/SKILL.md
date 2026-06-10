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

Two gates fire at natural checkpoints, **sized to risk** (v1.5 — redundant always-on passes removed):

| Gate | Event | Handler | Blocks? | Purpose |
|------|-------|---------|---------|---------|
| Issue Close | PreToolUse (Bash) | command script | YES | Verify before `bd close` (cheap, deterministic) |
| Task Complete | TaskCompleted | Sonnet agent (risk-sized) | YES | Verify real changes; auto-pass trivial ones |

> **Removed in v1.5 — the `SubagentStop` gate.** It fired a full Sonnet verifier after EVERY sub-agent,
> so a single fan-out spawned dozens of redundant verifiers (a major token sink) re-checking the same diff
> that `TaskCompleted` and the `bd close` gate already cover. The deterministic `bd close` gate remains the
> non-bypassable safety net; `TaskCompleted` is the single LLM check, and it now right-sizes itself.

### bd close Gate (deterministic, always on)

When `bd close <id>` runs, the PreToolUse hook checks for a `VERIFIED:` note on the issue.
If not found, it blocks and instructs Claude to spawn an independent verification agent.

To pass this gate:
1. Spawn a verification agent (Agent tool) that reads the issue criteria
2. The agent checks each criterion against actual code/state — **sized to the change**: backend → run unit + integration tests that exercise the real flow; user-facing → Playwright UI check (see the `independent-verifier` agent)
3. If all pass: `bd update <id> --notes='VERIFIED: <timestamp> | N/N criteria passed | evidence: <summary>'`
4. Retry `bd close <id>` — the gate sees the VERIFIED note and allows it

### TaskCompleted Gate (risk-sized LLM check)

A Sonnet agent fires when a task completes, but **right-sizes its own effort**:
1. It runs `git diff --stat` first. **Trivial changes (< ~30 lines, docs/config only, no source-logic files) auto-pass immediately** — no token spend on typos.
2. For real changes it verifies by TYPE: user-facing → confirm UI/e2e evidence exists; backend → run unit + integration tests that exercise the real flow.

This replaces the old behavior that ran a full Sonnet pass on every task regardless of size.

## Monitoring

Command hooks (PreToolUse bd close gate, PostToolUse logger) log to `~/.local/log/verification-hooks.jsonl`.
The `TaskCompleted` agent hook is visible in the session spinner but does not write to the JSONL log —
it runs as a Sonnet agent without access to the log writer script.

Run the analysis script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/analyze-verification.sh
```

### Healthy Ranges

| Metric | Healthy | Action if Outside |
|--------|---------|-------------------|
| bd_close block rate | trending low (0–15%) on a reliable model — a low rate means Claude IS self-checking | Persistently >40% = Claude routinely skips self-verification |
| avg duration (bd_close) | <100ms | Script bottleneck if slow |
| error rate | 0% | Any errors = fix immediately |

> Note: the old guidance ("10–30% block rate is healthy") assumed a weaker model that frequently failed to
> self-check. On a reliable 2026 model a block rate near zero is the GOOD outcome — the gate is a safety net,
> not a metric to keep elevated.

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
