#!/usr/bin/env bash
# Handoff plugin - SessionStart hook
# Scans for pending handoff files and notifies the new session

HANDOFF_DIR="/mnt/pi-data/claude-workspace/handoffs"

# Ensure directory exists
mkdir -p "$HANDOFF_DIR/archive" 2>/dev/null

# Count active handoff files (not in archive/)
PENDING=$(find "$HANDOFF_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null)

if [ -n "$PENDING" ]; then
  COUNT=$(echo "$PENDING" | wc -l)
  echo "=== HANDOFF CONTEXT AVAILABLE (${COUNT} pending) ==="
  while IFS= read -r f; do
    BASENAME=$(basename "$f")
    AGE=$(( ($(date +%s) - $(stat -c %Y "$f")) / 3600 ))
    echo "  - ${BASENAME} (${AGE}h ago)"
  done <<< "$PENDING"
  echo "Run /handoff-resume to load, or /handoff-clear to archive."
  echo "=== END HANDOFF NOTICE ==="
fi
