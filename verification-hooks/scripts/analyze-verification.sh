#!/bin/bash
# Verification Hooks — monitoring and analysis report
# Usage: bash analyze-verification.sh [path-to-log]

LOG="${1:-$HOME/.local/log/verification-hooks.jsonl}"

if [ ! -f "$LOG" ]; then
  echo "No verification log found at $LOG"
  echo "The log is created automatically when verification hooks first fire."
  exit 0
fi

TOTAL=$(wc -l < "$LOG")
echo "=== Verification Hooks Report ==="
echo "Log: $LOG ($TOTAL events)"
echo ""

echo "--- Gate Activity ---"
jq -sr '
  group_by(.gate) | map(
    "\(.[0].gate): \(length) fires, \([.[] | select(.action == "blocked")] | length) blocked, \([.[] | select(.action == "error")] | length) errors"
  ) | .[]
' "$LOG" 2>/dev/null || echo "(no parseable events)"
echo ""

echo "--- Performance ---"
jq -sr '
  group_by(.gate) | map(
    select(.[0].duration_ms != null) |
    "\(.[0].gate): avg \(([.[].duration_ms // 0] | add) / length | round)ms, max \([.[].duration_ms // 0] | max)ms"
  ) | .[]
' "$LOG" 2>/dev/null || echo "(no timing data)"
echo ""

echo "--- Recent Blocks (last 5) ---"
jq -s '[ .[] | select(.action == "blocked") ] | .[-5:] | .[] | "\(.ts) [\(.gate)] \(.details.reason // "no reason")"' "$LOG" 2>/dev/null || echo "(none)"
echo ""

echo "--- Errors ---"
ERRORS=$(jq -s '[.[] | select(.action == "error")] | length' "$LOG" 2>/dev/null || echo 0)
if [ "$ERRORS" -gt 0 ]; then
  echo "WARNING: $ERRORS hook errors detected!"
  jq 'select(.action == "error") | "\(.ts) [\(.gate)] \(.details.error // "unknown")"' "$LOG" 2>/dev/null
else
  echo "No errors."
fi
echo ""

echo "--- Health Check ---"
echo "| Metric | Value | Healthy Range |"
echo "|--------|-------|---------------|"

BD_TOTAL=$(jq -s '[.[] | select(.gate == "bd_close")] | length' "$LOG" 2>/dev/null || echo 0)
BD_BLOCKED=$(jq -s '[.[] | select(.gate == "bd_close" and .action == "blocked")] | length' "$LOG" 2>/dev/null || echo 0)
if [ "$BD_TOTAL" -gt 0 ]; then
  BD_RATE=$((BD_BLOCKED * 100 / BD_TOTAL))
  echo "| bd_close block rate | ${BD_RATE}% | 10-30% |"
fi

STOP_TOTAL=$(jq -s '[.[] | select(.gate == "stop")] | length' "$LOG" 2>/dev/null || echo 0)
STOP_BLOCKED=$(jq -s '[.[] | select(.gate == "stop" and .action == "blocked")] | length' "$LOG" 2>/dev/null || echo 0)
if [ "$STOP_TOTAL" -gt 0 ]; then
  STOP_RATE=$((STOP_BLOCKED * 100 / STOP_TOTAL))
  echo "| stop block rate | ${STOP_RATE}% | <10% |"
fi

ERROR_TOTAL=$(jq -s '[.[] | select(.action == "error")] | length' "$LOG" 2>/dev/null || echo 0)
echo "| error count | $ERROR_TOTAL | 0 |"
echo "| total events | $TOTAL | 5-20/session |"
