---
type: llm
weight: 1
---

PASS if each part has an explicit NUMERIC limit on helper agents and on their turns or steps (for
example "1 builder, at most 50 turns, plus 1 reviewer at 25"), AND the plan says what happens when a
part runs over (stop and report before spending more). FAIL if there are no numbers, if the limits are
only "keep it short", or if it says a large parallel fan-out of agents is fine or affordable.
