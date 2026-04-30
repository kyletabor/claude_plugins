# Tmux Skill Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Claude Code plugin with a tmux skill that gives Claude safe, multi-agent-aware control of tmux sessions for testing and verification.

**Architecture:** A single SKILL.md structured as step-by-step recipes, inside a standard kyle-plugins plugin directory. No scripts, no MCP server — pure instructions teaching Claude raw tmux commands with defensive patterns and session registry tracking.

**Tech Stack:** Bash (tmux CLI), JSONL (session registry), Claude Code plugin system

**Spec:** `docs/superpowers/specs/2026-03-31-tmux-skill-design.md`

---

### Task 1: Create Plugin Scaffold

**Files:**
- Create: `tmux/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create plugin directory structure**

```bash
mkdir -p ~/projects/claude_plugins/tmux/.claude-plugin
mkdir -p ~/projects/claude_plugins/tmux/skills/tmux
```

- [ ] **Step 2: Create plugin.json**

Create `tmux/.claude-plugin/plugin.json`:

```json
{
  "name": "tmux",
  "version": "1.0.0",
  "description": "Tmux session control for Claude Code — launch test sessions, send commands, read output with multi-agent safety",
  "author": {
    "name": "Kyle Tabor",
    "url": "https://github.com/kyletabor"
  },
  "repository": "https://github.com/kyletabor/claude_plugins",
  "license": "MIT",
  "keywords": [
    "tmux",
    "terminal",
    "session",
    "verification",
    "testing",
    "multi-agent"
  ]
}
```

- [ ] **Step 3: Register in marketplace.json**

Add this entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "tmux",
  "source": "./tmux",
  "description": "Tmux session control for Claude Code — launch test sessions, send commands, read output with multi-agent safety",
  "version": "1.0.0",
  "category": "development",
  "tags": [
    "tmux",
    "terminal",
    "session",
    "verification",
    "testing",
    "multi-agent"
  ]
}
```

- [ ] **Step 4: Validate marketplace registration**

Run: `cd ~/projects/claude_plugins && CLAUDE_PLUGIN_ROOT=. bash scripts/validate-marketplace.sh`
Expected: no warnings about unregistered plugins

- [ ] **Step 5: Commit**

```bash
cd ~/projects/claude_plugins
git add tmux/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat: scaffold tmux plugin with marketplace registration"
```

---

### Task 2: Write SKILL.md

**Files:**
- Create: `tmux/skills/tmux/SKILL.md`

This is the core deliverable. The skill must be structured as recipes, not reference docs. Every pattern must include the defensive mitigations from the spec.

- [ ] **Step 1: Create SKILL.md with frontmatter and overview**

Create `tmux/skills/tmux/SKILL.md` with this exact content:

```markdown
---
name: tmux
description: >
  Control tmux sessions for testing and verification.
  Use when launching Claude Code test sessions, verifying plugins/skills/hooks in fresh sessions,
  sending commands to interactive terminal applications, or reading output from background processes.
  Triggers on: "launch a test session", "verify in a fresh session", "check tmux", "send to tmux",
  "create a tmux session", "read tmux output", "clean up sessions".
---

# Tmux Session Control

Control tmux sessions for launching test/verification Claude Code sessions, sending commands, and reading output. Multi-agent safe.

## Hard Rules

1. **Own sessions only.** Only interact with sessions YOU created this conversation. Never touch other `agent-*` sessions.
2. **User sessions are hands-off.** Sessions like `claude`, `claude-1`, `shell` belong to the user. Do not create, kill, send input, or modify them unless the user explicitly names one and gives permission.
3. **Registry every session.** Every session you create MUST be registered. Every session you kill MUST be marked closed.
4. **Clean up before "done".** Before reporting any task as complete, run the Cleanup recipe for every session you created.
5. **Sleeps are not optional.** Always wait between send-keys and capture-pane. Race conditions are silent and hard to debug.

## Recipe 1: Create a Session

```bash
# 1. Generate unique name (max 40 chars)
SESSION="agent-<context>-$(openssl rand -hex 2)"

# 2. Ensure registry directory exists
mkdir -p ~/.local/share/tmux-skill

