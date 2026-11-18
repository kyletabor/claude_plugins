# Dev Process

The single orchestrator for all multi-file implementation work.

## What It Does

Dev Process is a spec-driven, gate-reviewed development pipeline that enforces rigorous implementation practices. It is the default workflow for any task involving architecture, multiple files, or non-trivial features. The pipeline runs from architecture spec through independent verification, with hard gates at each phase to prevent the most common failure modes: specs written from memory, self-reported verification, and skipped reviews.

## Components

- **Skills:** `dev-process` -- six-phase pipeline (Spec, Review, Implement, Code Review, Test, Verdict)
- **Agents:** `independent-verifier` -- read-only verification agent that checks features from the user's perspective using Playwright; structurally cannot edit code (hard cap 30 turns)
- **Capped helpers:** `piece-builder` (hard cap 50 turns) and `piece-reviewer` (read-only, 25 turns). Their `maxTurns` frontmatter makes Claude Code stop them, so builds can't run away. dev-process spawns helpers only as these types.
- **Workflow:** `workflows/dev-process-pipeline.js` -- the default engine for a Tier-L piece (fixed fan-out, capped agents)
- **Evals:** `evals/` + `scripts/eval-vs-baseline.sh` -- with-vs-without check of the skill on a pinned model
- **References:** `architecture-template.md` (spec template), `task-template.md` (task description format)

## Sub-Skill Orchestration

Dev Process calls these sub-skills automatically -- do not invoke them independently for implementation work:

- `brainstorming` -- design exploration (Phase 1)
- `test-driven-development` -- TDD per requirement (Phase 3)
- `subagent-driven-development` -- parallel execution (Phase 3)
- `verification-before-completion` -- verification enforcement (Phase 5)

## Usage

Triggers automatically before the first edit of any repo change that will be committed or opened as a PR, bug fixes included:

- "Fix this bug"
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

Shipping, every tier, when the repo owner opted in (the repo has the merge gate, or the owner's instructions say so): the PR body has a filled `## Dev process` block, and a second agent's verdict is posted as a `## Independent review` comment naming the head SHA. Then the PR gets merged without asking the owner. A repo with the merge gate merges and deploys it by itself.

## Installation

From the kyle-plugins marketplace -- already included if you have kyle-plugins installed.

## Budgets and caps (2.6.0)

- Multi-part work is split into pieces; each piece gets its own tier, a budget (helpers x turn cap) and a real-data check before the next piece starts.
- The same budget applies on every model. Over budget means stop and report.
- A Tier-L piece runs as the bounded workflow by default.

## Does the skill still help on a new model?

Models improve, and an instruction that helped an older model can become dead weight. Rerun this on each new model release:

```bash
dev-process/scripts/eval-vs-baseline.sh <model-id> [runs-per-case]   # e.g. claude-opus-5-5 1
```

It runs every case in `evals/` with the plugin and without it (a no-plugin baseline) on that one model, under a hard cost cap (`MAX_COST_USD`, default 5), and writes an HTML report to `evals/results/` (git-ignored). A case where the with-plugin score is not above the baseline points at instructions to trim or rewrite.
