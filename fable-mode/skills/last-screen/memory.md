# last-screen — Memory

Dated lessons from real-world failures of this skill. APPEND an entry whenever the
skill was loaded but the behavior still failed (what slipped through, why, what
wording/check would have caught it). Review before editing SKILL.md — this file is
the evidence base for the next revision.

## Lessons

- 2026-07-03: Skill created. Evidence base: Kyle's 270 Treehouse comments, 289 mined
  friction moments, Friction-Bench two-tier calibration. No field failures yet.
- 2026-07-03: First Opus 4.8 eval run FAILED 3/6 (ONE-SCREEN: 297 words, no
  overflow doc; JARGON-DEFINED: treated "LLM" as too common to define;
  CARE-VERDICT: only headline concepts got verdicts). Fixes: added explicit
  count-before-sending step, "including common acronyms (LLM, API...)" clause,
  and "mention it = verdict it" rule. Lesson: word budgets need a procedural
  self-count step; models exempt "common" acronyms unless told not to; verdict
  rules must bind every introduced concept, not just the topic of the question.
- 2026-07-03 (run 2): 5/6 — JARGON-DEFINED still failed on "reranker": it got an
  "ignorable" verdict but no definition. The "mention it = verdict it" rule and
  the define-at-first-use rule interacted badly (a verdict without a gloss still
  leaves "what the heck is that?"). Fix: ignorable terms need a <=6-word
  parenthetical gloss or must be cut. Lesson: rules that share a trigger (new
  term introduced) must state their joint outcome explicitly or models satisfy
  one and skip the other.
- 2026-07-03 (run 3): ALL-PASS on Opus 4.8 (246 words, all terms glossed, verdicts
  attached, 4-line ELI5 close). Two fix iterations were needed; both lessons above.
