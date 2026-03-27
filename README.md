# Kyle's Claude Code Plugins

A collection of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that add structured development workflows, session management, learning tools, and productivity shortcuts. Built by Kyle Tabor for daily use -- shared publicly for anyone who wants to get more out of Claude Code.

## Plugins

| Plugin | Version | Status | Description |
|--------|---------|--------|-------------|
| **dev-process** | 2.0.0 | Stable | Spec-driven development pipeline with review gates and independent verification |
| **capture** | 1.1.0 | Stable | Quick-capture tasks, bookmarks, ideas, and follow-ups to a personal inbox |
| **handoff** | 1.1.0 | Stable | Save session context and resume in a fresh Claude session without losing continuity |
| **capa** | 1.0.0 | Stable | Corrective and Preventive Action process for investigating broken processes |
| **educate-me** | 1.0.0 | Stable | Structured 1-on-1 tutor that teaches any subject using a MECE framework |
| **session-historian** | 1.0.0 | Stable | Read and analyze Claude Code session history for debugging and workflow analysis |
| **secret-vault** | 0.1.0 | Experimental | Intercept and securely store secrets pasted in chat, auto-redact from logs |
| **gastown** | 1.1.0 | Deprecated | Multi-agent orchestration for Gas Town environments (abandoned due to upstream bugs) |

## Installation

Install all plugins from the marketplace:

```bash
claude plugin add kyletabor/claude_plugins
```

Install an individual plugin:

```bash
claude plugin add kyletabor/claude_plugins/dev-process
claude plugin add kyletabor/claude_plugins/capture
claude plugin add kyletabor/claude_plugins/handoff
# etc.
```

## Plugin Details

### dev-process

The single orchestrator for all non-trivial implementation work. Runs a six-phase pipeline: Architecture Spec, Spec Review, Implementation, Code Review, Testing + Independent Verification, and Ship. It coordinates sub-skills (brainstorming, TDD, subagent-driven development, verification) so you don't invoke them separately. Use it any time you're building something that touches multiple files or needs architecture before coding.

Invoke: `/dev-process` or just ask Claude to "implement this" / "build this feature".

### capture

Zero-friction inbox for things you want to remember later. Say "bookmark this", "add a task", "idea: ...", or "follow up on ..." and it captures the item with auto-categorization (task, bookmark, idea, follow-up, research). Backed by an MCP server with search, digest, and promotion to a full task tracker.

Invoke: `/capture <text>` or use natural language like "remember this for later".

### handoff

Saves your current session context -- active goals, unfinished work, key files, decisions made -- so a fresh Claude session can pick up exactly where you left off. Useful when context gets long or you need to switch machines. The handoff file auto-injects on the next session start.

Invoke: `/handoff` or say "save context" / "pick this up later".

### capa

Corrective and Preventive Action -- an eight-phase process for when your development process itself fails. Not for simple bugs (use systematic-debugging for those). Use CAPA when the same failure pattern recurs, when "done" was claimed but the feature doesn't work, or when a gate failed to fire. Tracks root causes, research, process fixes, and re-execution in a shared SQLite database.

Invoke: `/capa <what broke>` or say "why did this fail again" / "do a retrospective".

### educate-me

A structured 1-on-1 tutor that teaches any subject step-by-step. Organizes material into a MECE (Mutually Exclusive, Completely Exhaustive) framework with 3-5 major sections, teaches one concept at a time, checks understanding before moving on, and wraps up with a vocabulary list and next steps. Works with topics, URLs, or local files.

Invoke: `/educate-me <topic or URL>` or say "teach me about X" / "walk me through this".

### session-historian

Six Python scripts for reading and analyzing Claude Code session history stored in `~/.claude/projects/`. List recent sessions, search conversation text, find errors, get deep context for debugging, and run cross-session pattern analysis. Useful for understanding what past agents did, continuing interrupted work, or spotting recurring failure patterns.

Invoke: `/session-historian` or ask "what did the last session do" / "find sessions about X".

### secret-vault (Experimental)

Early-stage plugin for intercepting secrets (API keys, tokens, passwords) pasted into chat and storing them securely in `~/.secrets/` with restricted permissions. Includes a UserPromptSubmit hook that catches common secret patterns automatically. Not yet feature-complete -- use with the understanding that the redaction and storage mechanisms are still being hardened.

Invoke: `/secret` for the guided flow, or paste a secret and the hook catches it.

### gastown (Deprecated)

Multi-agent orchestration plugin for Gas Town environments. Originally created by Steve Yegge, this plugin taught Claude how to operate with Gas Town roles (Mayor, Polecat, Crew, etc.) and coordinate across multiple Claude instances. **Deprecated and no longer maintained** -- Gas Town v0.7 has unfixable bugs that make it unreliable. Kept in the repo for reference only.

## Repository Structure

```
claude_plugins/
├── .claude-plugin/
│   └── marketplace.json      # Multi-plugin marketplace registry
├── capture/                   # Quick-capture inbox plugin
├── capa/                      # Corrective and Preventive Action plugin
├── dev-process/               # Structured development pipeline plugin
├── educate-me/                # MECE tutoring plugin
├── gastown/                   # Multi-agent orchestration (deprecated)
├── handoff/                   # Session context handoff plugin
├── secret-vault/              # Secret interception plugin (experimental)
├── session-historian/         # Session history analysis plugin
└── README.md
```

Each plugin directory contains its own `.claude-plugin/plugin.json` manifest, a `skills/` directory with `SKILL.md` files, and optionally `commands/`, `agents/`, `hooks/`, and `references/` directories.

## Author

**Kyle Tabor** -- [github.com/kyletabor](https://github.com/kyletabor)

## License

MIT
