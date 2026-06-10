---
name: dev-process
description: |
  THE SINGLE ORCHESTRATOR for all implementation work. This skill should be used ANY TIME the user asks
  to implement, build, or execute a plan that involves multi-file changes or non-trivial features. This
  is the DEFAULT workflow for all implementation work beyond single-file fixes. You do NOT need to be
  explicitly told to use it — if the task involves architecture, multiple files, agent teams, or a plan
  to execute, USE THIS SKILL.

  FIRST it RIGHT-SIZES the task (Phase 0): small/reversible work takes a fast lane; only large or
  high-risk work runs the full pipeline. Minimum process that fits — never maximum-by-default.

  This skill orchestrates sub-skills — do NOT use them independently for implementation work:
  - `brainstorming` — design exploration (Phase 1)
  - `test-driven-development` — TDD per requirement (Phase 3)
  - `subagent-driven-development` — parallel execution engine (Phase 3)
  - `verification-before-completion` — verification enforcement (Phase 5)

  It also integrates with beads for persistent requirement tracking. Every requirement becomes a beads
  issue with acceptance criteria, tracked from creation through verified closure.

  Examples of when this skill activates:
  - "Go implement this"
  - "Build this feature"
  - "Execute this plan"
  - "Implement the architecture"
  - "Go build it"
  - "Use the dev process"
  - "Follow the standard pipeline"
  - "Implement this"
  - "Build this"
  - Any request to implement a PRD, epic, or multi-step plan
---

# Structured Development Process

Spec-driven, gate-reviewed development pipeline for rigorous implementation.

> **Core principle (READ THIS FIRST): run the *minimum* process that fits the task, not the maximum.**
> The old version of this skill applied the full 6-phase, 7-agent pipeline to every change — a typo got
> the same treatment as a payment system. That is the documented cause of a 180M-token blowup. Rigor is
> spent where a bug actually hurts; small, reversible, internal work gets a fast lane. **You ALWAYS
> right-size first (Phase 0). You NEVER skip the gates that catch real risk.**

## Phase 0: Right-Size First (MANDATORY — ALWAYS the first step)

