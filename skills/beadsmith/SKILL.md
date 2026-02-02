---
name: beadsmith
description: |
  Use when decomposing epics, features, or bugs into implementable tasks. Auto-activates when
  discussing work breakdown, task creation, or when someone says "break this down" or "create
  tasks for this". Also activates when viewing an epic/feature that needs implementation planning.

  Examples of when this skill activates:
  - "Let's break down this epic into tasks"
  - "Create implementation tasks for gt-xyz"
  - "This feature needs to be decomposed"
  - "What tasks do we need for this?"
---

# Beadsmith - Work Decomposition Skill

This skill helps you decompose specifications (epics, features, bugs) into implementable task beads.

## When to Use Beadsmith

Use beadsmith when you have:
- An **epic** that needs to be broken into features or tasks
- A **feature** that needs implementation tasks
- A **bug** that requires multiple steps to fix
- Any spec bead that's too large for a single work session

## When NOT to Use Beadsmith

Don't use beadsmith for:
- Simple, single-session tasks (just do them directly)
- Research or exploration (use `bd create` for individual research tasks)
- Work that's already well-defined with clear steps

## How It Works

Beadsmith runs as a **subagent with isolated context** to avoid bloating your main conversation. This is important because decomposition produces a lot of output (reading specs, creating multiple beads, setting dependencies).

### Quick Start

To decompose a bead, invoke the beadsmith agent:

```
Use the beadsmith agent to decompose <bead-id>
```

Or use the Task tool directly:
```
Task tool (kyle-custom:beadsmith):
  Decompose <bead-id> into implementable tasks
```

### What Beadsmith Does

1. **Reads the source bead** - understands the desired outcome
2. **Analyzes and decomposes** - breaks work into 5-20 minute tasks
3. **Creates child beads** - with proper acceptance criteria
4. **Sets dependencies** - only for real technical blockers
5. **Creates gate beads** - for unclear requirements needing clarification
6. **Self-reviews** - verifies quality before returning
7. **Reports results** - summary of what was created

## Good Decomposition Principles

### Task Sizing
- **5-20 minutes of focused work** per task
- Small enough for coherent context
- Large enough to provide value

### Acceptance Criteria
Define **WHAT success looks like**, not HOW to build it:

**Good**: "User can log in with email and password"
**Bad**: "Use JWT tokens and call /auth endpoint"

### Dependencies
Only block for **real technical dependencies**:
- Database schema before queries
- API before client
- Library before code that uses it

**Don't block for preferences** - if tasks CAN run in parallel, let them.

### Gate Beads
When requirements are unclear, create a gate bead that blocks dependent work:
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

## Invoking the Agent

When you're ready to decompose, use the beadsmith agent:

```
Use the kyle-custom:beadsmith agent to decompose <bead-id>
```

The agent runs in isolated context and returns a summary of created tasks.
