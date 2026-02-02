---
name: beadsmith
description: |
  This skill should be used when the user asks to "break down this epic", "decompose this feature",
  "create implementation tasks", "what tasks do we need", or mentions work breakdown, task creation,
  or implementation planning. Auto-activates when viewing an epic/feature that needs decomposition.

  Examples of when this skill activates:
  - "Let's break down this epic into tasks"
  - "Create implementation tasks for gt-xyz"
  - "This feature needs to be decomposed"
  - "What tasks do we need for this?"
  - "Break this down into implementable work"
---

# Beadsmith - Work Decomposition Skill

Decompose specifications (epics, features, bugs) into implementable task beads with proper dependencies and acceptance criteria.

## When to Use Beadsmith

Invoke beadsmith when facing:
- An **epic** that needs breakdown into features or tasks
- A **feature** that needs implementation tasks
- A **bug** that requires multiple steps to fix
- Any spec bead too large for a single work session

## When NOT to Use Beadsmith

Skip beadsmith for:
- Simple, single-session tasks (execute directly)
- Research or exploration (create individual research tasks with `bd create`)
- Work already well-defined with clear steps

## How It Works

Beadsmith runs as a **subagent with isolated context** to avoid bloating the main conversation. Decomposition produces significant output (reading specs, creating beads, setting dependencies) - isolation keeps the primary context clean.

### Invocation

To decompose a bead, invoke the beadsmith agent:

```
Use the beadsmith agent to decompose <bead-id>
```

Or use the Task tool directly:
```
Task tool (kyle-custom:beadsmith):
  Decompose <bead-id> into implementable tasks
```

### Process

1. **Read the source bead** - understand the desired outcome
2. **Analyze and decompose** - break work into 5-20 minute tasks
3. **Create child beads** - with proper acceptance criteria
4. **Set dependencies** - only for real technical blockers
5. **Create gate beads** - for unclear requirements needing clarification
6. **Self-review** - verify quality before returning
7. **Report results** - summary of created tasks

## Core Principles

### Task Sizing
- **5-20 minutes of focused work** per task
- Small enough for coherent context
- Large enough to provide meaningful value

### Acceptance Criteria
Define **WHAT success looks like**, not HOW to build it:

**Good**: "User can log in with email and password"
**Bad**: "Use JWT tokens and call /auth endpoint"

### Dependencies
Block only for **real technical dependencies**:
- Database schema before queries
- API before client
- Library before code that uses it

Preserve parallelism - if tasks CAN run concurrently, let them.

### Gate Beads
For unclear requirements, create a gate bead blocking dependent work:
```
GATE: Clarify session vs stateless JWT
```

## Example Output

Given an epic "Add user authentication":

```
gt-auth (epic - input)
  ├─ gt-auth.1: Set up authentication library
  │     ↓ blocks gt-auth.2, gt-auth.3
  ├─ gt-auth.2: Create auth middleware
  │     ↓ blocks gt-auth.4
  ├─ gt-auth.3: Add login/logout endpoints
  │     ↓ blocks gt-auth.4
  ├─ gt-auth.4: Add protected route decorator
  │     ↓ blocks gt-auth.5
  ├─ gt-auth.5: Write authentication tests
  └─ gt-auth.gate: GATE: Clarify session vs stateless JWT
        Blocks: gt-auth.2, gt-auth.3
```

## Additional Resources

### Reference Files

For detailed patterns and common mistakes, consult:
- **`references/patterns.md`** - Dependency patterns, task templates, beads commands

### Agent

The actual decomposition work runs in the beadsmith agent:
- **`agents/beadsmith.md`** - Full agent with isolated context for decomposition
