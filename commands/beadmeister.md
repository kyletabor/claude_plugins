---
name: beadmeister
description: Create execution-ready task beads from Architect output
argument-hint: <architecture-bead-id>
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
---

Invoke the kyle-custom:beadmeister skill, then use the beadmeister agent to create execution-ready task beads.

The architecture bead ID is: $ARGUMENTS

If no architecture bead ID was provided, ask the user which architecture to convert to task beads.
