#!/bin/bash
# Shared JSONL log writer for verification hooks
# Usage: source log-event.sh; log_event '{"gate":"bd_close","action":"blocked",...}'
# Handles: file creation, atomic writes, rotation

VERIFICATION_LOG="${VERIFICATION_LOG:-$HOME/.local/log/verification-hooks.jsonl}"

log_event() {
  local json="$1"
  local ts
  ts=$(date -Iseconds)
  local session_id="${CLAUDE_SESSION_ID:-unknown}"

  # Ensure directory exists
  mkdir -p "$(dirname "$VERIFICATION_LOG")"

  # Add ts and session_id if not already present
  local full_event
  full_event=$(echo "$json" | jq -c \
    --arg ts "$ts" \
    --arg sid "$session_id" \
    '. + {ts: (.ts // $ts), session_id: (.session_id // $sid)}' 2>/dev/null)

  # Fallback if jq fails
  if [ -z "$full_event" ]; then
    full_event="{\"ts\":\"$ts\",\"session_id\":\"$session_id\",\"raw\":$(echo "$json" | jq -c '.' 2>/dev/null || echo "\"$json\"")}"
  fi

  # Atomic append (>> is atomic for lines < PIPE_BUF on Linux)
  echo "$full_event" >> "$VERIFICATION_LOG"

  # Rotate if over 10K lines (keep last 5K)
  local lines
  lines=$(wc -l < "$VERIFICATION_LOG" 2>/dev/null || echo 0)
  if [ "$lines" -gt 10000 ]; then
    local archive="${VERIFICATION_LOG%.jsonl}-$(date +%Y%m%d).jsonl"
    cp "$VERIFICATION_LOG" "$archive"
    tail -5000 "$VERIFICATION_LOG" > "${VERIFICATION_LOG}.tmp"
    mv "${VERIFICATION_LOG}.tmp" "$VERIFICATION_LOG"
  fi
}
