# Gas Town Plugin for Claude Code

A Claude Code plugin that teaches Claude how to operate within a Gas Town multi-agent orchestration environment.

## Overview

Gas Town is a multi-agent orchestration system for Claude Code that coordinates multiple Claude instances across projects using `gt` (agent operations) and `bd` (beads/data operations). This plugin provides the gastown skill that equips Claude with comprehensive knowledge of Gas Town's roles, commands, workflows, and the propulsion principle (GUPP: "If there is work on your Hook, YOU MUST RUN IT").

## Installation

```bash
claude plugin add kyletabor/claude_plugins/gastown
```

## What It Provides

This plugin provides a single skill (`gastown`) with 6 reference documents:

- **SKILL.md**: Quick orientation guide covering essential commands, role reference, work units, and the propulsion loop
- **commands.md**: Complete gt/bd CLI reference for all agent and beads operations
- **convoys.md**: Work tracking and batch assignment (both formula convoys and work convoys)
- **formulas.md**: Reusable workflow templates and formula patterns
- **molecules.md**: Multi-step workflow lifecycle and execution
- **propulsion.md**: Deep dive into the propulsion principle (GUPP) and hook contracts
- **roles.md**: Detailed documentation for all agent roles (Mayor, Deacon, Witness, Polecat, Crew, Refinery)

## When This Plugin Is Useful

Use this plugin when:

- Working in a Gas Town multi-agent environment
- Claude needs to understand and execute gt/bd commands
- Operating as a specific Gas Town agent role (Polecat, Crew, etc.)
- Managing convoys, molecules, or beads
- Following the propulsion principle and hook contracts
- Coordinating work across multiple Claude instances

## Prerequisites

Requires Gas Town to be installed and configured:

- `gt` CLI tool (agent operations)
- `bd` CLI tool (beads/data operations)
- Gas Town directory structure at `~/gt/`

See the [Gas Town repository](https://github.com/steveyegge/gastown) for installation instructions.

## Key Concepts

**GUPP (Propulsion Principle)**: If there is work on your Hook, YOU MUST RUN IT. No waiting for confirmation.

**Work Units**:
- **Bead**: Atomic work unit (issue/task), git-backed
- **Formula**: Reusable workflow template (TOML source)
- **Molecule**: Multi-step workflow instance
- **Hook**: Agent's primary work queue
- **Convoy**: Batch of related beads for tracking

**Agent Roles**:
- **Mayor**: Town coordinator, initiates convoys (persistent)
- **Deacon**: Background supervisor, health checks (persistent daemon)
- **Witness**: Monitors polecats per rig (persistent)
- **Refinery**: Merge queue processor (persistent)
- **Polecat**: Ephemeral worker with worktree (transient)
- **Crew**: Persistent human workspace (long-lived)

## Author

- Gas Town created by Steve Yegge (https://github.com/steveyegge)
- Plugin maintained by Kyle Tabor

## License

MIT
