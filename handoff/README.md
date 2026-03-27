# Handoff

Save session context so a fresh Claude session can pick up exactly where you left off.

## What It Does

Handoff captures your current session state -- active goals, unfinished work, key files, decisions, and last intent -- and saves it to both long-term memory (claude-mem) and a handoff file. The next Claude session automatically receives this context on startup via a SessionStart hook, giving seamless continuity across sessions. Use it when context is getting full, you need to switch tasks, or you want to continue later.

## Components

- **Skills:** `handoff` -- context gathering and structured save workflow
- **Commands:** `/handoff [notes]` -- save context with optional notes; `/handoff-resume` -- load saved context from a previous session; `/handoff-clear` -- delete saved handoff context
- **Hooks:** `SessionStart` -- automatically injects saved handoff context when a new session begins

## Usage

### Save Context

Trigger with `/handoff` or `/handoff [notes about current work]`, or say:

- "Save context"
- "Pick this up later"
- "Context is full"
- "Wrap up session"

### Resume in a New Session

Context is automatically injected on session start. You can also explicitly run:

- `/handoff-resume` -- read and summarize the saved context
- `/handoff-clear` -- dismiss saved context when you no longer need it

### What Gets Saved

- Session summary (2-3 sentences)
- Active goals
- Unfinished work with status
- Key file paths (absolute)
- Important decisions and rationale
- User's last intent
- Any notes provided via the command

Context is saved to `~/.claude/handoff-context.md` for immediate injection and to claude-mem for long-term searchable memory.

## Installation

From the kyle-plugins marketplace -- already included if you have kyle-plugins installed.
