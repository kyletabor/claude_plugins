---
name: handoff-clear
description: Archive handoff context (files are preserved, not deleted)
allowed-tools: ["Bash", "Glob"]
argument-hint: [filename, "all", or blank for interactive]
---

# Clear Handoff

Archive pending handoff files. Files are moved to the archive directory, never deleted.

## Input

User argument: $ARGUMENTS

## Execute

1. List active handoffs: `ls -t /mnt/pi-data/claude-workspace/handoffs/*.md 2>/dev/null`
2. If no active handoffs, tell the user there's nothing to clear.
3. Based on the argument:
   - **Specific filename**: Move that file to `/mnt/pi-data/claude-workspace/handoffs/archive/`
   - **"all"**: Move all active `.md` files to `archive/`
   - **Blank/no argument**: If one file, archive it. If multiple, list them and ask which to archive (or "all").
4. Confirm what was archived.
