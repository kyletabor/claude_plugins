# Kyle's Claude Code Plugins

A collection of personal plugins for Claude Code, including custom agents, skills, and session analysis tools.

## Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| **kyle-custom** | Custom agents, skills, and commands for Claude Code | 0.6.0 |
| **session-historian** | Read and analyze Claude Code session history for debugging, continuity, and workflow analysis | 1.0.0 |

## Installation

### Install All Plugins

```bash
claude plugin add kyletabor/claude_plugins
```

This installs both plugins from the marketplace configuration.

### Install Individual Plugins

**kyle-custom** (root-level plugin):
```bash
claude plugin add kyletabor/claude_plugins
```

**session-historian**:
```bash
claude plugin add kyletabor/claude_plugins/session-historian
```

## Plugin Details

### kyle-custom

Custom agents, skills, and commands for Claude Code workflows. Includes:

- **architect** skill - Designs architecture and creates implementation tasks from epics/PRDs. Explores the codebase with parallel subagents, designs technical approach, and creates implementation task beads with step-by-step instructions.
- **beadmeister** skill - Creates execution-ready task beads from Architect output. Converts architecture specs into polecat work with molecular, executable steps.
- **architect** command - Slash command to invoke the architect skill
- **beadmeister** command - Slash command to invoke the beadmeister skill

### session-historian

Read and analyze Claude Code session history for debugging, continuity, and workflow analysis. Provides 6 Python scripts for listing, searching, summarizing, and analyzing sessions.

Session historian can help you:
- Debug issues by reviewing past sessions
- Continue work from previous conversations
- Analyze workflow patterns and agent behavior
- Search session history for specific topics or events

## Repository Structure

```
.
├── .claude-plugin/
│   ├── plugin.json          # kyle-custom plugin manifest
│   └── marketplace.json     # Multi-plugin marketplace config
├── skills/
│   ├── architect/           # Architecture and task decomposition skill
│   │   └── SKILL.md
│   └── beadmeister/         # Task bead creation skill
│       └── SKILL.md
├── session-historian/       # Session history analysis plugin
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── [session analysis scripts]
└── README.md
```

## Author

**Kyle Tabor**
- GitHub: [kyletabor](https://github.com/kyletabor)

## License

MIT
