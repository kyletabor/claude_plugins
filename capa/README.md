# CAPA

Corrective and Preventive Action process for fixing broken processes.

## What It Does

CAPA is an eight-phase investigation framework that fixes the process first, then uses the fixed process to fix the original defect. Use it when a delivered feature does not work despite process skills being in place, when the same failure pattern recurs, or when "done" was claimed but the feature is actually broken. It is not for simple bugs or first-time implementation -- it is for when the process itself failed.

## Components

- **Skills:** `capa` -- structured eight-phase workflow (Detect, Investigate, Research, Design, Implement, Verify, Re-Execute, Close)
- **Commands:** `/capa <description>` -- starts a CAPA investigation with a description of what broke
- **References:** `schema.sql` (SQLite schema for CAPA records), `queries.sql` (common queries)

## Usage

Trigger with `/capa [what's broken]` or natural language like:

- "Figure out why X isn't working"
- "Why did this fail again?"
- "Our process didn't catch this"
- "Do a retrospective on X"

CAPA records are tracked in a shared SQLite database at `/home/openclaw/.openclaw/capa/capa.db`. Every phase transition is logged to an append-only changelog table.

## The Eight Phases

1. **Detect** -- document the failure and create a CAPA record
2. **Investigate** -- trace the failure chain using 5 Whys, map failures to skills/gates
3. **Research** -- find proven solutions from external and internal sources
4. **Design** -- propose 2-3 fix approaches with trade-offs (requires approval)
5. **Implement** -- build the approved process changes
6. **Verify** -- dry-run the fix against the original failure scenario
7. **Re-Execute** -- fix the original defect using the new process as proof it works
8. **Close** -- record outcome, save learnings, check trends

## Installation

From the kyle-plugins marketplace -- already included if you have kyle-plugins installed.
