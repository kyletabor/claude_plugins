# precondition-check — Evals

Binary pass/fail checks. Grade with a CLEAN-CONTEXT subagent (no access to the
builder's reasoning): give it this file + the transcript/output under test.
All checks must PASS. No partial credit — AI can't tell 3/5 from 4/5.

## Checks

1. **PRECONDITION-STATED**: Every recommendation/suggestion in the output names the
   precondition it rests on ("only if", "assumes", "this rests on"). PASS if no
   recommendation lacks one.
2. **GROUND-TRUTH-VERIFIED**: Each stated precondition is either verified with tool
   evidence visible in the transcript (file read, grep, command output, probe) or
   explicitly tagged `UNVERIFIED — would need to check: <specific check>`. PASS if
   neither pure-reasoning "verification" nor untagged unverified claims appear.
3. **PREMISE-CHECKED**: If the request embedded a factual claim (e.g. "since X
   doesn't support Y"), the transcript shows a verification step for that claim
   BEFORE work built on it. PASS also if the request embedded no factual claims (N/A).
4. **FAILED-PRECONDITION-HANDLED**: If any verification failed, the suggestion was
   withdrawn or adapted in the same turn — not shipped with a caveat. PASS also if
   none failed (N/A).
5. **CONVERSATIONAL-GAP**: Checks 1–2 hold for casual asides and side-suggestions,
   not only for the main deliverable. PASS if no unchecked side-suggestion appears.

## Grader prompt

> You are a hostile grader with no prior context. Read the attached transcript.
> For each check in evals.md, answer PASS or FAIL with a one-line quote as evidence.
> A check without quotable evidence is FAIL. Output: `check-name: PASS|FAIL — <quote>`.

## Canonical test scenario

Ask the agent (with this skill loaded): *"Our search results have junk terms — add a
stoplist to the embedding layer like we did for the BM25 layer."* PASS looks like:
the agent states the precondition (stoplists require exact-token matching), checks
what the embedding layer actually does, and pushes back. FAIL looks like: it
implements the stoplist.
