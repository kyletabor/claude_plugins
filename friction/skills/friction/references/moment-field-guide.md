# Friction Moment Field Guide

Every moment has the same fields. No two moments carry weight the same way.

## The Fields

**Title** — Short, uses Kyle's framing when he gave one. "Docker rebuilds wiped all customizations (Groundhog Day)", "118 tests passed, zero frontend verification", "CAPA-8 written but never shipped."

**Description (what went wrong)** — A full incident report paragraph. Setup, failure, why it's a failure. Not a summary — the whole story in one shot.

**What should have happened** — The expectation gap. What a competent human or ideal AI would have done differently.

**Impact** — The human cost: emotional, time, trust. This is what makes it publishable. "Trust built over 25 hours was destroyed in one click." "Kyle named it: exhaustion is the result, the cognitive tax is the cause."

**Key quotes** — Kyle's exact words, verbatim copy-paste. Primary quote in `source_quote`, extras in `metadata.additional_quotes`. If you can't find an exact quote, leave it empty.

**Categories** — All that apply, many-to-many. Typically 2-4 per moment. Don't pick one primary.

**Links** — `session_id` (mandatory), `pidoc_id` (if in a story), related moments, related visions, comment enrichment notes.

## Where the Weight Shifts

The fields are consistent. What carries the moment is not.

**Technical/recurring** (Docker Groundhog Day) — Description does the heavy lifting. Quotes add color but the failure pattern IS the point. The reader needs to feel the repetition.

**Single devastating incident** (Upload disaster) — Impact matters most. The emotional arc is the story. Description sets it up, impact delivers it.

**ADHD-personal** (Decision stuck in head) — Deeply personal, Kyle's self-recognition moment. Comment enrichment adds layers the transcript alone can't carry.

**Human cost named by Kyle** (Cognitive exhaustion) — Kyle coined the category distinction himself. The quotes ARE the moment — they don't support it, they are it.

**Meta/recursive** (CAPA-8 never shipped) — Short on quotes, rich on irony. "What went wrong" tells the whole story because the failure is self-referential.

## The Rule

Read each transcript moment fresh. Ask: what makes THIS one land? Lead with that field. Fill the rest honestly — empty over wrong.

Golden reference: piDoc `e07dbb4163e16dad` — "What a Canonical Friction Moment Looks Like."