# 3. Create detached session with initial command
#    Always pass command as argument — avoids shell-ready race
tmux new-session -d -s "$SESSION" -c "<workdir>" "<command>"

# 4. Verify it was created
tmux list-sessions -F '#{session_name}' | grep -qx "$SESSION"
# If this fails: regenerate UUID suffix and retry ONCE

# 5. Register (flock prevents concurrent write corruption)
flock ~/.local/share/tmux-skill/sessions.jsonl -c \
  "echo '{\"session\":\"$SESSION\",\"created\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"creator\":\"$$\",\"bead\":\"<bead-id-or-none>\",\"purpose\":\"<why>\",\"workdir\":\"<workdir>\",\"status\":\"active\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
```

**Session naming:** `agent-<context>-<4-char-hex>`
- `<context>`: bead ID, task name, or purpose (e.g., `4p8`, `verify-hooks`)
- Only `[a-zA-Z0-9_-]` characters. No dots, colons, spaces.
- Examples: `agent-4p8-a3f2`, `agent-verify-hooks-b7e1`

## Recipe 2: Send Input to a Session

```bash
# 1. Escape copy-mode (safe even if not in copy-mode)
tmux send-keys -t "$SESSION" -X cancel 2>/dev/null || true

# 2. Send text in literal mode (prevents tmux key interpretation)
tmux send-keys -t "$SESSION" -l -- "your text here"

# 3. Wait for text to be processed
sleep 0.2

# 4. Send Enter separately
tmux send-keys -t "$SESSION" Enter
```

**For multiline or long text (>400 chars):**

```bash
# Write content to unique temp file
cat > "/tmp/agent-${SESSION}-input.txt" << 'CONTENT'
your multiline
content here
CONTENT

# Load into tmux buffer and paste
tmux load-buffer -b agent-buf "/tmp/agent-${SESSION}-input.txt"
tmux paste-buffer -p -d -b agent-buf -t "$SESSION"
sleep 0.2
tmux send-keys -t "$SESSION" Enter

# Clean up
rm -f "/tmp/agent-${SESSION}-input.txt"
```

**For complex shell commands (quotes, pipes, variables):**

```bash
# Write command to temp script
cat > "/tmp/agent-${SESSION}-cmd.sh" << 'CMD'
echo "complex command with $VARS and | pipes"
CMD

# Send the script path (simple, no escaping needed)
tmux send-keys -t "$SESSION" -l -- "bash /tmp/agent-${SESSION}-cmd.sh"
sleep 0.2
tmux send-keys -t "$SESSION" Enter

# Clean up after output is captured
```

**Special keys (no -l flag):** `C-c`, `C-d`, `Escape`, `Enter`

```bash
tmux send-keys -t "$SESSION" C-c      # Ctrl+C
tmux send-keys -t "$SESSION" Escape    # Escape key
```

## Recipe 3: Read Output from a Session

```bash
# Quick check — last 20 lines
tmux capture-pane -t "$SESSION" -p | tail -20

# Deeper analysis — last 500 lines
tmux capture-pane -t "$SESSION" -p -S -500

# Full scrollback (use sparingly — can be huge)
tmux capture-pane -t "$SESSION" -p -S -

# Join wrapped lines (better for programmatic parsing)
tmux capture-pane -t "$SESSION" -p -J -S -500
```

**IMPORTANT:** After sending input, always `sleep 0.3` before capturing. Output needs time to flush.

## Recipe 4: Launch a Claude Code Test Session

```bash
# 1. Create session running Claude with auto-accept permissions
#    ONLY for throwaway test sessions — never for real data or shared repos
SESSION="agent-<context>-$(openssl rand -hex 2)"
mkdir -p ~/.local/share/tmux-skill
tmux new-session -d -s "$SESSION" -c "<workdir>" "claude --dangerously-skip-permissions"

# 2. Verify + register (see Recipe 1, steps 4-5)

# 3. Wait for Claude to boot
sleep 8

# 4. Check if Claude is ready
tmux capture-pane -t "$SESSION" -p | tail -10

# 5. Send a test prompt (use Recipe 2)
tmux send-keys -t "$SESSION" -l -- "Your test prompt here"
sleep 0.2
tmux send-keys -t "$SESSION" Enter

