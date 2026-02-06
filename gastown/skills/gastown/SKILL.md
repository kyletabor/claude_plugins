---
name: gastown
description: >
  Multi-agent orchestration system for coordinating Claude Code instances across projects.
  Use when working in a Gas Town environment, managing polecats/crew, using gt/bd commands,
  understanding convoys, molecules, or the propulsion principle.
---

# Gas Town - Multi-Agent Orchestration for Claude Code

Gas Town coordinates multiple Claude Code instances across projects using `gt` (agent operations) and `bd` (beads/data operations).

## Core Principles

| Principle | Meaning |
|-----------|---------|
| **GUPP** | "If there is work on your Hook, YOU MUST RUN IT." No waiting for confirmation. |
| **MEOW** | Break large goals into atomic, trackable units (beads/molecules). |
| **NDI** | Eventual completion despite unreliable individual operations. |

**The Hook Contract**: When you find work on your hook, EXECUTE IMMEDIATELY. The hook IS your assignment.

## Quick Orientation

```bash
gt hook              # What's on my hook?
bd mol current       # Where am I in the molecule?
bd ready             # What step is next?
bd show <step-id>    # What does this step require?
```

## The Propulsion Loop

```
1. gt hook                    # What's hooked?
2. bd mol current             # Where am I?
3. Execute step
4. bd close <step> --continue # Close and auto-advance
5. GOTO 2
```

## Role Quick Reference

| Role | Purpose | Lifecycle |
|------|---------|-----------|
| **Mayor** | Town coordinator, initiates convoys | Persistent, town-level |
| **Deacon** | Background supervisor, health checks | Persistent, daemon |
| **Witness** | Monitors polecats per rig | Persistent, per-rig |
| **Refinery** | Merge queue processor | Persistent, per-rig |
| **Polecat** | Ephemeral worker with worktree | Transient, Witness-managed |
| **Crew** | Persistent human workspace | Long-lived, user-managed |

See [references/roles.md](references/roles.md) for detailed role documentation.

## Essential Commands

### Agent Operations (gt)

```bash
gt hook                      # What's on my hook
gt convoy list               # Active work batches
gt convoy create "name" <ids> # Create work batch
gt sling <bead> <rig>        # Assign work to agent
gt handoff                   # Session cycling
gt mail inbox                # Check messages
gt escalate "topic"          # Escalate issue
```

### Beads Operations (bd)

```bash
bd ready                     # Unblocked work
bd show <id>                 # Issue details
bd create --title="..."      # Create issue
bd update <id> --status=...  # Update status
bd close <id> --continue     # Close and advance
bd sync                      # Push/pull to git
```

See [references/commands.md](references/commands.md) for full CLI reference.

## Work Units

| Type | Persistence | Purpose |
|------|-------------|---------|
| **Bead** | Git-backed | Atomic work unit (issue/task) |
| **Formula** | TOML source | Reusable workflow template |
| **Molecule** | Persistent | Multi-step workflow instance |
| **Wisp** | Ephemeral | Lightweight transient work |
| **Hook** | Pinned | Agent's primary work queue |
| **Convoy** | Tracking | Batch of related beads |

See [references/molecules.md](references/molecules.md) for workflow details.

## ⚠️ Terminology: "Convoy" Has Two Meanings

**IMPORTANT**: The word "convoy" refers to TWO completely different concepts:

| Context | What It Is | Command | File/Bead Type |
|---------|-----------|---------|----------------|
| **Formula convoy** | Parallel execution pattern in Beads formulas | `bd mol pour <formula>` | `.formula.toml` with `type = "convoy"` |
| **Work convoy** | Issue tracking unit in Gastown | `gt convoy create` | `hq-cv-*` bead |

### Formula Convoy (Beads Concept)
- **Purpose**: Execute multiple tasks in parallel, then synthesize results
- **Structure**: Multiple `[[legs]]` + one `[synthesis]` step
- **Example**: `code-review.formula.toml` - 10 reviewers analyze code in parallel, synthesis combines findings
- **Used in**: Multi-perspective analysis (design exploration, code review, architecture options)

### Work Convoy (Gastown Concept)
- **Purpose**: Track batch of related issues across rigs for visibility
- **Structure**: Single `hq-cv-*` bead that tracks multiple issue IDs
- **Example**: `gt convoy create "Feature X" gt-abc gt-def` - dashboard shows progress
- **Used in**: Monitoring work completion, cross-rig coordination, notifications

### How They Can Work Together
A formula convoy can create issues that get tracked by a work convoy:

```bash
# 1. Pour a convoy formula (parallel design exploration)
bd mol pour design-convoy --var feature="auth"
# Creates: design.explore-1, design.explore-2, design.arch, design.synthesis

# 2. Create work convoy to track all those issues
gt convoy create "Design: Auth feature" design.explore-1 design.explore-2 design.arch design.synthesis

# 3. Sling each leg to spawn polecats
gt sling design.explore-1 gastown
gt sling design.explore-2 gastown
# etc.

# 4. gt convoy status shows progress across all legs
```

**Bottom line**: They're separate layers. Formula convoy = execution pattern. Work convoy = tracking mechanism.

## Directory Structure

```
~/gt/                           Town root
├── .beads/                     Town-level beads (hq-* prefix)
├── mayor/                      Mayor agent home
├── deacon/                     Deacon daemon home
└── <rig>/                      Project container (NOT a clone)
    ├── .repo.git/              Bare repo (shared by worktrees)
    ├── mayor/rig/              Canonical clone (beads live here)
    ├── refinery/rig/           Worktree on main
    ├── witness/                Monitor (no clone)
    ├── crew/<name>/rig/        Human workspaces
    └── polecats/<name>/rig/    Worker worktrees
```

## Startup Behavior

1. Check hook (`gt hook`)
2. Work hooked -> EXECUTE immediately
3. Hook empty -> Check mail for attached work
4. Nothing anywhere -> ERROR: escalate to Witness

## Session Cycling

When context fills or you finish a chunk:

```bash
/handoff                    # Or gt handoff
```

**What persists**: Hooked molecule, beads state, git state
**What resets**: Conversation context, TodoWrite items, in-memory state

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GT_ROLE` | Agent role (mayor, witness, polecat, crew) |
| `GT_ROOT` | Town root directory |
| `GT_RIG` | Current rig name |
| `BD_ACTOR` | Agent identity for attribution |

## Resources

| Resource | Content |
|----------|---------|
| [roles.md](references/roles.md) | Detailed role documentation |
| [convoys.md](references/convoys.md) | Work tracking and assignment |
| [formulas.md](references/formulas.md) | Formula types and patterns |
| [molecules.md](references/molecules.md) | Formulas and workflow lifecycle |
| [propulsion.md](references/propulsion.md) | The propulsion principle deep dive |
| [commands.md](references/commands.md) | Full CLI reference |

## Full Documentation

- **gt --help**: Command overview
- **bd prime**: AI-optimized workflow context
- **GitHub**: [github.com/steveyegge/gastown](https://github.com/steveyegge/gastown)
