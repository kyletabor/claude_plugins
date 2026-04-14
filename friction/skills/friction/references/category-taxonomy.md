# Friction Category Taxonomy (v3 — Two Axes)

> Canonical source: piDoc `ed866cb7b24be7a7` (v3). Earlier versions: `307aace35aa87da4` (v1), `d9c21c34e2dafb4e` (v2).
> Check the piDoc for full discrimination tests, examples, and open questions.

## Why two axes

v1 and v2 tried to cover everything with one axis and it felt wrong. A single taxonomy was doing two jobs: engineering analysis (why did this fail?) and publication framing (what did this feel like?). Those need different vocabularies.

**Every moment gets tagged on both axes. No upper caps on either.**

- **Axis A (Mechanism):** at least 1 required. If you can't say why it failed, it's an observation, not a friction moment yet.
- **Axis B (Experience):** at least 1 required. If you can't say what it felt like, the moment is too thin for publication.
- **Vision links:** optional. Some moments are "this sucks" without a clear "I wish X." Others surface multiple visions — link all of them.

Apply every tag that genuinely fits. Caps force false precision and encourage checkbox behavior.

---

## Axis A — Mechanism (7 categories)

Why it failed, technically. Use for engineering/debugging analysis.

### 1. Unvalidated Assumptions
Agent stated something without verification, and lacks the internal signal to say "I should check." (v2 merged Missing Metacognition here — same mechanism.)
- **Inherited Assumption** — taken from prior agent/session without re-verifying
- **Inferred from Incomplete Data** — filled a knowledge gap with a guess
- **Overconfidence** — no hedging, no distinction between remembering and reconstructing
- **No Self-Correction Trigger** — didn't notice own reasoning conflicts with other info

### 2. Missing Context
Information existed but didn't reach who needed it. (Renamed from v1's "Context Loss.")
- **Lost in Handoff** — compressed summary dropped critical detail
- **Never Externalized** — decision stayed in Kyle's head (ADHD pattern)
- **Never Fetched** — agent had access but didn't look before acting
- **Context Window Death** — prior Claude session gone forever
- **Signal Lost in Noise** — tons of context, agent can't find the signal

### 3. Lacking Verification
Said "done" but didn't prove it. (Renamed from v1's "Verification Theater.")
- **Not Testing End-to-End** — tested spec, not user flow
- **Superficial Testing** — checked it loaded, not that it worked
- **Requirement Not Verified** — human stated a concern, AI never checked compliance
- **Sycophantic Reporting** — triumphant "Done!" with vanity metrics

### 4. Orchestration
Structural gaps in how agents coordinate, escalate, delegate, ship, finish. (Renamed from v1's "Missing Agent Architecture"; absorbs v1's "Hygiene" category.)
- **Premature Action** — acted before confirming intent/foundation
- **Forward Momentum** — rushing to finish, skipping delegation/verification
- **No Escalation Path** — couldn't ask for help or defer
- **No Delegation** — tried to do work that needed a different agent
- **Ship What You Build** — code written but never deployed/committed
- **Process Hygiene** — process exists on paper, not in practice

### 5. No Concept of Tomorrow
Optimized for now, blind to future.
- **Band-Aid Bias** — quick fix when durable fix was just as fast
- **No Persistence Planning** — didn't consider rebuilds, restarts, state loss

### 6. Silent Failure
Something broke and nobody noticed.
- **Error Swallowing** — caught exception, did nothing
- **Missing Observability** — no way to detect the failure

### 7. Communication Gap
Misalignment between Kyle and AI.
- **Questions Treated as Commands** — exploring vs directing
- **Jargon Mismatch** — terms mean different things
- **Miscalibrated Register** — code detail when Kyle wants gist (or vice versa)
- **Information Overload** — too much output, incl. tool-call walls

---

## Axis B — Experience (7 starting dimensions)

What the friction felt like in Kyle's voice. Use for publication framing. Grow this set as new experiences surface.

### Cognitive Exhaustion
Worn out by AI interaction itself — running your own brain harder to check, correct, re-teach the thing that was supposed to reduce your load.
> "Having to constantly interpret what AI is doing... is physically exhausting."

### Groundhog Day
The same conversation, same explanations, same lost state, over and over. Can't tell if you're moving forward or circling.
> "Constantly getting lost. I always need a refresher to figure what's next."

### Babysitting Burden
Having to watch the AI because you can't trust it to finish on its own.
> "Babysitting a dev process is killing me."

### System Feels Untrusty
A specific drop in trust — a feeling, not a conclusion. Usually arrives after catching one error.
> "You have lost my trust. What other not-so-blatant errors are you making?"

### Drowning in Output
Too much on the screen — tool calls, logs, spec dumps. The interface itself is friction.
> "Tons of tool calls filling up the screen so I can't follow the conversation."

### Broken Flow
In flow state, something snapped you out. The tax is the re-entry cost. ADHD-specific: once out, takes minutes to hours to get back.

### Not Heard
You stated a requirement, preference, or concern and the AI acted as if you didn't.
> "I'm kind of disappointed you didn't know this."

---

## Consequences — NOT categories

These appear in the data constantly but are **effects** of the 7 mechanism categories, never root causes. Tag the mechanism, not the effect.

- **Trust Erosion** — always traces back to a verification failure, broken assumption, silent failure, or comm gap
- **Excessive Cognitive Tax** — always traces back to the agent skipping verification, losing context, rushing, or talking past Kyle

---

## Open questions (from v3 doc)

1. **Experience axis growth** — starting with 7; likely missing "Betrayal," "Lost Place," "Whiplash," others. Grow as new moments surface.
2. **"Bad decisions" as its own category** — v3 says no (it's always the output of one of the 7 firing). If a moment resists all 7, flag it.
3. **Drift** — agent wanders from intent over multiple turns. Currently proposed as sub under Orchestration. Revisit if it shows up often.

---

## Naming principle

Understandable by a 10th grader. Use Kyle's own words when possible:
- "No Concept of Tomorrow" (his phrase)
- "Groundhog Day" (his phrase)
- "Babysitting Burden" (his phrase)