# 6. Wait for response, then read
sleep 10  # adjust based on expected response time
tmux capture-pane -t "$SESSION" -p -S -500

# 7. Exit Claude when done
tmux send-keys -t "$SESSION" -l -- "/exit"
sleep 0.2
tmux send-keys -t "$SESSION" Enter
```

**For non-interactive verification (preferred when possible):**

```bash
# No tmux needed — run Claude directly
CLAUDECODE= claude --print --output-format text "your verification prompt"
```

## Recipe 5: Clean Up (MANDATORY Before "Done")

```bash
# For EACH session you created this conversation:

# 1. Kill the session
tmux kill-session -t "$SESSION" 2>/dev/null || true

# 2. Mark closed in registry
flock ~/.local/share/tmux-skill/sessions.jsonl -c \
  "echo '{\"session\":\"$SESSION\",\"status\":\"closed\",\"closed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"

# 3. Clean up temp files
rm -f /tmp/agent-${SESSION}-*.sh /tmp/agent-${SESSION}-*.txt
```

## Recipe 6: Check for Orphaned Sessions (Housekeeping)

Run at the start of a conversation if tmux hygiene is relevant.

```bash
# 1. List all active agent sessions from registry
grep '"status":"active"' ~/.local/share/tmux-skill/sessions.jsonl 2>/dev/null | while IFS= read -r line; do
  SESSION=$(echo "$line" | grep -o '"session":"[^"]*"' | cut -d'"' -f4)

  # 2. Check if session still exists in tmux
  if ! tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -qx "$SESSION"; then
    # 3. Mark as orphaned
    flock ~/.local/share/tmux-skill/sessions.jsonl -c \
      "echo '{\"session\":\"$SESSION\",\"status\":\"orphaned\",\"detected\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
  fi
done
```

Sessions active for more than 4 hours are candidates for cleanup. Registry entries older than 7 days can be purged.

## Listing Sessions

```bash
# All tmux sessions (safe — read-only)
tmux list-sessions

# Just agent-managed sessions
tmux list-sessions -F '#{session_name}' | grep '^agent-'

# Check if a specific session exists (exact match)
tmux list-sessions -F '#{session_name}' | grep -qx "$SESSION"

# DO NOT use tmux has-session — it prefix-matches and hits wrong sessions
```

## Quick Reference: Defensive Patterns

| Situation | Do This |
|-----------|---------|
| Creating a session | Pass command as arg to `new-session` (not send-keys after) |
| Sending text | Always `-l` flag, always separate Enter, always `sleep 0.2` between |
| Reading output | Always `sleep 0.3` after send-keys before capture-pane |
| Multiline text | `load-buffer` + `paste-buffer`, NOT send-keys |
| Complex shell commands | Write to temp file, send `bash /tmp/file.sh` |
| Before any send-keys | Cancel copy-mode: `send-keys -X cancel 2>/dev/null \|\| true` |
| Session names | `agent-<context>-<4hex>`, max 40 chars, `[a-zA-Z0-9_-]` only |
| Name collision | Regenerate UUID suffix, retry once |
| Checking existence | `list-sessions` + `grep -qx`, never `has-session` |
| Registry writes | Always `flock` the JSONL file |
| Before claiming "done" | Kill all your sessions + update registry + delete temp files |
```

- [ ] **Step 2: Review the SKILL.md for completeness against spec**

Verify every spec requirement is covered:
- Session lifecycle (create, list, kill, check) ✓
- Safe input (literal, separate Enter, multiline, complex commands) ✓
- Reading output (line budgets, join, sleep) ✓
- Claude Code patterns (interactive, non-interactive, --dangerously-skip-permissions) ✓
- Multi-agent safety (naming, ownership, registry, flock, cleanup) ✓
- Defensive patterns (races, escaping, copy-mode, collision) ✓
- Trigger descriptions (in frontmatter) ✓
- Session registry (JSONL, flock, append-for-update, orphan detection) ✓

- [ ] **Step 3: Commit**

```bash
cd ~/projects/claude_plugins
git add tmux/skills/tmux/SKILL.md
git commit -m "feat: add tmux skill with recipes and multi-agent safety"
```

---

