# Architecture Spec Template

Use this format when creating the architecture bead:

```markdown
## Overview

[1-2 sentence summary of the approach]

## Technical Approach

- **Pattern**: [existing pattern we're following]
- **Key files**: [list of files to create/modify]
- **Integration points**: [where this connects to existing code]

## Reference Patterns

| Purpose | File | Notes |
|---------|------|-------|
| Similar feature | src/path/to/file.ts | Follow this structure |
| Test pattern | tests/path/to/test.ts | Use this testing approach |

## Implementation Legs

### Leg 1: [Name]
[Brief description of what this leg accomplishes]

### Leg 2: [Name]
[Brief description of what this leg accomplishes]

### Leg 3: [Name]
[Brief description of what this leg accomplishes]

## Dependencies

```
Leg 1 ──┬──> Leg 3
        │
Leg 2 ──┘
```

## Notes

[Any important context, gotchas, or decisions made during architecture]
```

## Example

```markdown
## Overview

Add visual bead exploration canvas using existing terminal canvas patterns.

## Technical Approach

- **Pattern**: Follow canvas:calendar implementation
- **Key files**:
  - Create: skills/beads-canvas/SKILL.md
  - Create: skills/beads-canvas/scripts/render.py
  - Modify: canvas skill to add beads type
- **Integration points**:
  - Canvas spawn mechanism
  - bd CLI for data fetching

## Reference Patterns

| Purpose | File | Notes |
|---------|------|-------|
| Canvas skill | skills/canvas/SKILL.md | Follow structure |
| Render script | skills/canvas/scripts/calendar.py | Adapt for beads |
| Data fetching | bd list --json | Use for bead data |

## Implementation Legs

### Leg 1: Basic bead list canvas
Spawn canvas showing flat list of beads with status icons

### Leg 2: Dependency graph view
Add graph visualization of bead dependencies

### Leg 3: Filter and navigation
Add filtering by status/priority and keyboard navigation

## Dependencies

```
Leg 1 ──> Leg 2 ──> Leg 3
```

## Notes

- Start with simplest possible canvas (list view)
- Use bd list --json for data - don't access DB directly
- Terminal canvas limitations: no mouse, limited colors
```
