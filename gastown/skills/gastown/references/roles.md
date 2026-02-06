# Gas Town Roles

## Town-Level Roles

### Mayor

Chief-of-staff agent responsible for:
- Initiating convoys
- Coordinating work distribution across rigs
- Notifying users of important events
- Cross-rig coordination

**Location**: `~/gt/mayor/`
**Identity**: `BD_ACTOR=mayor`
**Lifecycle**: Singleton, persistent

### Deacon

Daemon beacon running continuous patrol cycles:
- Ensures worker activity
- Monitors system health
- Triggers recovery when agents become unresponsive
- Dispatches Dogs for infrastructure tasks

**Location**: `~/gt/deacon/`
**Identity**: `BD_ACTOR=deacon`
**Lifecycle**: Singleton, persistent daemon

### Dogs

The Deacon's crew of maintenance agents:
- Handle background tasks (cleanup, health checks)
- NOT workers - infrastructure only
- **Boot**: Special Dog that checks the Deacon every 5 minutes

**Identity**: `BD_ACTOR=deacon-boot` (for Boot)
**Lifecycle**: Ephemeral, Deacon-managed

## Rig-Level Roles

### Polecat

Ephemeral worker agents that produce merge requests:
- Spawned for specific tasks
- Work in isolated git worktrees
- Cleaned up automatically on completion
- Monitored by Witness

**Location**: `~/gt/<rig>/polecats/<name>/rig/`
**Identity**: `BD_ACTOR=<rig>/polecats/<name>`
**Lifecycle**: Transient, Witness-managed

**When to use Polecats**:
- Discrete, well-defined tasks
- Batch work (tracked via convoys)
- Parallelizable work
- Work that benefits from supervision

### Crew

Long-lived, named agents for persistent collaboration:
- Maintain context across sessions
- Ideal for ongoing work relationships
- Human-managed lifecycle

**Location**: `~/gt/<rig>/crew/<name>/rig/`
**Identity**: `BD_ACTOR=<rig>/crew/<name>`
**Lifecycle**: Long-lived, user-managed

**When to use Crew**:
- Exploratory work
- Long-running projects
- Work requiring human judgment
- Tasks where you want direct control

### Witness

Patrol agent that oversees Polecats and Refinery:
- Monitors progress
- Detects stuck agents
- Triggers recovery actions
- No git clone (monitors only)

**Location**: `~/gt/<rig>/witness/`
**Identity**: `BD_ACTOR=<rig>/witness`
**Lifecycle**: One per rig, persistent

### Refinery

Manages the merge queue for a rig:
- Intelligently merges changes from Polecats
- Handles conflicts
- Ensures code quality before main branch

**Location**: `~/gt/<rig>/refinery/rig/`
**Identity**: `BD_ACTOR=<rig>/refinery`
**Lifecycle**: One per rig, persistent

## Crew vs Polecats

| Aspect | Crew | Polecat |
|--------|------|---------|
| **Lifecycle** | Persistent (user controls) | Transient (Witness controls) |
| **Monitoring** | None | Witness watches, nudges, recycles |
| **Work assignment** | Human-directed or self-assigned | Slung via `gt sling` |
| **Git state** | Pushes to main directly | Works on branch, Refinery merges |
| **Cleanup** | Manual | Automatic on completion |

## Dogs vs Crew

**Dogs are NOT workers**. Common misconception.

| Aspect | Dogs | Crew |
|--------|------|------|
| **Owner** | Deacon | Human |
| **Purpose** | Infrastructure tasks | Project work |
| **Scope** | Narrow, focused utilities | General purpose |
| **Lifecycle** | Very short (single task) | Long-lived |

If you need to do work in another rig, use **worktrees**, not dogs.

## Cross-Rig Work

### Option 1: Worktrees (Preferred)

```bash
gt worktree beads
# Creates ~/gt/beads/crew/gastown-joe/
# Identity preserved: BD_ACTOR = gastown/crew/joe
```

### Option 2: Dispatch to Local Workers

```bash
bd create --prefix beads "Fix authentication bug"
gt convoy create "Auth fix" bd-xyz
gt sling bd-xyz beads
```

| Scenario | Approach |
|----------|----------|
| Quick fix needed | Worktree |
| Work should appear in your CV | Worktree |
| Work should be done by target rig team | Dispatch |
