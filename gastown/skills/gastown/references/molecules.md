# Molecules - Workflow Templates in Gas Town

## Work Unit Hierarchy

| Type | Persistence | Purpose |
|------|-------------|---------|
| **Bead** | Git-backed JSONL | Atomic work unit (issue, task, epic) |
| **Formula** | TOML source | Reusable workflow template definition |
| **Protomolecule** | Frozen template | Compiled formula ready for instantiation |
| **Molecule** | Persistent | Multi-step workflow instance |
| **Wisp** | Ephemeral | Lightweight transient work (destroyed after run) |
| **Hook** | Pinned | Agent's primary work queue |

## Molecule Lifecycle

```
Formula (TOML source) ─── "Ice-9"
    │
    ▼ bd cook
Protomolecule (frozen template) ─── Solid
    │
    ├─▶ bd mol pour ──▶ Molecule (persistent) ──▶ bd squash ──▶ Digest
    │
    └─▶ bd mol wisp ──▶ Wisp (ephemeral) ──┬▶ bd squash ──▶ Digest
                                           └▶ bd burn ──▶ (gone)
```

## Formula Commands

```bash
bd formula list              # Available formulas
bd formula show <name>       # Formula details
bd cook <formula>            # Formula → Protomolecule
```

## Molecule Commands

### Beads Operations (bd) - Data

```bash
bd mol list                  # Available protos
bd mol show <id>             # Proto details
bd mol pour <proto>          # Create persistent molecule
bd mol wisp <proto>          # Create ephemeral wisp
bd mol bond <proto> <parent> # Attach to existing mol
bd mol squash <id>           # Condense to digest
bd mol burn <id>             # Discard wisp
```

### Agent Operations (gt) - Execution

```bash
gt hook                      # What's on MY hook
gt mol current               # What should I work on next
gt mol progress <id>         # Execution progress
gt mol attach <bead> <mol>   # Pin molecule to bead
gt mol detach <bead>         # Unpin molecule
gt mol burn                  # Burn attached molecule
gt mol squash                # Squash attached molecule
gt mol step done <step>      # Complete a molecule step
```

**Key distinction**: `bd mol` takes explicit IDs. `gt mol` operates on the current agent's attached molecule.

## Formula Format

```toml
formula = "name"
type = "workflow"           # workflow | expansion | aspect
version = 1
description = "..."

[vars.feature]
description = "..."
required = true

[[steps]]
id = "step-id"
title = "{{feature}}"
description = "..."
needs = ["other-step"]      # Dependencies
```

### Composition

```toml
extends = ["base-formula"]

[compose]
aspects = ["cross-cutting"]

[[compose.expand]]
target = "step-id"
with = "macro-formula"
```

## Formula Search Paths

Priority order:
1. `.beads/formulas/` - Project-level (current worktree)
2. `~/.beads/formulas/` - User-level (private custom)
3. `$GT_ROOT/.beads/formulas/` - Town-level (shared across rigs)

## Common Formulas

### Sequential Workflows
- `shiny` - Complete engineer-in-a-box: design → implement → review → test → submit
- `shiny-enterprise` - Shiny with expanded implementation phase
- `mol-polecat-work` - Full polecat lifecycle

### Parallel/Convoy Formulas
- `code-review` - 10 parallel legs (correctness, performance, security, etc.)
- `design` - 6 parallel legs (api, data, ux, scale, security, integration)

### Patrol Formulas
- `mol-witness-patrol` - Witness daemon loop
- `mol-deacon-patrol` - Deacon daemon loop
- `mol-refinery-patrol` - Refinery daemon loop

## Patrol Agents and Wisps

Deacon, Witness, and Refinery run continuous patrol loops using wisps:

```
1. bd mol wisp mol-<role>-patrol
2. Execute steps (check workers, process queue, run plugins)
3. bd mol squash (or burn if routine)
4. Loop
```

Wisps are ideal for patrol because:
- Ephemeral - don't clutter the ledger
- Can be burned without trace if routine
- Squashed to digest only if noteworthy
