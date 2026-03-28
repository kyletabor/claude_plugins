#!/bin/bash
# Shared JSONL log writer for verification hooks
# Usage: source log-event.sh; log_event '{"gate":"bd_close","action":"blocked",...}' "$RAW_STDIN"
# Handles: file creation, atomic writes, rotation, session_id extraction

# Persistent data location — dedicated directory for all verification hooks data
# Included in backups at ~/.local/share/verification-hooks/
VERIFICATION_DATA_DIR="${VERIFICATION_DATA_DIR:-$HOME/.local/share/verification-hooks}"
VERIFICATION_LOG="${VERIFICATION_LOG:-$VERIFICATION_DATA_DIR/events.jsonl}"

# Extract session_id from hook stdin JSON (passed as second arg)
# Falls back to env var, then "unknown"
_extract_session_id() {
  local stdin_json="$1"
  local sid=""

  # Primary: read from hook stdin JSON (documented in Claude Code hook contract)
  if [ -n "$stdin_json" ]; then
    sid=$(echo "$stdin_json" | jq -r '.session_id // empty' 2>/dev/null)
  fi

  # Fallback: env var (in case Claude Code adds it in future)
  if [ -z "$sid" ]; then
    sid="${CLAUDE_SESSION_ID:-}"
  fi

  # Final fallback
  echo "${sid:-unknown}"
}

log_event() {
  local json="$1"
  local stdin_json="${2:-}"
  local ts
  ts=$(date -Iseconds)
  local session_id
  session_id=$(_extract_session_id "$stdin_json")

  # Ensure data directory exists
  mkdir -p "$VERIFICATION_DATA_DIR"

  # Set up backward-compatible symlink from old log path
  local old_log_dir="$HOME/.local/log"
  local old_log_path="$old_log_dir/verification-hooks.jsonl"
  if [ ! -L "$old_log_path" ] && [ -d "$old_log_dir" ]; then
    # Migrate existing data if present
    if [ -f "$old_log_path" ]; then
      mv "$old_log_path" "$VERIFICATION_LOG" 2>/dev/null || true
    fi
    ln -sf "$VERIFICATION_LOG" "$old_log_path" 2>/dev/null || true
  elif [ ! -e "$old_log_path" ] && [ -d "$old_log_dir" ]; then
    ln -sf "$VERIFICATION_LOG" "$old_log_path" 2>/dev/null || true
  fi

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
    local archive="$VERIFICATION_DATA_DIR/events-$(date +%Y%m%d).jsonl"
    cp "$VERIFICATION_LOG" "$archive"
    tail -5000 "$VERIFICATION_LOG" > "${VERIFICATION_LOG}.tmp"
    mv "${VERIFICATION_LOG}.tmp" "$VERIFICATION_LOG"
  fi
}
