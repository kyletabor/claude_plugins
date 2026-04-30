---
name: capture
description: >
  This skill should be used when the user says "/capture", "remember this",
  "add a task", "bookmark this", "save this for later", "follow up on",
  "idea:", "look into", or wants to quickly save a task, bookmark, idea,
  follow-up, or research item to their personal capture inbox.
user_invocable: true
argument-hint: "<text to capture>"
allowed-tools:
  - "mcp__capture-mcp__capture"
  - "mcp__capture-mcp__list"
  - "mcp__capture-mcp__search"
  - "mcp__capture-mcp__digest"
  - "mcp__capture-mcp__update"
  - "mcp__capture-mcp__done"
  - "mcp__capture-mcp__delete"
  - "mcp__capture-mcp__promote"
---

# Quick Capture

Capture a task, bookmark, idea, follow-up, or research item to the personal inbox with zero friction.

## What belongs here vs elsewhere

| Content | Go to |
|---------|-------|
| Fleeting thought, bookmark, idea, "remind me later" | **capture-mcp** (this skill) — one line is fine |
| Kyle said "that was friction" — something annoying/broken in how we worked | **capture-mcp** with `friction` tag, then later promote to `friction-graph.db` |
| A skill/gate/process **failed to fire** when it should have | **CAPA** — invoke `/capa`, not capture |
| Same failure pattern recurring, or "done" claimed but doesn't work | **CAPA** — invoke `/capa` |
| Engineering task with dependencies or multi-session work | **beads** — `bd create` |

**Keep captures short.** One-line capture is the goal. If you catch yourself writing a multi-paragraph "root cause / steps to fix" block inside a capture, that's CAPA-shaped content — stop and invoke `/capa` instead. Captures are the inbox, not the investigation.

## Capture Flow

1. Take the user's raw text (from args or message)
2. Analyze content to determine structured fields (see Categorization below)
3. Call the `mcp__capture-mcp__capture` tool
4. Confirm in ONE line: `Captured: "[title]" (category) [tags if any]`

## Categorization

Before calling the capture tool, infer these fields from the text:

**Category** — determine from content:
- `bookmark` — contains URLs, or phrases like "check out", "read this", "watch this"
- `follow-up` — "follow up", "circle back", "ping", "ask about", "remind me"
- `idea` — "idea:", "what if", "could we", "feature idea", "maybe we should"
- `research` — "look into", "investigate", "compare", "evaluate", "explore"
- `task` — default for anything actionable that doesn't match above

**URL** — extract any URL present in the text

**Tags** — infer relevant tags from context (project names, topics, tech)

**Title** — clean the raw text into a concise title (strip filler words, normalize)

## Tool Parameters

Call `mcp__capture-mcp__capture` with:
- `text` (required) — the raw user input
- `title` — cleaned-up title
- `category` — inferred category from above
- `url` — extracted URL if present
- `tags` — array of relevant tags
- `source` — always `"claude-code"`

## Other Operations

When the user asks about their captures rather than adding new ones:

- "What's in my inbox?" → call `mcp__capture-mcp__list` with no status filter or `status: "inbox"`
- "Search captures for X" → call `mcp__capture-mcp__search` with query
- "Give me my digest" → call `mcp__capture-mcp__digest`
- "Mark X as done" → call `mcp__capture-mcp__done` with the item ID
- "Update priority on X" → call `mcp__capture-mcp__update`
- "Delete X" → call `mcp__capture-mcp__delete`
- "Promote X to beads" → call `mcp__capture-mcp__promote`

## Response Format

Keep responses minimal — one line for captures, a short table for lists. The user has ADHD; walls of text are harmful.
