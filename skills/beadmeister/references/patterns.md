# Beadmeister Reference

## Dependency Patterns

### Sequential Pipeline
```
setup → implement → test → document
```
Each step must complete before the next.

**When to use**: Linear workflows where each step builds on the previous.

### Parallel Then Merge
```
research-a ─┐
research-b ─┼─→ decision
research-c ─┘
```
Multiple tasks feed into one synthesis step.

**When to use**: Research phases, gathering information from multiple sources.

### Foundation First
```
         ┌─→ feature-a
setup ───┼─→ feature-b
         └─→ feature-c
```
One foundational task unblocks multiple parallel features.

**When to use**: Infrastructure setup, shared dependencies.

### Diamond Pattern
```
        ┌─→ path-a ─┐
start ──┤           ├─→ finish
        └─→ path-b ─┘
```
Parallel paths that converge.

**When to use**: Independent implementations that need integration.

## Step Patterns

### TDD Steps (Coding Tasks)
```markdown
### 1. Write failing test (~3 min)
Create `tests/path/file.test.ts`:
\`\`\`typescript
// Complete test code
\`\`\`

### 2. Verify test fails (~1 min)
\`\`\`bash
npm test -- file.test.ts
\`\`\`
Expected: Test fails

### 3. Implement (~5 min)
Create `src/path/file.ts`:
\`\`\`typescript
// Complete implementation
\`\`\`

### 4. Verify test passes (~1 min)
\`\`\`bash
npm test -- file.test.ts
\`\`\`
Expected: All tests pass
```

### Fix/Modify Steps
```markdown
### 1. Locate the issue (~2 min)
Open `src/path/file.ts:42`

### 2. Make the change (~3 min)
Replace with:
\`\`\`typescript
<new code>
\`\`\`

### 3. Verify (~2 min)
\`\`\`bash
npm test
\`\`\`
Expected: No regressions
```

### Research Steps
```markdown
### 1. Explore (~5 min)
\`\`\`bash
<commands>
\`\`\`
Looking for: <what>

### 2. Document findings (~3 min)
Create `docs/findings/<topic>.md`

### 3. Report
Add to bead comments
```

## Common Mistakes

### Over-decomposition
**Problem**: Tasks so small that coordination overhead exceeds benefit.
**Signs**: Tasks under 5 minutes, excessive dependency chains.
**Fix**: Combine related micro-tasks into coherent units.

### Under-decomposition
**Problem**: Tasks so large they exhaust context mid-implementation.
**Signs**: Tasks over 30 minutes, vague scope, "and then also..." in description.
**Fix**: Find natural seams to split the work.

### Over-blocking
**Problem**: Everything sequential when parallel work is possible.
**Signs**: Linear chain when tasks don't technically depend on each other.
**Fix**: Ask "Can this start before the blocker finishes?" If yes, remove the block.

### Vague Criteria
**Problem**: "Make it work" instead of specific verifiable outcomes.
**Signs**: Can't tell when task is done, acceptance criteria are opinions.
**Fix**: Define observable, testable success conditions.

### Implementation in Criteria
**Problem**: Locking in HOW instead of defining WHAT.
**Signs**: Technology choices, specific APIs, implementation details in criteria.
**Fix**: Describe the outcome, not the approach.

## Task Description Template

```markdown
<One sentence goal>

## What Success Looks Like
- [ ] <Verifiable outcome 1>
- [ ] <Verifiable outcome 2>
- [ ] <Verifiable outcome 3>

## Execution Steps

### 1. <Step name> (~3 min)
<Exact instructions with complete code>

### 2. <Step name> (~2 min)
<More exact instructions>

### 3. Verify (~1 min)
\`\`\`bash
<command to verify>
\`\`\`
Expected: <what success looks like>

### 4. Commit
\`\`\`bash
git add <files>
git commit -m "<message>"
\`\`\`

## Context
- Reference: `<path/to/similar/file.ts>` - follow this pattern
- Depends on: <what must exist first>
- Watch out for: <common pitfalls>
```

## Beads Commands Reference

### Creating Tasks
```bash
bd create -t task "Title" --parent <epic-id> -d "Description"
```

### Setting Dependencies
```bash
bd dep add <blocker-id> <blocked-id>
```

### Creating Gate Beads
```bash
bd create -t task -l gate "GATE: <clarification needed>" --parent <epic-id>
bd dep add <gate-id> <blocked-task-id>
```

### Checking Ready Work
```bash
bd ready
```

### Viewing Structure
```bash
bd show <epic-id>
```
