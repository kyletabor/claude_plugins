# Dev Process

The single orchestrator for all multi-file implementation work.

## What It Does

Dev Process is a spec-driven, gate-reviewed development pipeline that enforces rigorous implementation practices. It is the default workflow for any task involving architecture, multiple files, or non-trivial features. The pipeline runs from architecture spec through independent verification, with hard gates at each phase to prevent the most common failure modes: specs written from memory, self-reported verification, and skipped reviews.

## Components

- **Skills:** `dev-process` -- six-phase pipeline (Spec, Review, Implement, Code Review, Test, Verdict)
- **Agents:** `independent-verifier` -- read-only verification agent that checks features from the user's perspective using Playwright; structurally cannot edit code
- **References:** `architecture-template.md` (spec template), `task-template.md` (task description format)

## Sub-Skill Orchestration

Dev Process calls these sub-skills automatically -- do not invoke them independently for implementation work:

- `brainstorming` -- design exploration (Phase 1)
- `test-driven-development` -- TDD per requirement (Phase 3)
- `subagent-driven-development` -- parallel execution (Phase 3)
- `verification-before-completion` -- verification enforcement (Phase 5)

## Usage

Triggers automatically on any implementation request:

- "Go implement this"
- "Build this feature"
- "Execute this plan"
- Any request to implement a PRD, epic, or multi-step plan

### The Six Phases

1. **Spec** -- verify current state, explore codebase with parallel agents, write architecture spec with executable acceptance criteria
2. **Spec Review** -- automated review gate (approve/reject)
3. **Implement** -- TDD per requirement, parallel agent execution, one commit per requirement
4. **Code Review** -- automated review against spec compliance, security, and coverage
5. **Test + Verify** -- run tests, then independent verifier (not the builder) confirms the feature works
6. **Verdict** -- pre-ship checklist, beads gate, ship or iterate

## Installation

From the kyle-plugins marketplace -- already included if you have kyle-plugins installed.
