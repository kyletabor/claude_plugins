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
    log_event "{\"gate\":\"logger\",\"action\":\"logged\",\"details\":{\"tool\":\"$TOOL_NAME\",\"command_prefix\":\"$(echo "$COMMAND" | head -c 100)\"}}"
    ;;
  Edit|Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
    log_event "{\"gate\":\"logger\",\"action\":\"logged\",\"details\":{\"tool\":\"$TOOL_NAME\",\"file\":\"$FILE_PATH\"}}"
    ;;
  *)
    # Unknown tool — skip
    exit 0
    ;;
esac

exit 0
