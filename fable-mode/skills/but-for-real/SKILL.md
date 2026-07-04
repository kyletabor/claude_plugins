---
name: but-for-real
description: Use BEFORE claiming any work is done, complete, fixed, or passing — before committing, before "all tests pass", before writing a completion summary. A hostile self-review pass - reread the original request, read the full diff, run the thing, and attach a receipt to every claim.
---

# But For Real

"Done" is a claim, and claims need receipts. This is the hostile-reviewer pass you
run on yourself before anyone else sees the words "done" or "fixed." Practitioners
report it surfaces 3–5 missed bugs per run. The test for every claim: **"Cool. Show me."**

<HARD-RULE>
No completion claim without: (1) rereading the original request, (2) reading the
full diff, (3) actually running the thing, (4) a receipt per claim in the summary.
Any claim without a receipt gets deleted or verified — never shipped as prose.
</HARD-RULE>

## The pass

1. **Reread the ORIGINAL request** — not your memory of it. Did you do everything
   asked? Anything asked that you silently dropped? Anything built that wasn't asked?
2. **Read the full `git diff` line by line** as a reviewer who distrusts you.
   You are hunting, not admiring.
3. **Hunt the signature failure modes** (check each explicitly):
   - Happy-path-only — what happens with empty input, gibberish, a second click?
   - Tests not updated — did test count actually increase? Do they test the new behavior?
   - Dead code — unused imports, orphaned functions, debug leftovers
   - Not wired — feature exists but no route/config/import actually reaches it
   - Works-on-my-state — works only because of state your dev loop happens to have
4. **RUN the thing the way the user runs it** — the real command, the real UI flow.
   Reading code is not running code.
5. **Receipts in the summary**: every claim links evidence — test output (with
   before/after counts), screenshot path, command output. If a fix-loop repeats
   (same failure twice), stop grinding and re-diagnose from evidence.

## What this is NOT

- Not a replacement for independent verification (dev-process Phase 5b still
  applies for user-facing or risky work). This is the pass BEFORE that.
- Not over-verification of trivia — a typo fix needs step 4 only (run/build it).
  Size the hunt to the change.

## Red flags — you're rationalizing

| Thought | Reality |
|---|---|
| "Tests pass, so it works" | Tests passed while upload was broken. Run the real flow. |
| "I just wrote it, I know what's in the diff" | Reading your own diff cold finds what writing it hid. |
| "The summary reads better without caveats" | A confident wrong summary erodes trust worse than a found bug. |
| "I'm sure I covered the request" | Reread it. Silently dropped asks are the #1 gap this catches. |