### Task 3: Verify Plugin Structure

**Files:** None (read-only verification)

- [ ] **Step 1: Validate marketplace**

Run: `cd ~/projects/claude_plugins && CLAUDE_PLUGIN_ROOT=. bash scripts/validate-marketplace.sh`
Expected: no warnings, tmux plugin recognized

- [ ] **Step 2: Check file structure matches plugin conventions**

```bash
ls -la ~/projects/claude_plugins/tmux/.claude-plugin/plugin.json
ls -la ~/projects/claude_plugins/tmux/skills/tmux/SKILL.md
```

Expected: both files exist

- [ ] **Step 3: Verify version match**

```bash
grep '"version"' ~/projects/claude_plugins/tmux/.claude-plugin/plugin.json
grep -A1 '"name": "tmux"' ~/projects/claude_plugins/.claude-plugin/marketplace.json | grep version
```

Expected: both show `"1.0.0"`

---

### Task 4: Basic Lifecycle Verification

**Files:** None (tmux + registry testing)

- [ ] **Step 1: Create a test session using the skill's Recipe 1**

```bash
SESSION="agent-test-$(openssl rand -hex 2)"
mkdir -p ~/.local/share/tmux-skill
tmux new-session -d -s "$SESSION" "echo 'hello from tmux skill test' && sleep 300"
tmux list-sessions -F '#{session_name}' | grep -qx "$SESSION" && echo "PASS: session created" || echo "FAIL"
flock ~/.local/share/tmux-skill/sessions.jsonl -c \
  "echo '{\"session\":\"$SESSION\",\"created\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"creator\":\"$$\",\"bead\":\"kyle-dev-infra-4p8\",\"purpose\":\"lifecycle test\",\"workdir\":\"/home/orangepi\",\"status\":\"active\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
```

Expected: "PASS: session created"

- [ ] **Step 2: Read output using Recipe 3**

```bash
sleep 1
tmux capture-pane -t "$SESSION" -p | tail -5
```

Expected: output contains "hello from tmux skill test"

- [ ] **Step 3: Send input using Recipe 2**

```bash
tmux send-keys -t "$SESSION" -X cancel 2>/dev/null || true
tmux send-keys -t "$SESSION" -l -- "echo 'input received'"
sleep 0.2
tmux send-keys -t "$SESSION" Enter
sleep 0.3
tmux capture-pane -t "$SESSION" -p | tail -5
```

Expected: output contains "input received"

- [ ] **Step 4: Clean up using Recipe 5**

```bash
tmux kill-session -t "$SESSION" 2>/dev/null || true
flock ~/.local/share/tmux-skill/sessions.jsonl -c \
  "echo '{\"session\":\"$SESSION\",\"status\":\"closed\",\"closed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
```

- [ ] **Step 5: Verify registry**

```bash
grep "$SESSION" ~/.local/share/tmux-skill/sessions.jsonl
```

Expected: two entries — one with `"status":"active"`, one with `"status":"closed"`

- [ ] **Step 6: Verify session is gone**

```bash
tmux list-sessions -F '#{session_name}' | grep -qx "$SESSION" && echo "FAIL: session still exists" || echo "PASS: session cleaned up"
```

Expected: "PASS: session cleaned up"

---

### Task 5: Claude Code Session Verification

**Files:** None (integration test)

- [ ] **Step 1: Launch a Claude Code test session using Recipe 4**

```bash
SESSION="agent-claude-test-$(openssl rand -hex 2)"
mkdir -p ~/.local/share/tmux-skill
tmux new-session -d -s "$SESSION" -c /tmp "claude --dangerously-skip-permissions"
# Register in registry (see Recipe 1 step 5)
flock ~/.local/share/tmux-skill/sessions.jsonl -c \
  "echo '{\"session\":\"$SESSION\",\"created\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"creator\":\"$$\",\"bead\":\"kyle-dev-infra-4p8\",\"purpose\":\"claude session test\",\"workdir\":\"/tmp\",\"status\":\"active\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
```

- [ ] **Step 2: Wait for Claude to boot and verify it's running**

```bash
sleep 8
tmux capture-pane -t "$SESSION" -p | tail -15
```

