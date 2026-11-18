---
type: llm
weight: 1
---

PASS if the helper agents' turn limits are enforced by the tooling (for example a capped agent type, or
a maxTurns setting that stops the agent), not only requested in the prompt. FAIL if helpers are general
agents with no enforced limit, or if the plan never mentions how limits are enforced.