Before any exploration, spec, or sub-agent, classify the task on two axes and pick the lightest lane.
This is a 15-second decision, stated in one line in the conversation (e.g. *"Tier S — 2 files, reversible,
no risk triggers → fast lane"*). Default to the SMALLEST tier; **risk triggers can only escalate, never lower.**

### Axis 1 — Size
- **Small**: 1–2 files, reversible, an obvious/local change, a bugfix with a known cause.
- **Medium**: several files, moderate logic, a new internal module or multi-file refactor.
- **Large**: an epic, novel architecture, or many interdependent legs.

### Axis 2 — Risk triggers (if ANY are true, the task is at LEAST Tier M and full verification fires)
1. Touches a **prod URL / deployed service**
2. Touches **persistent or destructive data**
3. Touches **auth · permissions · secrets**
4. Touches **money / billing**
5. **Ships a Claude Code plugin**
6. **User-facing UI behavior**

### The lanes

| Tier | When | Process that runs | Sub-agents |
|------|------|-------------------|------------|
| **S — Fast lane** | Small AND zero risk triggers | Micro pre-mortem (1 line) → implement → **machine gate** (tests + build + types pass) → self-check (`verification-before-completion`) → commit. NO spec doc, NO explore swarm, NO separate reviewers, NO independent-verifier. | 0–1 |
| **M — Spec-lite** | Medium, OR Small+a risk trigger | Light pre-mortem → short inline spec (goal · files · acceptance) → TDD → machine gate → **one** combined review → risk-typed verification (see Phase 5). | 1–3 |
| **L — Full pipeline** | Large, epic, or high blast-radius | The full Phase 1→6 below, unchanged. Full pre-mortem card + GATE beads + independent verification + staging gate. | 5–8+ |

**Then jump to the matching lane.** Tier S/M execute the lightweight steps above and skip to Phase 5's
risk-typed verification + Phase 6 ship. Only **Tier L** runs the complete Phase 1–6 pipeline that follows.

### Resource budget (applies to every tier — prevents runaway token cost)
- **Fan-out ceiling**: Tier S = 0 explore agents, Tier M = 0–1, Tier L = up to 3. Never a fixed floor.
- **Agent turn caps**: soft cap ~15 turns (agent summarizes + presents stop/continue), hard cap ~30 (terminate with a state summary). Cap any fix→re-review loop at **2** iterations.
- **Pass digests, not transcripts**: each sub-agent gets a pre-scoped task (relevant spec section + file paths) and returns a 1–2k-token summary. Never "read the whole spec and codebase."
- **Loop detection**: if a step produces no diff / the same test failure twice / a repeated re-plan → abort and surface it, don't grind.
- **Model/effort awareness**: on Opus (high reliability, no token pressure) the full fan-out is affordable. On Fable / `ultracode`, HARD-cap fan-out to 2–4 workers, prefer a single long-running agent over a swarm, and do not stack redundant verification. Right-size effort = f(tier × model).

### Pre-mortem is ALWAYS done — its depth right-sizes
A pre-mortem is always worth 30 seconds of "how could this go wrong." Scale the rigor, never skip it:
**Micro** (Tier S, 1 line of risks) · **Light** (Tier M, inline) · **Full card** (Tier L/epic, the GATE bead). See the `pre-mortem` skill.

## When NOT to use this skill at all
- Pure research/exploration or a question (no code change).
- A one-character/one-line edit you can make and verify in a single step (just do it + run the test).

## The Tier-L Pipeline (everything below applies to Tier L; Tier S/M use the lanes above)

```
Phase 1: Spec → Phase 2: Spec Review → Phase 3: Implement → Phase 4: Code Review → Phase 5: Test → Phase 6: Verdict
```

### Optional: run the Tier-L pipeline as a bounded workflow (deterministic engine)

For Tier-L work you MAY execute the phases below as a single **bounded workflow** instead of hand-orchestrating
them. It ships with this plugin and enforces fixed fan-out, turn-capped agents, and compact summary handoffs —
the structure that prevents token blowups:

> `Workflow({ scriptPath: "<plugin-root>/workflows/dev-process-pipeline.js", args: { task: "<what to build>", repo: "<path>", appUrl: "<url if user-facing>", userFacing: true } })`

The plugin root is two levels up from this skill's "Base directory" line (`.../dev-process/`).

**Status: v1 — not yet the default.** Until it's battle-tested on a real epic, the hand-orchestrated phases
below remain the proven path. Use the workflow when you want deterministic, capped orchestration; otherwise
follow the inline phases. The phase contracts are identical either way.

## Phase 1: Architecture Spec

Write a detailed spec BEFORE any code. This phase uses parallel codebase exploration to inform the design.

### Step 0a: Design Exploration (When Starting From Scratch)

If the feature is greenfield or the approach is unclear, invoke the `brainstorming` skill first for
design exploration. Let brainstorming run its full cycle (diverge → converge → decide), then carry the
chosen approach into the spec below. Skip this if you already have a clear PRD or plan to execute.

### Step 0a-pre: Pre-Mortem (MANDATORY for Epics)

<HARD-GATE>
If this work is being tracked under an epic bead (`issue_type = "epic"`), the Verification
Suite requires a `GATE: Pre-mortem filed` bead backed by a real pre-mortem card before
implementation begins. The `pre-mortem-filed` gate enforces CLAUDE.md rule #2 ("Pre-mortem
before multi-step work"), which prior dev-process revisions silently omitted.
</HARD-GATE>

1. Invoke the `pre-mortem` skill. Output a Standard-tier card with success criteria, failure
   narrative, surfaced assumptions, and a verification plan.
2. Save it to `docs/pre-mortem/YYYY-MM-DD-<slug>.md` in the project directory.
3. Create the GATE bead: `bd create --title='GATE: Pre-mortem filed' --description='...'`
   (or use `evaluate-gates.sh --emit-create pre-mortem-filed`).
4. Close that GATE with a VERIFIED note containing a `PREMORTEM:` marker pointing at the card:
   `bd update <id> --notes='VERIFIED: ... | PREMORTEM: <path-to-card>'`.

For non-epic work (single feature, bug fix, chore), skip this step — the gate won't apply.

### Step 0b: Verify Current State (MANDATORY)

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

**Fan-out is tier-sized (Phase 0): Tier S launches none, Tier M 0–1, Tier L up to 3 — and only when the
codebase is genuinely unfamiliar. This is a ceiling, not a floor.** When exploration is warranted, launch
up to 3 Explore subagents in parallel using the Task tool:

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

## Dependency Verification
[MANDATORY — for each external dependency referenced in the spec]
| Dependency | Assumed Capability | Verified At Source? | Source Path |
|---|---|---|---|
| @pkg/name | method X exists | YES/NO | node_modules/@pkg/name/dist/file.js:L123 |
[Phase 2 reviewer will REJECT specs without this section. The GATE beads issue
cannot be closed without VERIFIED: evidence citing these source paths.]

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

### Step 5: Create Beads Issues From Requirements

After the spec is approved, create a beads issue for EACH requirement/acceptance criterion:

```bash
bd create --title='R1: [requirement name]' --description='[acceptance criteria — testable assertion]' --type=feature
bd create --title='R2: [requirement name]' --description='[acceptance criteria]' --type=feature
# ... one per requirement
```

Then spawn **all applicable GATE beads** from the Verification Suite registry. The evaluator
picks which gates apply to THIS spec (e.g. plugin-installed if the spec touches plugin paths,
pre-mortem-filed if the work is tracked under an epic bead, deps-verified if the spec has a
populated Dependency Verification section):

```bash
# Emit bd create commands for every applicable gate, then execute them.
EVAL=~/projects/claude_plugins/dev-process/scripts/evaluate-gates.sh
for gate_id in $("$EVAL" --for-spec <path-to-spec.md>); do
  eval "$("$EVAL" --emit-create "$gate_id")"
done
```

The registry lives at `~/projects/claude_plugins/dev-process/config/verification-gates.json`.
To see all enabled gates: `$EVAL --list`. To add a new one (from a closed CAPA), see
`~/projects/claude_plugins/dev-process/references/adding-a-gate.md`.

<HARD-GATE>
GATE beads are NOT optional. `verify-before-close.sh` will BLOCK closing any requirement bead
whose applicable gates don't have CLOSED GATE beads with the correct evidence_marker in their
VERIFIED notes. Skipping Step 5 = blocked at close time.

The Verification Suite is the consolidated enforcement for recurring AI-agent failure modes
(CAPA-8 deps-verified, CAPA-14 plugin-installed, CLAUDE.md-rule-2 pre-mortem-filed, and any
future gates added when new CAPAs close). Read the registry BEFORE you write R-beads so you
know what evidence each GATE will demand.
</HARD-GATE>

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
6. Are dependency assumptions verified AT SOURCE? For each external dependency
   referenced in the spec, was the ACTUAL library source (node_modules/pkg/dist/*)
   inspected — not just our wrapper code? Are source file paths cited as evidence?
   If the spec references dependency capabilities without citing library source → REJECT.
7. VERIFICATION SUITE CHECK (MANDATORY). Run:
       EVAL=~/projects/claude_plugins/dev-process/scripts/evaluate-gates.sh
       "$EVAL" --for-spec <spec-path>
   PASTE the full output into your verdict. For each gate id the evaluator lists,
   confirm a corresponding GATE bead (open OR closed, matching the gate's registry
   title exactly) exists in the project. If any applicable gate has no bead, REJECT
   and name the missing gate(s). A verdict that omits the evaluator output is
   auto-rejected by the lead — do not skip step 7.
Output: APPROVE with notes, or REJECT with specific issues."
```

If REJECTED: fix the spec and re-review.
If APPROVED: close the applicable GATE beads (with their required evidence markers)
before proceeding to Phase 3. The Dependency Verification section below is the recipe for
the `deps-verified` gate; other gates have their own close-criteria recorded in the registry
(run `$EVAL --list` and inspect `verification-gates.json` for each gate's `evidence_marker`
and `acceptance` string).

### Dependency Verification (Close the `deps-verified` GATE Issue)

<HARD-GATE>
If `deps-verified` appeared in the evaluator output, you MUST close its GATE bead with a
VERIFIED: note citing source paths before starting implementation. The verify-before-close
hook blocks closing any R-prefixed requirement until every applicable gate has a closed
GATE bead with the correct evidence_marker. This is architectural enforcement, not a
suggestion.
</HARD-GATE>

For each external dependency referenced in the spec:

1. **Read the actual library source** — `node_modules/pkg/dist/*`, NOT your wrapper code.
   If the dependency is inside a container, exec in and read the source there.
2. **List the methods/APIs you found** — what does the library actually expose?
3. **Compare to spec assumptions** — does the library support what the spec assumes?
4. **Look for capabilities the spec missed** — are there better-suited APIs you didn't know about?

Then close the GATE issue with evidence:

```bash
bd update <gate-id> --notes='VERIFIED: [date] | Dependencies checked: [list] | Source paths: [node_modules/ paths where capabilities confirmed]'
bd close <gate-id>
```

If the library does NOT support what the spec assumed → update the spec and re-review.

## Phase 3: Implementation

Use agent teams for parallel work. Follow the dependency diagram from the spec.

### Sub-Skill Integration

- **Use the `test-driven-development` skill** for each requirement. Write the test first, then the
  implementation. This is not optional — every requirement gets TDD treatment.
- **Use the `subagent-driven-development` skill** to parallelize work across independent requirements.
  Each implementation leg runs as a subagent with isolated scope.

### Progress Tracking

After each requirement is implemented (code + tests written):
1. Update its beads issue: `bd update <id> --status=in_progress`
2. Git checkpoint: commit the requirement with a clear message (e.g., "Implement R3: [name]")
3. Do NOT batch commits — one commit per requirement keeps the trail clean

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

## Phase 5: Testing + Verification (RIGHT-SIZED TO WHAT CHANGED)

**Invoke the `verification-before-completion` skill** to wrap this phase. The KEY rule: **verification
scales to what you're verifying.** You don't drive a browser to check a backend refactor, and you don't
trust unit tests alone for a UI feature. Pick the mode(s) that match the change — a change can need more
than one.

### 5a: Run Tests (Builder — every tier)

1. **Unit tests**: Run the full suite — report BEFORE and AFTER counts (e.g. "was 118, now 130"; if the count didn't increase, new tests aren't there or aren't running).
2. **Build + types**: must pass clean.
3. **Regression check**: existing functionality isn't broken.

This is the **machine gate**. For **Tier S with no risk triggers, a green machine gate + the
`verification-before-completion` self-check is sufficient — STOP HERE.** No separate verifier agent.

### 5b: Independent Verification — fires for Tier M/L or ANY risk trigger (NOT for clean Tier S)

<HARD-GATE>
When independent verification applies, the agent who built it CANNOT be the one who certifies it.
Self-certification shipped broken features in 5 out of 5 past incidents. This is non-negotiable
**for the work that qualifies** — but it is sized to the change, per below. A clean Tier-S change
verified by a green machine gate does NOT need a separate agent.
</HARD-GATE>

Choose the verification mode by what changed:

**A) User-facing change (UI / user workflow) → Independent UI verification.**
Spawn the `independent-verifier` agent (read-only + Playwright). It drives the REAL app the way the user
does and checks each acceptance criterion from the user's perspective, with screenshots:
```
"Verify this feature from the USER's perspective.
Spec: [path]   App URL: [the URL the user actually uses]
For EACH acceptance criterion: load the app like the user does, perform the action, check the observable
result, screenshot it. Report a PASS/FAIL table with evidence. You CANNOT edit code — only observe and report."
```

**B) Backend-only change (logic / API / data / no UI) → Independent integration verification.**
A browser proves nothing here. Instead, a **separate agent (not the builder)** runs and inspects
**unit + integration/workflow tests that simulate the real end-to-end flow against real data (not mocks)**
— proving the pieces actually work together, not just in isolation:
```
"Independently verify this backend change. Do NOT trust the builder's claims.
Spec/acceptance: [path or list].
1. Run the unit suite + the integration test(s) that exercise the REAL flow this change participates in.
2. If an integration/workflow test for this path doesn't exist, write or run one that simulates it end-to-end
   (real inputs → real outputs), then confirm it passes.
3. Check the change actually satisfies each acceptance criterion. Report PASS/FAIL with the command output as evidence.
You CANNOT ship — only run, inspect, and report."
```
For lower-risk Tier-M backend work, the integration test passing IS the verification (the deterministic
result is the evidence); reserve the separate-agent pass for backend changes that hit a risk trigger
(auth, data, money, deployed service).

**C) Both UI and backend → do both A and B.**

The verifier updates beads as it confirms each requirement:
```bash
bd close <id> --reason='Verified: [evidence — screenshot path, DOM assertion, or integration-test output]'
```

If verification FAILS → return to Phase 3 with the details (cap the fix→re-verify loop at 2).
If it PASSES → proceed to Phase 5c (if plugin work) or Phase 6.

### 5c: Plugin Verification (If Work Involves Plugins)

<HARD-GATE>
Publishing a plugin to a marketplace and verifying files exist is NOT verification.
The plugin must actually LOAD in a fresh Claude Code session. This step has been missed
repeatedly — "pushed to GitHub" was treated as "done" when the plugin wasn't even installed.
</HARD-GATE>

Skip this section if the work doesn't involve Claude Code plugins. For plugin work:

**For NEW plugins (not yet installed):**

1. Launch a fresh Claude Code session (use the `tmux` skill if available):
   ```bash
   SESSION="agent-verify-plugin-$(openssl rand -hex 2)"
   tmux new-session -d -s "$SESSION" -c <workdir> "claude --dangerously-skip-permissions"
   ```
2. Install the plugin: send `/plugin install <name>` to the session
3. Reload: send `/reload-plugins`
4. Verify the skill appears: ask the session to list skills containing the plugin name
5. Clean up the tmux session

**For UPDATED plugins (version bump):**

1. Launch a fresh Claude Code session (new sessions fetch updated marketplace)
2. Run `/doctor` — check for plugin errors
3. Run `/skills` — verify the skill is listed with the correct plugin name
4. Invoke the skill with a test prompt to confirm it activates correctly
5. Clean up the tmux session

**Verification evidence must include:**
- The `/skills` or skill list output showing the plugin loaded
- Or the skill activation output showing it triggered correctly
- Plugin version confirmed (cache shows correct version)

Do NOT accept "marketplace.json updated" or "files pushed" as verification. The plugin must load.

## Phase 6: Verdict & Ship

### Beads Gate (MANDATORY)

Before evaluating the pre-ship checklist, check beads:

```bash
bd list --status=open
```

If ANY beads issues for this feature remain open, you are NOT done. Do NOT claim completion.
Go back to the phase where the open requirement needs work.

### Pre-ship checklist (all must be YES):
- [ ] Spec includes Current State Verification with command output?
- [ ] Acceptance criteria are executable (not prose)?
- [ ] Test count increased? (before: ___, after: ___)
- [ ] Independent verifier (not builder) confirmed feature works?
- [ ] Verifier evidence (screenshots/DOM checks) included in report?
- [ ] All beads issues for this feature are closed? (`bd list --status=open` returns none)

If all YES:
1. Final commit with clean message
2. Close/update completed tasks in your tracking system
3. Save learnings to claude-mem for future reference
4. **Present beads summary to user as proof of completion:**
   ```bash
   bd list  # Show all issues — should all be closed with verification evidence
   ```
5. Report summary to user WITH verifier evidence AND beads trail attached

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

- **Right-size first, then don't skip the gates that apply to that tier** — skipping a Tier-L review costs hours of rework; running Tier-L ceremony on a Tier-S typo costs tokens and time. Both are failures.
- **Spec changes during implementation** are OK but must be documented and re-reviewed (Tier M/L)
- **Small scope** is better — but right-size it; don't multiply fixed overhead across many tiny cycles. Batch many small same-session items under ONE parent bead and run them in a single lightweight loop.
- **Claude CLI for LLM calls**: Use `CLAUDECODE= claude --print` not Anthropic SDK

## Additional Resources

### Reference Files
- **`references/architecture-template.md`** — Lighter-weight architecture spec template
- **`references/task-template.md`** — Task description format with step-by-step instructions
