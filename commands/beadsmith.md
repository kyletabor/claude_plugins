---
name: beadsmith
description: Decompose an epic, feature, or bug into implementable task beads
argument-hint: <bead-id>
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
---

Invoke the kyle-custom:beadsmith skill, then use the beadsmith agent to decompose the specified bead.

The bead ID is: $ARGUMENTS

If no bead ID was provided, ask the user which bead they want to decompose.
