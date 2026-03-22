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

### Step 0: Verify Current State (MANDATORY)

<HARD-GATE>
Before writing ANY spec, you MUST verify the current state of the system you're targeting.
Specs written from memory are specs written against fiction. This step has been skipped in
5 out of 5 recent incidents, causing features to target dead code paths every time.
</HARD-GATE>

Run these checks and include the OUTPUT in your spec:

1. **Trace the actual data flow** — open the app, check browser DevTools / network requests,
   or grep the codebase to find which endpoints and code paths are ACTUALLY used
2. **Verify the target files exist and are active** — `grep -r` for imports, route registrations,
   or function calls that prove the code you're targeting is live (not legacy)
3. **Check for recent changes** — `git log --oneline -10 [target files]` to see if the area
   was recently refactored (your mental model may be stale)

Include a `## Current State Verification` section in every spec with actual command output.
If you cannot produce this evidence, you are not ready to write the spec.

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

## Current State Verification
[MANDATORY — actual command output proving this spec targets live code paths]
- Data flow trace: [which endpoints/functions are actually called]
- Target file verification: [grep output showing files are imported/used]
- Recent changes: [git log of target area]

## Acceptance Criteria (Executable)
[MANDATORY — each criterion is a testable assertion, not prose]
For each criterion, write it as: "When [action], then [observable result]"
Example:
- When user loads conversation view, DOM contains `.tool-group` elements (count > 0)
- When user clicks tool group header, expanded content becomes visible
These MUST be convertible to Playwright assertions. Prose-only criteria are rejected at review.

## Test Requirements

For each component:
- Unit tests: [count and description]
- Integration tests: [if applicable]
- E2E tests: [Playwright tests that verify acceptance criteria against REAL data, not mocks]

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

## Phase 5: Testing + Independent Verification

### 5a: Run Tests (Builder)

1. **Unit tests**: Run the full test suite — report BEFORE and AFTER counts
   (e.g., "was 118, now 130" — if count didn't increase, new tests weren't added or aren't running)
2. **Integration tests**: If applicable
3. **Regression check**: Ensure existing functionality isn't broken

### 5b: Independent Verification (NOT the Builder)

<HARD-GATE>
The agent who built it CANNOT verify it. This is non-negotiable.
In 5 out of 5 recent incidents, self-certification led to shipping broken features.
</HARD-GATE>

Spawn a **separate verification agent** (use the `independent-verifier` agent if available,
or launch a fresh Agent with read-only + Playwright access):

```
"Verify this feature works from the USER's perspective.

Spec: [path to spec with acceptance criteria]
App URL: [the URL the user actually uses]

For EACH acceptance criterion in the spec:
1. Load the app the way the user loads it (not a test harness)
2. Perform the user action described
3. Check the observable result matches the criterion
4. Take a screenshot as evidence

Report:
| Acceptance Criterion | Result | Evidence |
|---------------------|--------|----------|
| [criterion] | PASS/FAIL | [screenshot or DOM check] |

You have NO access to edit code. You can only read, browse, and report.
If ANY criterion fails, report FAIL — do not attempt to fix."
```

If the verifier reports FAIL → return to Phase 3 with the failure details.
If the verifier reports PASS → proceed to Phase 6 with the evidence.

## Phase 6: Verdict & Ship

**Pre-ship checklist** (all must be YES):
- [ ] Spec includes Current State Verification with command output?
- [ ] Acceptance criteria are executable (not prose)?
- [ ] Test count increased? (before: ___, after: ___)
- [ ] Independent verifier (not builder) confirmed feature works?
- [ ] Verifier evidence (screenshots/DOM checks) included in report?

If all YES:
1. Final commit with clean message
2. Close/update completed tasks in your tracking system
3. Save learnings to claude-mem for future reference
4. Report summary to user WITH verifier evidence attached

If any NO:
1. Document what failed and why
2. Create fix tasks
3. Loop back to the appropriate phase

## Quick Reference

| Phase | Gate | Who | Output |
|-------|------|-----|--------|
| 1. Spec | Current state verified? | Lead + Explore agents | Architecture doc with evidence |
| 2. Review | Spec complete? Criteria executable? | Plan agent | APPROVE/REJECT |
| 3. Implement | — | Implementation agents | Code + tests |
| 4. Review | Spec compliant? | Review agent | APPROVE/REJECT |
| 5a. Test | Tests pass? Count increased? | Builder | Test results |
| 5b. Verify | Feature works for user? | **Independent verifier** (NOT builder) | Evidence |
| 6. Ship | All gates + verifier evidence? | Lead | Done or iterate |

## Tips

- **Don't skip gates** even when it feels like overkill — the 10 minutes saved by skipping review costs hours of rework
- **Spec changes during implementation** are OK but must be documented and re-reviewed
- **Small scope** is better — break large features into multiple dev-process cycles
- **Claude CLI for LLM calls**: Use `CLAUDECODE= claude --print` not Anthropic SDK

## Additional Resources

### Reference Files
- **`references/architecture-template.md`** — Lighter-weight architecture spec template
- **`references/task-template.md`** — Task description format with step-by-step instructions
