---
name: beadmeister
description: |
  This skill should be used when creating execution-ready task beads from Architect output.
  Use when an architecture spec exists and you need to generate polecat work.

  Examples of when this skill activates:
  - "The architecture is done, create the implementation beads"
  - "Convert these legs into task beads"
  - "Create polecat work from the architecture"
  - "gt-xyz.arch is ready, make the tasks"
  - "Turn the legs into executable work"
---

# Beadmeister - Molecular Work Creator

Create execution-ready task beads from Architect output. Beadmeister takes implementation legs and generates beads with step-by-step instructions that polecats can execute directly.

## The Workflow

```
Epic → Architect → Architecture Bead → Beadmeister → Task Beads → Polecats
```

**Architect** decomposes and designs (exploration, planning, leg definition).
**Beadmeister** creates work (converts legs to execution-ready beads).

## When to Use Beadmeister

Use beadmeister when:
- An **architecture bead exists** with implementation legs
- You need to **generate polecat work** from an architecture spec
- Legs need **step-by-step execution instructions**

## When NOT to Use Beadmeister

Skip beadmeister when:
- No architecture exists yet → Use **Architect** first
- Work doesn't need decomposition → Execute directly
- Just exploring/researching → Create research bead with `bd create`

## How It Works

Beadmeister runs as a **subagent with isolated context** to keep the main conversation clean.

### Invocation

```
Use the beadmeister agent to create tasks from gt-xyz.arch
```

Or use the Task tool:
```
Task tool (kyle-custom:beadmeister):
  Create execution-ready beads from the architecture at gt-xyz.arch
```

### Process

1. **Read the architecture bead** - understand the legs and their dependencies
2. **For each leg, create a task bead** - with complete execution steps
3. **Set up dependencies** - only for real technical blockers
4. **Report results** - summary of created tasks and what's ready

## Core Principle

> "Hey polecat, this is what you're gonna do: first this, then this, then this."

Every bead should be immediately executable by a fresh agent with no context.

## Task Bead Format

Each task bead includes:

```markdown
<One sentence goal>

## What Success Looks Like
- [ ] <Verifiable outcome 1>
- [ ] <Verifiable outcome 2>

## Execution Steps

### 1. <Step name> (~3 min)
<Exact instructions with complete code>

### 2. <Step name> (~2 min)
<More exact instructions>

### 3. Verify (~1 min)
```bash
<command to verify>
```

### 4. Commit
```bash
git commit -m "<message>"
```

## Context
- Reference: `path/to/pattern.ts`
```

## Quality Standards

- **Complete code** - No "add validation here", show the actual code
- **Time-bounded steps** - 2-5 minutes each
- **Verifiable outcomes** - Clear success/failure criteria
- **Minimal dependencies** - Block only for technical requirements

## Additional Resources

### Reference Files
- **`references/patterns.md`** - Dependency patterns, common mistakes

### Agent
- **`agents/beadmeister.md`** - Full agent for creating execution-ready beads
