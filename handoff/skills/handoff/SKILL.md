---
name: handoff
description: |
  This skill should be used when the user says "hand off", "handoff", "save context",
  "session handoff", "context is full", "switch sessions", "save and close", "pick this up later",
  "continue later", "wrap up session", or wants to preserve their current work context
  before closing Claude and starting a fresh session.
---

# Handoff Skill

Save the current session context so a fresh Claude session can pick up exactly where this one left off.

## When to Use

- User runs `/handoff` or `/handoff [notes]`
- User says they want to save context, switch sessions, or continue later
- User mentions context is getting full or compaction is losing detail

## Storage

- **Directory:** `/mnt/pi-data/claude-workspace/handoffs/`
- **Archive:** `/mnt/pi-data/claude-workspace/handoffs/archive/`
- **Backup:** Covered by pi-data Google Drive sync (backup-claude.sh)

## Instructions

When this skill activates, do the following:

### Step 1: Gather Context

Review the current conversation and identify:

1. **Session summary**: 2-3 sentence overview of what was happening this session
2. **Active goals**: What the user is trying to accomplish (the big picture)
3. **Unfinished work**: Tasks in progress, what's been done, what's left
4. **Key files**: Files that were being worked on (full absolute paths)
5. **Important decisions**: Any architectural, design, or strategic decisions made
6. **User's last intent**: What they were about to do or asked for last
7. **User notes**: If the user provided notes via `/handoff [notes]`, include them prominently

### Step 2: Generate Filename

**Convention:** `YYYY-MM-DDTHHMM-<bead-id>-<slug>.md`

1. Run `bd list --status=in_progress` to check for an active bead ID.
2. If a bead is active, include its ID (e.g., `kyle-dev-infra-234`).
3. If no bead, omit the bead portion.
4. Create a 3-5 word kebab-case slug summarizing the session's main work.

**Examples:**
- `2026-03-28T2042-kyle-dev-infra-234-fix-handoff-plugin.md`
- `2026-03-28T1530-treehouse-chat-ui-rebuild.md`
- `2026-03-29T0900-kyle-dev-infra-25j-total-recall-remote-push.md`

### Step 3: Write the Handoff Document

Format the context as a structured markdown document. Use this exact template:

```markdown
# Handoff Context

> Saved: YYYY-MM-DD HH:MM | Bead: <id or "none"> | Working dir: <pwd>

## Session Summary
[2-3 sentences]

## Active Goals
- [goal 1]
- [goal 2]

## Unfinished Work
- [ ] [task with status]
- [ ] [task with status]

## Key Files
- `/absolute/path/to/file1` - [what/why]
- `/absolute/path/to/file2` - [what/why]

## Important Decisions
- [decision and rationale]

## Last Intent
[What the user was about to do or asked for last]

## User Notes
[Any notes the user provided, or "None"]
```

### Step 4: Save to Two Places

**A) Save to claude-mem** for long-term searchable memory:

Use the `mcp__plugin_claude-mem_mcp-search__save_memory` tool with:
- `title`: "HANDOFF: [brief summary of session]"
- `text`: The full handoff document from Step 3
- `project`: Use the current project name if known, otherwise omit

**B) Save to handoff file** for immediate injection on next startup:

Use the `Write` tool to write the handoff document to:
`/mnt/pi-data/claude-workspace/handoffs/<filename from Step 2>`

Ensure the directory exists first: `mkdir -p /mnt/pi-data/claude-workspace/handoffs`

### Step 5: Confirm

Tell the user:
- Context has been saved (include the filename)
- They can safely close Claude and start a fresh session
- The next session will automatically see pending handoffs on startup
- The context is also saved to long-term memory for future reference

Keep the confirmation brief -- 2-3 lines max.

## Important

- Be thorough in capturing context but concise in presentation
- Use absolute file paths, never relative
- If the session was short or simple, the handoff can be brief too -- don't pad it
- Handoff files are NEVER deleted -- they are archived via /handoff-clear
- Multiple handoffs can coexist -- each session gets its own file
