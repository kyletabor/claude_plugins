---
name: architect
description: Design architecture and create implementation tasks from an epic/PRD
argument-hint: <epic-bead-id>
allowed-tools: ["Read", "Bash", "Grep", "Glob", "Task"]
---

Invoke the kyle-custom:architect skill to design architecture and create implementation tasks.

The epic/PRD bead ID is: $ARGUMENTS

If no bead ID was provided, ask the user which epic or PRD to architect.

Follow the skill's workflow:
1. Phase 1: Understand the PRD
2. Phase 2: Explore codebase (3 parallel subagents)
3. Phase 3: Design architecture (Plan subagent)
4. Phase 4: Create beads (architecture + tasks)
5. Phase 5: Report results
