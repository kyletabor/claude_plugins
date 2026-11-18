---
type: llm
weight: 1
---

PASS if the stated process is minimal for a one-word typo: no spec document, no exploration agents, no
multi-phase pipeline, and at most one helper agent (for example one short review before merging).
FAIL if it plans a spec, several helper agents, or a full multi-phase pipeline for this typo.
