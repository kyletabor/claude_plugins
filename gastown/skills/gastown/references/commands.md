# Gas Town CLI Reference

**Principle**: `gt` = agent operations, `bd` = beads/data operations.

For complete syntax, use `gt --help` and `bd --help`.

## Town Management (gt)

```bash
gt install [path]            # Create town
gt install --git             # With git init
gt doctor                    # Health check
gt doctor --fix              # Auto-repair
```

## Rig Management (gt)

```bash
gt rig add <name> <url>      # Add project
gt rig list                  # List projects
gt rig remove <name>         # Remove project
```

## Convoy Management (gt)

```bash
gt convoy list               # Dashboard of active convoys
gt convoy status [id]        # Show progress
gt convoy create "name" [ids]  # Create convoy
gt convoy create "name" gt-a --notify mayor/  # With notification
gt convoy list --all         # Include landed convoys
gt convoy list --status=closed  # Only landed convoys
```

## Work Assignment (gt)

```bash
gt sling <bead> <rig>        # Assign to polecat
gt sling <bead> <rig> --agent codex  # Override agent
gt sling <proto> --on <bead> <rig>   # With workflow template
```

## Communication (gt)

```bash
gt mail inbox                # Check messages
gt mail read <id>            # Read message
gt mail send <addr> -s "Subject" -m "Body"
gt mail send --human -s "..."  # To overseer
gt nudge <agent> "message"   # Real-time message
gt peek <agent>              # Check health
```

## Escalation (gt)

```bash
gt escalate "topic"          # Default: MEDIUM severity
gt escalate -s CRITICAL "msg"  # Urgent
gt escalate -s HIGH "msg"    # Important blocker
gt escalate -s MEDIUM "msg" -m "Details..."
```

## Sessions (gt)

```bash
gt handoff                   # Request session cycle
gt handoff --shutdown        # Terminate (polecats)
gt session stop <rig>/<agent>
gt seance                    # List predecessor sessions
gt seance --talk <id>        # Talk to predecessor
gt seance --talk <id> -p "Where is X?"  # One-shot question
```

## Hook & Molecule (gt)

```bash
gt hook                      # What's on my hook
gt mol current               # Current step
gt mol progress <id>         # Execution progress
gt mol attach <bead> <mol>   # Pin molecule to bead
gt mol detach <bead>         # Unpin molecule
gt mol burn                  # Burn attached molecule
gt mol squash                # Squash attached molecule
gt mol step done <step>      # Complete step
```

## Merge Queue (gt)

```bash
gt mq list [rig]             # Show merge queue
gt mq next [rig]             # Highest-priority MR
gt mq submit                 # Submit current branch
gt mq status <id>            # MR status
gt mq retry <id>             # Retry failed MR
gt mq reject <id>            # Reject MR
```

## Emergency (gt)

```bash
gt stop --all                # Kill all sessions
gt stop --rig <name>         # Kill rig sessions
```

## Beads Management (bd)

```bash
bd ready                     # Unblocked work
bd list --status=open        # Open issues
bd list --status=in_progress # In-progress issues
bd show <id>                 # Issue details
bd create --title="..."      # Create issue
bd create --title="..." --type=task
bd update <id> --status=in_progress
bd close <id>                # Close issue
bd close <id> --continue     # Close and auto-advance
bd sync                      # Push/pull to git
```

## Dependencies (bd)

```bash
bd dep add <child> <parent>  # child depends on parent
bd dep remove <child> <parent>
bd dep list <id>             # Show dependencies
```

## Formulas (bd)

```bash
bd formula list              # Available formulas
bd formula show <name>       # Formula details
bd cook <formula>            # Formula → Proto
```

## Molecules (bd)

```bash
bd mol list                  # Available protos
bd mol show <id>             # Proto details
bd mol pour <proto>          # Create molecule
bd mol wisp <proto>          # Create wisp
bd mol bond <proto> <parent> # Attach to existing mol
bd mol squash <id>           # Condense to digest
bd mol burn <id>             # Discard wisp
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GT_ROLE` | Agent role (mayor, witness, polecat, crew) |
| `GT_ROOT` | Town root directory |
| `GT_RIG` | Current rig name |
| `GT_POLECAT` | Polecat worker name |
| `GT_CREW` | Crew worker name |
| `BD_ACTOR` | Agent identity for attribution |
| `BEADS_DIR` | Beads database location |

## Configuration (gt)

```bash
gt config agent list         # List all agents
gt config agent get <name>   # Show agent config
gt config agent set <name> <cmd>  # Create/update agent
gt config agent remove <name>  # Remove agent
gt config default-agent [name]  # Get/set default
```

## Health Check (gt)

```bash
gt deacon health-check <agent>  # Send health ping
gt deacon health-state       # Show health state for all
```
