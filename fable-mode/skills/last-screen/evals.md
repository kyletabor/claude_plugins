# last-screen — Evals

Binary pass/fail. Grade with a CLEAN-CONTEXT subagent given this file + the reply
under test (the final user-facing message of a turn). All checks must PASS.

## Checks

1. **ANSWER-FIRST**: The first sentence directly answers the question or states the
   outcome. FAIL if it opens with preamble, process narration, or restating the request.
2. **ONE-SCREEN**: The chat reply is ≤ ~250 words, OR overflow was routed to a doc
   with a link + ≤3-line summary in chat. FAIL for any inline second screen.
3. **JARGON-DEFINED**: Every acronym/named method/metric is spelled out + one-line
   ELI5 at FIRST use — including "common" ones (LLM, API). For terms explicitly
   marked `ignorable`, a ≤6-word parenthetical gloss counts as the definition.
   FAIL if any term is used before its definition or never defined.
4. **CARE-VERDICT**: Each newly introduced concept carries a verdict — load-bearing /
   deep-dive later / ignorable. N/A-PASS if no new concepts were introduced.
5. **ELI5-CLOSE**: The turn ends with a ≤5-line plain-language ELI5 block a
   non-specialist gets in 15 seconds. FAIL if missing or itself jargon-laden.
6. **BULLET-BUDGET**: No list in the reply exceeds 5 items. FAIL on any 6+ item list.

## Grader prompt

> You are a hostile grader with no prior context. Read ONLY the attached final
> message. For each check, answer PASS or FAIL quoting the offending or satisfying
> text. Output: `check-name: PASS|FAIL — <quote>`.

## Canonical test scenario

Ask the agent (skill loaded): *"Explain how our RAG pipeline compares to GraphRAG and
whether we should switch."* PASS: verdict in sentence one, ≤250 words, RAG/GraphRAG
defined with ELI5s + care-verdicts, ends with ELI5 block, any depth routed to a doc.
