#!/usr/bin/env bash
# Handoff plugin - SessionStart hook
# Checks for saved handoff context and injects it into the new session

HANDOFF_FILE="$HOME/.claude/handoff-context.md"

if [ -f "$HANDOFF_FILE" ]; then
  cat "$HANDOFF_FILE"
  rm -f "$HANDOFF_FILE"
fi
