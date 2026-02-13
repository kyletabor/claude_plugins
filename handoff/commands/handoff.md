---
name: handoff
description: Save session context and hand off to a fresh Claude session
allowed-tools: ["Write", "Read", "Bash", "Glob", "Grep", "mcp__plugin_claude-mem_mcp-search__save_memory"]
argument-hint: [optional notes about current work]
---

# Handoff

Save the current session's context so a fresh Claude session can pick up where you left off.

## Input

User notes (if any): $ARGUMENTS

## Execute

Follow the handoff skill instructions to:

1. **Gather** the current session context (goals, unfinished work, key files, decisions, last intent)
2. **Include** any user-provided notes from the arguments above
3. **Save** to both claude-mem (long-term) and `~/.claude/handoff-context.md` (immediate injection)
4. **Confirm** to the user that context is saved and they can safely close and restart

The next Claude session will automatically receive the saved context via the SessionStart hook.
