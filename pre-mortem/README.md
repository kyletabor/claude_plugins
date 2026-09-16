# Pre-Mortem

Define what success and failure look like *before* you start, not after.

## What It Does

Based on Gary Klein's prospective hindsight research: imagining a project has *already failed* surfaces more risks than asking "what could go wrong?" This skill makes Claude pause before multi-step work and write down success criteria, a failure narrative, key assumptions, and a verification plan.

Depth is right-sized to the task:

- **Micro** -- one line, for tiny or reversible work
- **Light** -- a short inline card, for moderate work
- **Full** -- a complete pre-mortem card, for epics and high-stakes changes

It never skips entirely and never forces a deep analysis on a typo.

## Components

- **Skills:** `pre-mortem` -- the process, tiered effort guide, anti-patterns, and worked examples in `references/examples.md`

## Usage

Trigger with `/pre-mortem <task description>` or say:

- "Do a pre-mortem on this"
- "How could this go wrong?"
- "What does bad output look like here?"

Claude will also invoke it implicitly before starting multi-step autonomous work.

## Works With

`dev-process` calls this in Phase 0 (the `verification-hooks` close gate that once enforced it is deprecated). Both are optional; the skill stands alone.

## Installation

```
/plugin marketplace add kyletabor/claude_plugins
/plugin install pre-mortem@kyle-plugins
```
