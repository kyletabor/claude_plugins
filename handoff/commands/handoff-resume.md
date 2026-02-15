---
name: handoff-resume
description: Load saved handoff context from a previous session
---

Read the file `~/.claude/handoff-context.md` and summarize what was in progress. Then ask the user what they'd like to pick up first.

If the file doesn't exist, tell the user there's no handoff context saved.

Do NOT delete the file — it stays until the user explicitly runs /handoff-clear.
