#!/bin/bash
# PostToolUse logger — records tool use events for monitoring
# Non-blocking: always exits 0, never interferes with workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/log-event.sh" 2>/dev/null || true

INPUT=$(cat 2>/dev/null || true)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)

# Only log significant tool uses (writes/edits/bash that modify things)
case "$TOOL_NAME" in
  Bash)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
    # Skip read-only commands
    if echo "$COMMAND" | grep -qE "^(ls|cat|head|tail|grep|find|git (log|status|diff|show|branch)|pwd|echo|which|type|bd (show|list|ready|search|stats))"; then
      exit 0
    fi
    # Use jq to build valid JSON (handles quotes in commands)
    EVENT=$(jq -nc --arg tool "$TOOL_NAME" --arg cmd "$(echo "$COMMAND" | head -c 100)" \
      '{"gate":"logger","action":"logged","details":{"tool":$tool,"command_prefix":$cmd}}')
    log_event "$EVENT" "$INPUT"
    ;;
  Edit|Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
    EVENT=$(jq -nc --arg tool "$TOOL_NAME" --arg file "$FILE_PATH" \
      '{"gate":"logger","action":"logged","details":{"tool":$tool,"file":$file}}')
    log_event "$EVENT" "$INPUT"
    ;;
  *)
    # Unknown tool — skip
    exit 0
    ;;
esac

exit 0
