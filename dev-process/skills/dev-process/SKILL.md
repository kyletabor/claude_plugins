---
name: dev-process
description: |
  This skill should be used ANY TIME the user asks to implement, build, or execute a plan that involves
  multi-file changes or non-trivial features. This is the DEFAULT workflow for all implementation work
  beyond single-file fixes. You do NOT need to be explicitly told to use it — if the task involves
  architecture, multiple files, agent teams, or a plan to execute, USE THIS SKILL.

  Examples of when this skill activates:
  - "Go implement this"
  - "Build this feature"
  - "Execute this plan"
  - "Implement the architecture"
  - "Go build it"
  - "Use the dev process"
  - "Follow the standard pipeline"
  - Any request to implement a PRD, epic, or multi-step plan
---

# Structured Development Process

Spec-driven, gate-reviewed development pipeline for rigorous implementation.

## When to Use

- Multi-file features or fixes
- Work that needs architecture before coding
- Changes requiring security or compliance review
- Any work where "just code it" leads to rework

## When NOT to Use

- Single-file bug fixes
- Quick config changes
- Pure research/exploration tasks

## The Pipeline

```
Phase 1: Spec → Phase 2: Spec Review → Phase 3: Implement → Phase 4: Code Review → Phase 5: Test → Phase 6: Verdict
```

## Phase 1: Architecture Spec

Write a detailed spec BEFORE any code. This phase uses parallel codebase exploration to inform the design.

### Step 1: Understand the Requirements

Read and extract requirements from the source (PRD, epic, issue, or user request):
- Goal and acceptance criteria
- Scope boundaries (in/out)
- Constraints and requirements

### Step 2: Explore Codebase (Parallel Subagents)

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

### Step 3: Design Architecture

Launch a Plan subagent with the requirements and exploration findings. The subagent outputs:
- Technical approach (how to solve it)
- Patterns to follow (reference files)
- Implementation legs (each sized for one agent session)

### Step 4: Write the Spec

The spec MUST include:

```markdown
# [Feature/Fix Name] — Architecture Spec

## Goal
[1-2 sentences: what we're building and why]

## Scope
- **In scope**: [list]
- **Out of scope**: [list]

## Reference Patterns
| Purpose | File | Notes |
|---------|------|-------|
| Similar feature | src/path/to/file | Follow this structure |
| Test pattern | tests/path/to/test | Use this testing approach |

## Files to Modify/Create
| File | Action | Purpose |
|------|--------|---------|
| path/to/file | Create/Modify | What changes |

## Technical Design

### [Component 1]
- **Goal**: [what this component does]
- **Logic**: [how it works, pseudocode or description]
- **Types**: [new types/interfaces needed]
- **Edge cases**: [what could go wrong]

### [Component 2]
[repeat pattern]

## Implementation Legs

### Leg 1: [Name]
[Brief description of what this leg accomplishes]

### Leg 2: [Name]
[Brief description]

## Dependencies & Parallelization

```
Leg 1 ──┬──> Leg 3
        │
Leg 2 ──┘
```

[Explain what can run in parallel and what's sequential]

## Test Requirements

For each component:
- Unit tests: [count and description]
- Integration tests: [if applicable]
- E2E verification: [manual or automated checks]

## Security Considerations
[If applicable: bypass vectors, injection risks, access control]
```

Save the spec as a doc in the project's docs/ folder or as a task in your tracking system.

See `references/architecture-template.md` for a lighter-weight template.

## Phase 2: Spec Review Gate

**STOP.** Do not proceed to implementation without review.

Launch a Plan subagent to review the spec:

```
"Review this architecture spec for completeness. Check:
1. Are all files identified? Any missing?
2. Are edge cases covered?
3. Is the test plan adequate?
4. Are dependencies correctly mapped?
5. Any security concerns missed?
Output: APPROVE with notes, or REJECT with specific issues."
```

If REJECTED: fix the spec and re-review.
If APPROVED: proceed to Phase 3.

## Phase 3: Implementation

Use agent teams for parallel work. Follow the dependency diagram from the spec.

### Team Setup

1. Create a team (if not already in one)
2. Create tasks for each implementation leg
3. Set up dependencies between tasks
4. Spawn implementation agents for each independent leg

### Implementation Agent Instructions Template

```
Implement [Leg Name] per the architecture spec.

Spec location: [path]
Your scope: [specific section of the spec]

Rules:
- Follow the spec exactly — don't improvise
- Write tests alongside code (TDD preferred)
- Commit when your leg is complete
- Report: what you built, test results, any deviations from spec
```

### Parallelization Rules

- Independent legs run simultaneously
- Dependent legs wait for blockers to complete
- Each agent gets isolated scope — no overlapping file edits
- If two legs touch the same file, they must be sequential

## Phase 4: Code Review Gate

**STOP.** All implementation must be reviewed before merging.

Launch a code review agent:

```
"Review the implementation against the architecture spec.

Spec: [path]
Changes: [git diff or file list]

Check per file:
1. Spec compliance — does it match the design?
2. Code quality — clean, readable, no dead code
3. Test coverage — are all spec'd tests present and passing?
4. Security — any bypass vectors or injection risks?

Output format:
### [filename]
| Requirement | Status |
|-------------|--------|
| [from spec] | PASS / FAIL |

### Security Review
[explicit checks]

### Verdict
APPROVE / REJECT
Severity: [CRITICAL: X, HIGH: X, MEDIUM: X, LOW: X]"
```

If REJECTED: fix issues and re-review.
If APPROVED: proceed to Phase 5.

## Phase 5: Testing

Run all tests and verify E2E:

1. **Unit tests**: Run the full test suite
2. **Integration tests**: If applicable
3. **E2E verification**: Actually run the thing and verify it works
4. **Regression check**: Ensure existing functionality isn't broken

Report test results with counts: X/Y passing, any failures.

## Phase 6: Verdict & Ship

If all gates passed:
1. Final commit with clean message
2. Close/update completed tasks in your tracking system
3. Save learnings to claude-mem for future reference
4. Report summary to user

If any gate failed:
1. Document what failed and why
2. Create fix tasks
3. Loop back to the appropriate phase

## Quick Reference

| Phase | Gate | Who | Output |
|-------|------|-----|--------|
| 1. Spec | — | Lead + Explore agents | Architecture doc |
| 2. Review | Spec complete? | Plan agent | APPROVE/REJECT |
| 3. Implement | — | Implementation agents | Code + tests |
| 4. Review | Spec compliant? | Review agent | APPROVE/REJECT |
| 5. Test | Tests pass? | Test runner | Results |
| 6. Ship | All gates? | Lead | Done or iterate |

## Tips

- **Don't skip gates** even when it feels like overkill — the 10 minutes saved by skipping review costs hours of rework
- **Spec changes during implementation** are OK but must be documented and re-reviewed
- **Small scope** is better — break large features into multiple dev-process cycles
- **Claude CLI for LLM calls**: Use `CLAUDECODE= claude --print` not Anthropic SDK

## Additional Resources

### Reference Files
- **`references/architecture-template.md`** — Lighter-weight architecture spec template
- **`references/task-template.md`** — Task description format with step-by-step instructions
