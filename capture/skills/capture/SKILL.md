---
name: capture
description: Quick-capture a task, bookmark, idea, follow-up, or research item to your personal inbox. Use when the user says "/capture", "remember this", "add a task", "bookmark this", or wants to save something for later.
user_invocable: true
---

# Quick Capture

The user wants to capture something to their personal task inbox.

Take the user's text (from args or their message) and call the `capture` MCP tool from the `capture-mcp` server.

## How to categorize

Before calling the tool, analyze the text and determine:

1. **Category** — infer from content:
   - `bookmark` — URLs, "check out", "read this", "watch this"
   - `follow-up` — "follow up", "circle back", "ping", "ask about"
   - `idea` — "idea:", "what if", "could we", "feature idea"
   - `research` — "look into", "investigate", "compare", "evaluate"
   - `task` — default for actionable items

2. **URL** — extract any URL from the text

3. **Tags** — extract relevant tags from context (project names, topics)

4. **Title** — clean up the text into a concise title

## Call the tool

Use the `capture` MCP tool with these parameters:
- `text`: the raw user input
- `title`: cleaned up title
- `category`: inferred category
- `url`: extracted URL (if any)
- `tags`: relevant tags (if any)
- `source`: "claude-code"

## Confirm

After capturing, tell the user what was saved in ONE line:
> Captured: "[title]" (category) [tags if any]
