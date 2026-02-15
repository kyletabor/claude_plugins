#!/usr/bin/env bash
# Handoff plugin - SessionStart hook
# Checks for saved handoff context and injects it into the new session

HANDOFF_FILE="$HOME/.claude/handoff-context.md"

if [ -f "$HANDOFF_FILE" ]; then
  AGE=$(( ($(date +%s) - $(stat -c %Y "$HANDOFF_FILE")) / 3600 ))
  echo "=== HANDOFF CONTEXT AVAILABLE (saved ${AGE}h ago) ==="
  echo "A previous session saved context for you. Run /handoff-resume or say 'pick up where we left off' to load it."
  echo "Run /handoff-clear to dismiss."
  echo "=== END HANDOFF NOTICE ==="
fi
