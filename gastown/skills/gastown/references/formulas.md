# Formulas in Gas Town

Formulas are reusable workflow templates (`.formula.toml` files) that define work structure. When you pour a formula, it creates bead issues that can be assigned to agents.

## Formula Types

| Type | Execution | Structure | Use Case |
|------|-----------|-----------|----------|
| **workflow** | Sequential | `[[steps]]` with `needs` dependencies | Linear process: design → implement → test → ship |
| **convoy** | Parallel + synthesis | `[[legs]]` + `[synthesis]` | Multi-perspective analysis: code review, design exploration |
| **expansion** | Iterative refinement | `[[template]]` repeated per target | Rule of five: draft → refine correctness → refine clarity → refine edges → polish |
| **aspect** | Cross-cutting injection | `[[advice]]` around target steps | Security scans before/after implementation steps |

## Convoy Formulas (Parallel Execution)

**CRITICAL - Invocation:**
```bash
# CORRECT - use gt formula run with --pr or --files:
gt formula run code-review --pr=123
gt formula run code-review --files="src/*.go"

# WRONG - gt sling fails for convoy formulas:
gt sling code-review --on <bead>  # ERROR: "convoy type not supported"
```

**Why?** `gt sling` attempts to cook+pour the formula, which fails for convoy type.
`gt formula run` handles convoy dispatch directly, spawning parallel polecats.

**Structure:**
```toml
type = "convoy"

[[legs]]
id = "explore-similar"
title = "Find similar features"

[[legs]]
id = "explore-arch"
title = "Understand architecture"

[synthesis]
title = "Combine findings"
depends_on = ["explore-similar", "explore-arch"]
```

**Execution:**
1. `gt formula run <convoy-formula> --pr=N` creates leg beads and spawns polecats
2. Each leg assigned to different polecat (parallel work)
3. Synthesis waits for all legs to complete
4. Synthesis combines all leg outputs

**Use cases:**
- Code review (parallel: security, performance, correctness reviewers)
- Design exploration (parallel: API, data, UX, scale, security analysts)
- Multi-option architecture (parallel: minimal, clean, pragmatic approaches)

## Workflow Formulas (Sequential Execution)

**Structure:**
```toml
type = "workflow"

[[steps]]
id = "design"

[[steps]]
id = "implement"
needs = ["design"]

[[steps]]
id = "test"
needs = ["implement"]
```

**Execution:**
1. Steps execute in dependency order
2. `needs` blocks execution until dependencies complete
3. Single agent typically works through steps sequentially
4. `bd close <step> --continue` auto-advances to next ready step

**Use cases:**
- Feature development pipeline
- Release process
- Polecat work execution (mol-polecat-work)

## Expansion Formulas (Iterative Refinement)

**Structure:**
```toml
type = "expansion"

[[template]]
id = "{target}.draft"

[[template]]
id = "{target}.refine-1"
needs = ["{target}.draft"]

[[template]]
id = "{target}.refine-2"
needs = ["{target}.refine-1"]
```

**Execution:**
1. Takes a target (e.g., design bead)
2. Creates refinement steps for that target
3. Each refinement depends on previous
4. Same agent iterates through improvements

**Use cases:**
- Rule of five (draft → correctness → clarity → edges → polish)
- Iterative design refinement
- Progressive enhancement

## Aspect Formulas (Cross-Cutting Concerns)

**Structure:**
```toml
type = "aspect"

[[advice]]
target = "implement"

[[advice.around.before]]
id = "{step.id}-security-prescan"

[[advice.around.after]]
id = "{step.id}-security-postscan"
```

**Execution:**
1. Injects steps before/after matching steps
2. Uses glob patterns to match target steps
3. Adds consistent gates across workflows

**Use cases:**
- Security scans before/after implementation
- Validation gates
- Logging/audit trails

## Formula Lifecycle in Gas Town

```
1. Write formula        → .beads/formulas/my-formula.formula.toml
2. Cook formula        → bd cook my-formula (validates)
3. Pour formula        → bd mol pour my-formula (creates beads)
4. Assign work         → gt sling <bead> <rig> (spawns polecats)
5. Execute             → Polecats work through beads
6. Track progress      → gt convoy create (optional, for visibility)
```

## Common Patterns

### Chained Convoys (Exploration → Architecture → Review)

```bash
# Step 1: Exploration convoy
bd mol pour exploration-convoy --var prd=/path/to/PRD.md
gt sling explore-1 gastown
gt sling explore-2 gastown
# Wait for synthesis to complete

# Step 2: Architecture convoy (uses exploration output)
bd mol pour architecture-convoy --var exploration_id=<synthesis-bead>
gt sling arch-minimal gastown
gt sling arch-clean gastown
gt sling arch-pragmatic gastown
# Wait for synthesis (creates implementation beads)

# Step 3: Review
bd mol pour review-convoy --var beads=<list-from-arch-synthesis>
gt sling review-1 gastown
```

### Orchestrator Workflow

```toml
type = "workflow"

[[steps]]
id = "exploration-phase"
description = """
Run exploration convoy:
  bd mol pour exploration-convoy
  gt sling each leg
  Wait for synthesis
"""

[[steps]]
id = "architecture-phase"
needs = ["exploration-phase"]
description = """
Run architecture convoy:
  bd mol pour architecture-convoy
  gt sling each leg
  Wait for synthesis (creates beads)
"""
```

One orchestrator agent works through workflow steps, each step pours and manages a convoy.

## See Also

- [convoys.md](convoys.md) - Work convoy tracking (gt convoy)
- [molecules.md](molecules.md) - Molecule lifecycle
- Beads skill MOLECULES.md - Proto/wisp patterns
