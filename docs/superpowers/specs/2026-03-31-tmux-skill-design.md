# Tmux Skill Design Spec

**Date:** 2026-03-31
**Bead:** kyle-dev-infra-4p8
**Status:** Draft

## Purpose

Give Claude Code direct tmux control for launching and managing test/verification sessions. Primary use case: spinning up fresh Claude Code sessions to verify plugins, skills, and hooks work correctly.

## Architecture

**Pure skill — no scripts, no MCP server, no dependencies.**

A single SKILL.md file in a new `tmux` plugin directory within `~/projects/claude_plugins/`. The skill teaches Claude raw tmux commands with defensive patterns and multi-agent safety rules baked into the instructions.

The SKILL.md is structured as **step-by-step recipes** for common workflows, not a reference manual. Claude follows recipes far more reliably than it synthesizes behavior from capability lists.

### Plugin structure

```
tmux/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── tmux/
        └── SKILL.md
```

## Core Recipes

### Recipe 1: Create a Session and Run a Command

1. Generate session name: `agent-<context>-$(openssl rand -hex 2)` (max 40 chars total)
2. Create directory: `mkdir -p ~/.local/share/tmux-skill`
3. Create session: `tmux new-session -d -s <name> -c <workdir> "<command>"`
4. Verify creation: `tmux list-sessions -F '#{session_name}' | grep -qx '<name>'` — if fails, regenerate UUID and retry once
5. Write registry entry (with flock): `flock ~/.local/share/tmux-skill/sessions.jsonl -c "echo '{...}' >> ~/.local/share/tmux-skill/sessions.jsonl"`

### Recipe 2: Send Input to a Session

1. Escape copy-mode first: `tmux send-keys -t <target> -X cancel 2>/dev/null || true`
2. For short text: `tmux send-keys -t <target> -l -- "<text>"`
3. Wait: `sleep 0.2`
4. Send Enter: `tmux send-keys -t <target> Enter`
5. For multiline/long text (>400 chars): write to `/tmp/agent-<session>-input.txt`, then `tmux load-buffer -b agent-buf /tmp/agent-<session>-input.txt && tmux paste-buffer -p -d -b agent-buf -t <target>` then `sleep 0.2` then `tmux send-keys -t <target> Enter`
6. For complex shell commands: write to `/tmp/agent-<session>-cmd.sh`, then send `bash /tmp/agent-<session>-cmd.sh` + Enter

### Recipe 3: Read Output from a Session

- **Quick check (20 lines)**: `tmux capture-pane -t <target> -p | tail -20`
- **Analysis (500 lines)**: `tmux capture-pane -t <target> -p -S -500`
- **Full scrollback**: `tmux capture-pane -t <target> -p -S -` (use sparingly — can be huge)
- **Join wrapped lines**: add `-J` flag when parsing output programmatically
- **IMPORTANT**: after sending input, always `sleep 0.3` before capturing — output needs time to flush

### Recipe 4: Launch a Claude Code Verification Session

1. Follow Recipe 1 with command: `claude --dangerously-skip-permissions`
   - **Only for throwaway test sessions** — never for sessions touching real data or shared repos
2. Wait for Claude to boot: `sleep 5` then capture-pane to confirm it's ready
3. Send test prompt using Recipe 2
4. Read results using Recipe 3
5. Exit Claude: `tmux send-keys -t <target> -l -- '/exit'` then `sleep 0.2` then `tmux send-keys -t <target> Enter`
6. For non-interactive verification, prefer: `claude --print --output-format text "prompt"` (no tmux needed)

### Recipe 5: Clean Up When Done

**Run this before reporting any task as complete.**

1. List your sessions (the ones you created this conversation)
2. For each session:
   a. Kill it: `tmux kill-session -t <name> 2>/dev/null || true`
   b. Update registry: `flock ~/.local/share/tmux-skill/sessions.jsonl -c "echo '{\"session\":\"<name>\",\"status\":\"closed\",\"closed\":\"<timestamp>\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"`
3. Clean up temp files: `rm -f /tmp/agent-<session>-*.sh /tmp/agent-<session>-*.txt`

### Recipe 6: Scan for Orphaned Sessions (Housekeeping)

Run at the start of a conversation if tmux session hygiene is relevant:

1. Read active entries: `grep '"status":"active"' ~/.local/share/tmux-skill/sessions.jsonl`
2. For each, check if tmux session still exists: `tmux list-sessions -F '#{session_name}' | grep -qx '<name>'`
3. If session is gone, append orphan record: `flock ... -c "echo '{\"session\":\"<name>\",\"status\":\"orphaned\",\"detected\":\"<timestamp>\"}' >> ..."`
4. Optionally kill orphaned sessions that still exist but are older than 4 hours (check `created` timestamp)
5. Registry rotation: entries older than 7 days can be purged with `flock ... -c "tmp=$(mktemp) && jq -c 'select(...)' < file > $tmp && mv $tmp file"`

## Multi-Agent Safety Rules

These are HARD rules — the skill must enforce them in its instructions.

### Session Naming

Format: `agent-<context>-<short-uuid>`

- `<context>`: bead ID, task name, or purpose (e.g., `4p8`, `verify-hooks`)
- `<short-uuid>`: 4-char random hex for global uniqueness (e.g., `a3f2`)
- Examples: `agent-4p8-a3f2`, `agent-verify-hooks-b7e1`
- Validation: `^[a-zA-Z0-9_-]+$` only — no dots, colons, or spaces
- **Max 40 characters total** — prevents display issues and unwieldy names
- **On name collision**: regenerate UUID and retry once

