---
name: handoff-resume
description: Load saved handoff context from a previous session
allowed-tools: ["Read", "Bash", "Glob"]
---

# Resume Handoff

## Execute

1. List all active handoff files: `ls -t /mnt/pi-data/claude-workspace/handoffs/*.md 2>/dev/null`
2. If no files found, tell the user there's no handoff context pending.
3. If one file, read it and summarize what was in progress. Ask the user what they'd like to pick up first.
4. If multiple files, read them all and present a brief summary of each (filename, age, session summary). Use your judgment:
   - If one clearly matches the current session context, pick it up and summarize.
   - If ambiguous, ask the user which handoff to resume.
5. Do NOT archive or delete handoff files — they stay until the user explicitly runs /handoff-clear.
