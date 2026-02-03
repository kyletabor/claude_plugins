---
name: architect
description: |
  This skill should be used when the user asks to "architect this epic", "design the implementation",
  "break down this feature", "create an architecture spec", "explore and plan gt-xyz", or mentions
  needing multi-pass codebase exploration before task decomposition. Takes an epic/PRD bead, explores
  the codebase with parallel subagents, designs the technical approach, and creates implementation
  task beads with step-by-step instructions.
---

# Architect Skill

Expert software architecture workflow for decomposing epics into executable task beads.

## When to Use

- Epic or PRD needs implementation planning
- Feature requires codebase exploration before breakdown
- Need architecture spec with reference patterns
- Creating task beads with bite-sized execution steps

## Workflow Overview

```
Phase 1: Understand PRD → Phase 2: Explore (3 parallel) → Phase 3: Design → Phase 4: Create Beads
```

## Phase 1: Understand the PRD

Read and extract requirements from the bead:

```bash
bd show <bead-id>
```

Extract:
- Goal and acceptance criteria
- Scope boundaries (in/out)
- Constraints and requirements

## Phase 2: Explore Codebase (Parallel Subagents)

Launch 3 Explore subagents in parallel using the Task tool:

```
Task 1 - Pattern Discovery:
"Find existing features similar to [feature type]. Look for patterns, file structures,
and conventions to follow. Output: Reference files to use as templates."

Task 2 - Integration Points:
"Find where [feature] would integrate with existing code. Look for APIs, data models,
entry points. Output: Files to modify, connection points."

Task 3 - Test Patterns:
"Find how tests are structured in this codebase. Look for unit, integration, e2e patterns.
Output: Test file locations, testing conventions."
```

Wait for all 3 to complete, then synthesize findings.

## Phase 3: Design Architecture

Launch a Plan subagent with:
- PRD requirements
- Exploration findings
- Request: Design implementation approach, decompose into legs

The Plan subagent outputs:
- Technical approach (how to solve it)
- Patterns to follow (reference files)
- Implementation legs (each sized for one agent session)

## Phase 4: Create Beads

### 4.1: Create Architecture Bead

```bash
bd create -t task "<epic-id>.arch: Architecture Spec" --parent <epic-id> -d "<spec>"
```

Architecture spec format - see `references/architecture-template.md`

### 4.2: Create Task Beads

For each implementation leg:

```bash
bd create -t task "<verb> <what>" --parent <epic-id> -d "<task-description>"
```

Task description format - see `references/task-template.md`

### 4.3: Set Up Dependencies

```bash
bd dep add <earlier-task-id> <later-task-id>
```

Only block for real technical dependencies:
- Schema before queries
- Library before usage
- API before client

## Phase 5: Report Results

Output summary:

```markdown
## Architecture Complete

**Epic**: <bead-id>
**Architecture Bead**: <arch-bead-id>

### Tasks Created
| ID | Title | Blocked By |
|----|-------|------------|
| <id> | <title> | <deps or "Ready"> |

### Ready to Start
Run `bd ready` to see unblocked tasks.
```

## Quality Standards

- **Complete code in steps**: Show actual code, not "add validation"
- **Exact file paths**: Full paths, not "in the utils folder"
- **Verifiable criteria**: Can be checked without reading code
- **Right-sized tasks**: 5-20 minutes focused work
- **Minimal dependencies**: Only block when technically required

## Edge Cases

| Situation | Action |
|-----------|--------|
| Unclear requirements | Create gate bead: `bd create -t task -l gate "GATE: Clarify X" --parent <epic>` |
| Large epic | Break into sub-epics first, architect each separately |
| Partial implementation | Note what exists, only create tasks for remaining work |
| Missing patterns | Propose new pattern in architecture spec |

## Additional Resources

### Reference Files

- **`references/architecture-template.md`** - Architecture spec format
- **`references/task-template.md`** - Task bead description format