### Ownership Rules

1. **Only interact with sessions you created** in the current conversation
2. **Never kill, send input to, or modify sessions you didn't create** — even other `agent-*` sessions
3. **User sessions** (`claude`, `claude-1`, `shell`, etc.) are **hands-off** unless the user explicitly names one and gives permission
4. **Listing all sessions is OK** — but interacting requires ownership or explicit user instruction
5. **Track your sessions** — maintain awareness of which session names you created so you can clean up
6. **Write-own-only is advisory** — no filesystem enforcement exists. Violation causes confusion in crash recovery but not data loss.

### Session Registry

A JSONL file tracks all agent-created sessions: **`~/.local/share/tmux-skill/sessions.jsonl`**

Each line records who/what/when/where/why:

```json
{"session": "agent-4p8-a3f2", "created": "2026-03-31T03:45:00Z", "creator": "PID-12345", "bead": "kyle-dev-infra-4p8", "purpose": "verify tmux skill works", "workdir": "/home/orangepi/projects/claude_plugins", "status": "active"}
```

| Field | Description |
|-------|------------|
| `session` | tmux session name |
| `created` | ISO 8601 timestamp |
| `creator` | PID of the Claude Code process (`$$` in bash, or `$PPID`) — deterministic and unique per session |
| `bead` | Associated bead ID, if any (`"none"` if not applicable) |
| `purpose` | Why this session was created |
| `workdir` | Working directory the session was started in |
| `status` | `active`, `closed`, or `orphaned` |

**Registry rules:**

1. **Append on create** — every `new-session` writes a registry entry (part of Recipe 1)
2. **Update via append** — to mark closed/orphaned, append a new line with the same `session` name and new `status`. Latest entry for a given session name wins.
3. **All writes use `flock`** — prevents concurrent append corruption from multiple agents
4. **Read is always safe** — any agent can read the registry for awareness
5. **Write-own-only** — agents only append entries for sessions they created
6. **Rotation** — entries older than 7 days can be purged during housekeeping (Recipe 6)

**Creator identity:** Use `$PPID` (parent PID of the bash shell, which is the Claude Code process). This is deterministic, unique per running Claude session, and available in every bash invocation.

### Cleanup

- **MANDATORY before claiming "done"**: run Recipe 5 for every session you created
- Update registry entries to `closed` when killing sessions
- Use unique temp file names: `/tmp/agent-<session-name>-cmd.sh`
- Clean up temp files after use
- Temp files are best-effort; `/tmp` is ephemeral and self-cleans on reboot

### Resource Isolation

- No shared temp files — always include session name in temp file paths
- Registry is append-only per agent (no deleting other agents' entries)
- No assumptions about what other sessions exist or their state

## Defensive Patterns

### Race Conditions

| Problem | Mitigation |
|---------|-----------|
| Shell not ready when keys arrive | Pass command as arg to `new-session`, not via `send-keys` |
| Enter arrives before text is processed | Separate text and Enter sends with `sleep 0.2` (may need 0.3 on loaded systems) |
| Capture-pane returns stale output | Wait `sleep 0.3` after send-keys before capturing |
| Copy-mode blocks send-keys | Send `-X cancel` before any input (Recipe 2, step 1) |
| Session name already exists | Regenerate UUID suffix and retry once |

### Escaping

| Problem | Mitigation |
|---------|-----------|
| Special chars in send-keys | Always use `-l` flag for literal mode |
| Complex commands with quotes/pipes | Write to temp file, send `bash /tmp/file.sh` |
| `$` expansion in commands | Use single quotes or temp files |
| Multiline text | Use `load-buffer` + `paste-buffer` (Recipe 2, step 5) |

### Session Management

| Problem | Mitigation |
|---------|-----------|
| Duplicate session names | Random UUID suffix + collision retry |
| `has-session` prefix-matches wrong session | Use `list-sessions` + `grep -qx` for exact match |
| Zombie sessions accumulate | Registry + cleanup recipes + 4-hour TTL for orphan detection |
| Killing another agent's session | Ownership rules + registry tracking |
| JSONL concurrent writes | All writes use `flock` |

## Trigger Descriptions

The skill should activate when Claude needs to:

- Launch a new Claude Code session for testing
- Verify a plugin/skill/hook works in a fresh session
- Monitor or interact with a running tmux session
- Send commands to an interactive terminal application
- Check the output of a background process in tmux

## What This Skill Does NOT Cover

- Window/pane splitting (not needed, Kyle doesn't want pane splits)
- Polling/wait-for-text patterns (too fragile given Claude Code UX changes)
- tmux configuration changes
- Session persistence/resurrection
- TUI rendering concerns (agents never attach to sessions — flickering is irrelevant)

## Verification Plan

1. **Create verification beads** for each test scenario
2. **Basic lifecycle test**: create a session, send a command, read output, verify registry entry, clean up, verify registry updated — **pass**: output matches expected, registry shows active then closed
3. **Claude Code test**: launch a Claude session with `--dangerously-skip-permissions`, send a simple prompt, verify response appears in capture-pane — **pass**: Claude responds coherently
4. **Multi-agent test**: two agent sessions coexist, each only interacts with its own — **pass**: no cross-contamination, both registries correct
5. **Cleanup test**: all agent sessions removed after task, registry reflects closures, temp files gone — **pass**: `tmux ls` shows no `agent-*` sessions, no orphan temp files
6. **Orphan detection test**: create a session, kill it outside the skill (simulating crash), run Recipe 6 — **pass**: registry marks it orphaned
