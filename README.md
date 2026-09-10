# Kyle's Claude Code Plugins

A marketplace of plugins for [Claude Code](https://docs.claude.com/en/docs/claude-code) that add structured development workflows, verification gates, session continuity, learning tools, and productivity shortcuts. Built by Kyle Tabor for daily use and shared publicly. Marketplace name: **`kyle-plugins`**.

## Installation

Add the marketplace once, then install whichever plugins you want. Inside Claude Code:

```
/plugin marketplace add kyletabor/claude_plugins
/plugin install dev-process@kyle-plugins
```

Or from your shell:

```bash
claude plugin marketplace add kyletabor/claude_plugins
claude plugin install dev-process@kyle-plugins
```

Browse everything with `/plugin`, and pull updates with `/plugin marketplace update kyle-plugins`. Plugins are cached by version, so a new version only lands after a restart.

## Which plugins should I try?

Two groups. The first works anywhere. The second is built around my own machine and tooling and is here for reference or to fork.

### General purpose

| Plugin | Version | What it does |
|--------|---------|--------------|
| **[dev-process](dev-process/)** | 2.4.1 | Right-sized development pipeline: spec, review, implement, verify. The orchestrator the rest plug into. Gate tracking uses the [beads](https://github.com/steveyegge/beads) `bd` CLI. |
| **[verification-hooks](verification-hooks/)** | 1.5.2 | Hooks that block "done" until an independent agent has checked the work. The close gate targets the beads `bd` CLI. |
| **[pre-mortem](pre-mortem/)** | 1.1.0 | Define success and failure criteria before starting multi-step work. |
| **[fable-mode](fable-mode/)** | 0.1.1 | Judgment habits as skills and Stop hooks: check preconditions, answer first, prove UI changes, never hand back uncommitted work. |
| **[session-historian](session-historian/)** | 1.0.1 | Read and analyze past Claude Code sessions: search, find errors, cross-session patterns. |
| **[tmux](tmux/)** | 1.0.0 | Let Claude drive tmux sessions safely for testing and verification. |
| **[educate-me](educate-me/)** | 1.1.0 | A 1-on-1 tutor that teaches any topic step by step with a MECE outline. |
| **[secret-vault](secret-vault/)** | 0.1.1 | Experimental. Catch secrets pasted in chat and store them outside the transcript. |

### Personal / infrastructure-specific

These depend on services, paths, or conventions on my machine. Read them for ideas; they will not work out of the box.

| Plugin | Version | What it does | Depends on |
|--------|---------|--------------|------------|
| **[capture](capture/)** | 1.1.0 | Quick-capture tasks, bookmarks, and ideas to a personal inbox. | A `capture-mcp` MCP server (not in this repo) |
| **[deploy-standard](deploy-standard/)** | 1.1.0 | Enforces my deploy layout with a PreToolUse hook and SessionStart audit. | `/opt` symlink layout, `/mnt/pi-data`, a `deploy` CLI |
| **[total-recall](total-recall/)** | 0.1.1 | Front door to my externalized memory system. | The Total Recall backend |
| **[friction](friction/)** | 0.1.1 | Mines session transcripts for AI friction moments and logs them to a knowledge graph. | Total Recall, piDocs, a local SQLite graph |
| **[handoff](handoff/)** | 1.2.0 | Save session context and resume in a fresh session without losing the thread. | Handoff directory under `/mnt/pi-data`, claude-mem |
| **[capa](capa/)** | 1.0.0 | Corrective and Preventive Action: fix the broken process first, then the defect. | SQLite tracking DB under `/mnt/pi-data` |
| **[gastown](gastown/)** | 1.1.0 | Deprecated. Multi-agent orchestration for Gas Town. Kept for reference only. | Gas Town v0.7 (abandoned upstream) |

## Plugin details

### dev-process

The single orchestrator for non-trivial implementation work. Phase 0 classifies the task by size and risk into Tier S, M, or L, then runs only the process that tier needs: a one-line pre-mortem and a machine gate for small work, the full spec / review / implement / independent-verify pipeline for large or risky work. Ships an `independent-verifier` agent that cannot edit code, plus an extensible Verification Suite of gates (`config/verification-gates.json`) that `verification-hooks` enforces.

Invoke: `/dev-process` or just say "implement this" / "build this feature".

### verification-hooks

Stops Claude from claiming "done" without proof. A PreToolUse hook gates issue closure, a TaskCompleted agent hook re-checks completed tasks sized to blast radius, and a PostToolUse logger records evidence. Includes a read-only `independent-verifier` agent and an `analyze-verification.sh` report. Pairs with dev-process but runs standalone.

### pre-mortem

Before multi-step work, Claude writes down what success looks like, how it would fail, what it is assuming, and how it will verify. Depth scales from one line to a full card. Based on Gary Klein's prospective hindsight research.

Invoke: `/pre-mortem <task>` or "how could this go wrong?"

### fable-mode

Four skills and two Stop hooks that encode judgment habits for working with an executive-style user: `precondition-check` (verify the premise before recommending), `executive-mode` (act versus ask, clean handbacks), `last-screen` (answer first, one screen, jargon defined), and `but-for-real` (hostile self-review before claiming done). The `rendered-proof` hook demands pixel evidence for UI edits; `session-exit-hygiene` blocks silent uncommitted handbacks. Each skill ships with evals.

### handoff

`/handoff` saves goals, unfinished work, key files, and decisions to a handoff file. A SessionStart hook injects it into the next session. `/handoff-resume` and `/handoff-clear` manage it explicitly.

### session-historian

Six Python scripts over `~/.claude/projects/`: list sessions, search text, find errors, pull deep context, summarize, and run cross-session analysis. Has a pytest suite.

Invoke: "what did the last session do", "find sessions about X".

### tmux

Recipes for creating, driving, reading, and cleaning up tmux sessions, with a registry so Claude only touches sessions it created. Built for verifying plugins in a fresh Claude Code session.

### educate-me

Structured tutoring: builds a MECE outline of 3 to 5 sections, teaches one concept at a time, checks understanding, and closes with vocabulary and next steps. Works on topics, URLs, or local files.

Invoke: `/educate-me <topic or URL>`.

### capa

Eight-phase Corrective and Preventive Action investigation for when the *process* failed: the same bug recurs, "done" was claimed but nothing works, a gate did not fire. Tracks root causes and fixes in a SQLite database.

Invoke: `/capa <what broke>`.

### secret-vault (experimental)

A UserPromptSubmit hook watches for API keys, tokens, and passwords pasted into chat and moves them to `~/.secrets/` with restricted permissions. Redaction and storage are still being hardened.

Invoke: `/secret`, or paste a secret and the hook catches it.

## Guides

- **[Statusline setup](docs/statusline-setup.md)**: a two-line statusline with context bar, git branch, model, session duration, lines changed, total tokens, and weekly rate limit. Full script and JSON field reference.

## Repository layout

```
claude_plugins/
├── .claude-plugin/marketplace.json   # registry: every plugin must be listed here
├── <plugin>/
│   ├── .claude-plugin/plugin.json    # manifest; version must match marketplace.json
│   ├── README.md
│   ├── skills/<name>/SKILL.md
│   ├── commands/ agents/ hooks/      # optional
│   └── tests/                        # optional
└── docs/
```

## Contributing

Issues and pull requests are welcome. To add or update a plugin: bump the version in both the plugin's `plugin.json` and its `marketplace.json` entry, then run `bash verification-hooks/scripts/validate-marketplace.sh` from a plugin directory (or set `CLAUDE_PLUGIN_ROOT`) to confirm every plugin is registered.

## License

MIT. Copyright Kyle Tabor. The `gastown` plugin was originally authored by Steve Yegge under MIT.
