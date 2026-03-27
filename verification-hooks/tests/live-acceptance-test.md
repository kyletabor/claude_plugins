# Verification Hooks — Live Acceptance Tests

You are testing the verification-hooks plugin in a live Claude Code session.
This plugin enforces independent verification at task boundaries via hooks.

## Prerequisites

Before starting, confirm the plugin is loaded:
1. Check that `verification-hooks@kyle-plugins` appears in your available skills (look for "verification" in the skill list)
2. Run: `cat ~/.claude/settings.json | python3 -c "import json,sys; s=json.load(sys.stdin); print('enabled:', s['enabledPlugins'].get('verification-hooks@kyle-plugins', 'NOT FOUND'))"`

If not loaded, stop and report. The remaining tests are meaningless without the plugin active.

## Test AC3: TaskCompleted Agent Hook Fires

**Goal:** When a subagent completes a task, the TaskCompleted Sonnet verification agent should fire automatically.

1. Create a small test file:
   ```
   Write a file /tmp/test-ac3.py with: print("hello from AC3")
   ```
2. Spawn a subagent (Agent tool) with this prompt: "Write a file /tmp/test-ac3-agent.txt containing 'agent was here'. Then report done."
3. When the agent completes, **watch for the TaskCompleted hook firing** — you should see a verification agent spawn and check the work.
4. Check the log: `tail -5 ~/.local/log/verification-hooks.jsonl | python3 -c "import sys,json; [print(json.dumps(json.loads(l), indent=2)) for l in sys.stdin if 'task_complete' in l.lower() or 'TaskCompleted' in l]"`

**Pass criteria:** The TaskCompleted hook fires and logs an event. The Sonnet verification agent checks the work.
**Record result:** `bd update kyle-dev-infra-ynj --notes="VERIFIED: <timestamp> | TaskCompleted hook fired, evidence: <what you saw>"`
Then: `bd close kyle-dev-infra-ynj --reason="<summary>"`

## Test AC4: Stop Hook Blocks on Uncommitted Changes

**Goal:** When Claude stops after making code changes in a git repo, the Stop hook should fire and verify the work.

1. Go to a git repo (e.g., `cd ~/projects/claude_plugins`)
2. Create a small test file: Write `/home/orangepi/projects/claude_plugins/verification-hooks/tests/test-stop-gate.txt` with content "stop gate test"
3. After writing that file, **try to stop** (just finish your response naturally)
4. The Stop hook should fire — a Sonnet agent will check git diff and verify the changes
5. Check the log: `jq 'select(.gate == "stop")' ~/.local/log/verification-hooks.jsonl | tail -5`

**Pass criteria:** Stop hook fires, detects the uncommitted file, and either allows or blocks with a reason.
**Record result:** `bd update kyle-dev-infra-uvq --notes="VERIFIED: <timestamp> | Stop hook fired on uncommitted changes, evidence: <what you saw>"`
Then: `bd close kyle-dev-infra-uvq --reason="<summary>"`

## Test AC5: Stop Hook No Infinite Loop

**Goal:** After the Stop hook blocks once and Claude responds, the second Stop should pass through (no infinite loop).

This is tested as part of AC4. If the Stop hook blocks, Claude will respond to fix the issue, and then Stop fires again. The second time should allow through.

**Pass criteria:** Claude doesn't get stuck in an infinite block-respond-block loop. Session continues normally after at most one block.
**Record result:** `bd update kyle-dev-infra-2bd --notes="VERIFIED: <timestamp> | Stop hook blocked once, second pass allowed through, no loop"`
Then: `bd close kyle-dev-infra-2bd --reason="<summary>"`

## Test AC6: Stop Hook Allows When No Changes

**Goal:** When Claude finishes a response without making any code changes, the Stop hook should pass immediately.

1. Ask a simple question that requires NO file edits: "What is 2 + 2?"
2. Claude answers. The Stop hook fires.
3. It should return `ok: true` immediately (checks git diff, finds nothing, passes)
4. Check the log: `jq 'select(.gate == "stop")' ~/.local/log/verification-hooks.jsonl | tail -3`

**Pass criteria:** Stop hook fires and allows through with no delay. Log shows the pass.
**Record result:** `bd update kyle-dev-infra-1eu --notes="VERIFIED: <timestamp> | Stop hook passed immediately with no git changes"`
Then: `bd close kyle-dev-infra-1eu --reason="<summary>"`

## After All Tests

1. Run the analysis: `bash ~/projects/claude_plugins/verification-hooks/scripts/analyze-verification.sh`
2. Clean up test files: `rm -f /tmp/test-ac3.py /tmp/test-ac3-agent.txt ~/projects/claude_plugins/verification-hooks/tests/test-stop-gate.txt`
3. Report which ACs passed and which failed

## Beads Issue IDs

| AC | Issue ID | Description |
|----|----------|-------------|
| AC3 | kyle-dev-infra-ynj | TaskCompleted agent hook fires |
| AC4 | kyle-dev-infra-uvq | Stop hook blocks on uncommitted changes |
| AC5 | kyle-dev-infra-2bd | Stop hook no infinite loop |
| AC6 | kyle-dev-infra-1eu | Stop hook allows when no changes |
