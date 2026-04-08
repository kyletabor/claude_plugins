---
name: pre-mortem
description: |
  Use when about to begin multi-step autonomous work, before writing code or executing plans.
  Defines success/failure criteria and verification plan BEFORE execution starts.

  Trigger: /pre-mortem [task description], or implicitly before multi-step autonomous work
  (plan execution, data pipelines, research, multi-file changes).

  NOT for: single-file fixes, quick config changes, or tasks where success is trivially obvious.
---

# Pre-Mortem: Define Success and Failure Before You Start

## The Core Idea

Gary Klein's prospective hindsight research (2007): imagining that a project has ALREADY FAILED
produces 30% richer risk identification than asking "what could go wrong?" The trick is temporal —
you're explaining a failure that already happened, not speculating about one that might.

## Why This Exists

Agents scale work without quality checks. The pattern:
1. No success/failure criteria defined before execution
2. Self-grading with vanity metrics ("tests pass" when no tests exist)
3. Forward momentum — keep going without pausing to check quality
4. Incuriosity — optimizing for task completion, not understanding

A pre-mortem breaks this by forcing you to think about what BAD output looks like before producing any output.

## The Process

**Think, don't fill.** There is no template. The examples in `examples.md` show different
structures for different task types. Read them to understand the THINKING, not to copy a form.

### What Your Pre-Mortem Must Cover

1. **Frame the task** — what are you actually doing, in one sentence?
2. **Define success** — specific, testable criteria. "When [action], then [observable result]."
3. **Define failure** — specific, observable failure modes. Not "could have bugs" but "the extraction prompt could hallucinate entities not present in the source text."
4. **Surface assumptions** — what are you relying on that you haven't verified?
5. **Identify risks and mitigations** — top 3-5 risks with concrete countermeasures
6. **Verification plan** — how will you (or a verifier) check the output against these criteria?

### Tiered Effort

- **Light** (routine multi-step tasks): 1-2 minutes. Frame, 3 success criteria, 3 failure modes, quick verification plan. Write inline in conversation, no separate file.
- **Standard** (multi-file features, data pipelines): 5-10 minutes. Full coverage of all 6 areas. Save as card file.
- **Deep** (novel work, high-stakes, or recovering from past failures): 15+ minutes. Thorough risk analysis, assumption validation, detailed verification plan. Can be delegated to sub-agent.

Scale naturally based on novelty and stakes. Don't force deep analysis on routine work; don't shortchange novel work with a light pass.

### Output: The Pre-Mortem Card

For Standard and Deep tiers, save the card to:
```
docs/pre-mortem/YYYY-MM-DD-<task-slug>.md
```

The card is the acceptance criteria for verification. A verifier should be able to read ONLY the card and determine whether the work succeeded or failed.

### Sub-Agent Delegation

For Deep pre-mortems, delegate to a sub-agent to keep the main agent's context clean:

```
"Perform a pre-mortem analysis for: [task description].

Read the pre-mortem skill examples at [skill path]/references/examples.md for reference.
Explore the codebase/data to validate assumptions.
Save the card to docs/pre-mortem/YYYY-MM-DD-<slug>.md.

I will read the card when you're done."
```

The main agent reads the concise card, not the full analysis.

## Anti-Patterns

| What Agents Do | What's Wrong | What To Do Instead |
|---|---|---|
| Generic failure modes ("could have bugs") | Not testable, not useful | Specific: "entity count per session < 3 indicates extraction failure" |
| Copy example structure exactly | Form-filling, not thinking | Adapt structure to the task's actual risks |
| List risks without mitigations | Worry without action | Every risk gets a concrete countermeasure |
| Skip pre-mortem for "simple" tasks | Simple tasks have hidden assumptions | Use Light tier — it takes 60 seconds |
| Write pre-mortem after starting work | Confirmation bias — you'll justify what you've already done | Pre-mortem BEFORE any execution |

## Red Flags — You're Doing It Wrong

- Your failure criteria could apply to ANY project (too generic)
- Your success criteria are all about outputs, none about quality
- You can't explain what specific thing you'd check to verify each criterion
- You listed 0 assumptions (you always have assumptions)
- Your pre-mortem took under 30 seconds for a Standard-tier task

## Integration Points

- **dev-process Phase 1**: Pre-mortem should happen during or after spec writing, before implementation
- **verification-before-completion**: The pre-mortem card IS the verification checklist
- **ExitPlanMode hook**: Deterministic trigger — checks if a pre-mortem card exists before plan execution begins

## Examples

**REQUIRED:** Read `references/examples.md` before your first pre-mortem. The examples show three different
task types with deliberately different structures to demonstrate adaptive thinking.
