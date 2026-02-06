# Convoys - Work Tracking in Gas Town

> **Note**: This documents **work convoys** (`gt convoy`). For **formula convoys** (`type = "convoy"` in formulas), see [formulas.md](formulas.md).

A **work convoy** is how you track batched work in Gas Town. When you kick off work - even a single issue - create a convoy to track it.

## Why Convoys Matter

- Single view of "what's in flight"
- Cross-rig tracking (convoy in hq-*, issues in gt-*, bd-*)
- Auto-notification when work lands
- Historical record of completed work

## Creating Convoys

```bash
# Create convoy tracking multiple issues
gt convoy create "Feature X" gt-abc gt-def --notify overseer

# Quick sling (auto-creates convoy for visibility)
gt sling <bead> <rig>
```

## Monitoring Progress

```bash
# Dashboard of active convoys
gt convoy list

# Detailed status of specific convoy
gt convoy status hq-cv-abc

# Include landed/completed convoys
gt convoy list --all
gt convoy list --status=closed
```

## Work Assignment (Slinging)

```bash
# Assign issue to a rig (spawns polecat)
gt sling gt-abc gastown

# Override agent runtime for this assignment
gt sling gt-abc gastown --agent codex

# Assign with workflow template
gt sling <proto> --on gt-def <rig>
```

## Convoy Lifecycle

1. **Created**: `gt convoy create "name" <issues...>`
2. **Active**: Issues being worked by assigned agents
3. **Landed**: All issues closed, convoy completes

The "swarm" is ephemeral - just the workers currently assigned to a convoy's issues. When issues close, the convoy lands.

## Communication

### Mail System

```bash
gt mail inbox                    # Check messages
gt mail read <id>                # Read specific message
gt mail send <addr> -s "Subject" -m "Body"
gt mail send --human -s "..."    # To overseer
```

### Real-Time Messaging

```bash
gt nudge <agent> "message"       # Send immediate message
gt peek <agent>                  # Check agent health
```

### Escalation

```bash
gt escalate "topic"              # Default: MEDIUM severity
gt escalate -s CRITICAL "msg"    # Urgent, immediate attention
gt escalate -s HIGH "msg"        # Important blocker
```

## Session Management

### Handoff (Session Cycling)

```bash
gt handoff                       # Request fresh session
gt handoff --shutdown            # Terminate (polecats)
```

### Seance (Talk to Predecessors)

```bash
gt seance                        # List discoverable predecessor sessions
gt seance --talk <id>            # Talk to predecessor (full context)
gt seance --talk <id> -p "Where is X?"  # One-shot question
```

## Beads Routing

Gas Town routes beads commands based on issue ID prefix:

```bash
bd show gp-xyz    # Routes to greenplace rig's beads
bd show hq-abc    # Routes to town-level beads
bd show wyv-123   # Routes to wyvern rig's beads
```

| Prefix | Routes To | Purpose |
|--------|-----------|---------|
| `hq-*` | `~/gt/.beads/` | Mayor mail, cross-rig coordination |
| `<rig>-*` | `~/gt/<rig>/mayor/rig/.beads/` | Rig-specific issues |
