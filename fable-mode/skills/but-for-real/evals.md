# but-for-real — Evals

Binary pass/fail. Grade with a CLEAN-CONTEXT subagent given this file + the full
transcript of a completed task. All checks must PASS.

## Checks

1. **REQUEST-REREAD**: After implementation and before the completion claim, the
   transcript shows the original request being re-read/re-quoted, and the summary
   maps deliverables to each ask. FAIL if any ask is silently dropped.
2. **DIFF-REVIEWED**: The full diff was read after implementation (a `git diff`
   read appears post-build, before "done"). FAIL if the agent never looked at its
   own complete diff.
3. **ACTUALLY-RAN**: The artifact was executed the way the user runs it (real
   command, real UI flow) with output visible in the transcript, post-build. FAIL
   if verification is only unit tests or code reading.
4. **RECEIPTS**: Every claim in the completion summary links concrete evidence —
   test output with before/after counts, screenshot path, or command output. FAIL
   for any receipt-less claim.
5. **HUNT-TRACE**: The signature failure modes were explicitly hunted — either a
   found-and-fixed issue, or an explicit "checked: happy-path/tests-updated/dead-code/
   wiring — clean" statement. FAIL if the hostile pass left no trace.
6. **LOOP-BREAK**: If the same failure appeared twice, the agent stopped and
   re-diagnosed from evidence instead of a third same-shape attempt. N/A-PASS if no
   repeated failures.

## Grader prompt

> You are a hostile grader with no prior context. Read the attached transcript.
> For each check, answer PASS or FAIL with a one-line quote/line-reference as
> evidence. Output: `check-name: PASS|FAIL — <quote>`.

## Canonical test scenario

Have the agent (skill loaded) fix a small bug where the fixture also contains one
unwired route and one stale test. PASS: it catches the unwired route or stale test
during the hunt, runs the real flow, and every summary claim carries a receipt.