Expected: Claude Code UI visible (prompt, status bar, or loading indicator)

- [ ] **Step 3: Send a simple test prompt**

```bash
tmux send-keys -t "$SESSION" -X cancel 2>/dev/null || true
tmux send-keys -t "$SESSION" -l -- "What is 2+2? Reply with just the number."
sleep 0.2
tmux send-keys -t "$SESSION" Enter
```

- [ ] **Step 4: Read the response**

```bash
sleep 15  # Claude needs time to respond
tmux capture-pane -t "$SESSION" -p -S -500 | tail -30
```

Expected: output contains "4" somewhere in Claude's response

- [ ] **Step 5: Exit Claude and clean up**

```bash
tmux send-keys -t "$SESSION" -l -- "/exit"
sleep 0.2
tmux send-keys -t "$SESSION" Enter
sleep 3
tmux kill-session -t "$SESSION" 2>/dev/null || true
flock ~/.local/share/tmux-skill/sessions.jsonl -c \
  "echo '{\"session\":\"$SESSION\",\"status\":\"closed\",\"closed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
rm -f /tmp/agent-${SESSION}-*.sh /tmp/agent-${SESSION}-*.txt
```

---

### Task 6: Multi-Agent Safety Verification

**Files:** None (isolation test)

- [ ] **Step 1: Create two independent agent sessions**

```bash
SESSION_A="agent-multi-a-$(openssl rand -hex 2)"
SESSION_B="agent-multi-b-$(openssl rand -hex 2)"
mkdir -p ~/.local/share/tmux-skill

tmux new-session -d -s "$SESSION_A" "echo 'I am session A' && sleep 300"
tmux new-session -d -s "$SESSION_B" "echo 'I am session B' && sleep 300"

# Register both
for S in "$SESSION_A" "$SESSION_B"; do
  flock ~/.local/share/tmux-skill/sessions.jsonl -c \
    "echo '{\"session\":\"$S\",\"created\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"creator\":\"$$\",\"bead\":\"kyle-dev-infra-4p8\",\"purpose\":\"multi-agent test\",\"workdir\":\"/home/orangepi\",\"status\":\"active\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
done
```

- [ ] **Step 2: Verify both exist independently**

```bash
tmux list-sessions -F '#{session_name}' | grep '^agent-multi'
```

Expected: both session names listed

- [ ] **Step 3: Verify output isolation**

```bash
sleep 1
OUTPUT_A=$(tmux capture-pane -t "$SESSION_A" -p | tail -5)
OUTPUT_B=$(tmux capture-pane -t "$SESSION_B" -p | tail -5)
echo "A: $OUTPUT_A"
echo "B: $OUTPUT_B"
```

Expected: A contains "I am session A", B contains "I am session B" — no cross-contamination

- [ ] **Step 4: Verify user sessions untouched**

```bash
tmux list-sessions -F '#{session_name}' | grep -E '^claude|^shell'
```

Expected: user sessions still exist, unmodified

- [ ] **Step 5: Clean up both sessions**

```bash
for S in "$SESSION_A" "$SESSION_B"; do
  tmux kill-session -t "$S" 2>/dev/null || true
  flock ~/.local/share/tmux-skill/sessions.jsonl -c \
    "echo '{\"session\":\"$S\",\"status\":\"closed\",\"closed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}' >> ~/.local/share/tmux-skill/sessions.jsonl"
done
```

- [ ] **Step 6: Verify cleanup**

```bash
tmux list-sessions -F '#{session_name}' | grep '^agent-multi' && echo "FAIL: sessions still exist" || echo "PASS: all agent sessions cleaned"
```

Expected: "PASS: all agent sessions cleaned"

---

### Task 7: Push to GitHub

**Files:** None (git operations)

- [ ] **Step 1: Final git status**

```bash
cd ~/projects/claude_plugins && git status
```

Expected: clean working tree (all committed)

- [ ] **Step 2: Push**

```bash
cd ~/projects/claude_plugins && git push
```

- [ ] **Step 3: Verify marketplace validator still passes**

```bash
cd ~/projects/claude_plugins && CLAUDE_PLUGIN_ROOT=. bash scripts/validate-marketplace.sh
```

Expected: no warnings
