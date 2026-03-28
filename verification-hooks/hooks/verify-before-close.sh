#!/bin/bash
# Verification gate for bd close commands
# PreToolUse hook on Bash — exits instantly for non-matching commands
# Exit 0 = allow, Exit 2 = block
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/log-event.sh" 2>/dev/null || true

# Read stdin once, store for session_id extraction and command parsing
INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# No command to check — allow through
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Fail-open: if the hook itself errors, allow through and log
trap 'log_event "{\"gate\":\"bd_close\",\"action\":\"error\",\"details\":{\"error\":\"hook script failed\",\"fallback\":\"allowed\"}}" "$INPUT"; exit 0' ERR

# ========================================
# Smart command matching (R2)
# Only match actual "bd close <issue-ids>" commands,
# not "bd close" appearing in strings, git commits, help, etc.
# ========================================

# Extract the actual command being run, handling chained commands (&&, ;, |)
# We check each segment for "bd close" as a command verb
BD_CLOSE_SEGMENT=""

# Split on && and ; to find individual commands, check each
# Use a simple approach: check if any command segment starts with "bd close" (possibly with leading whitespace)
while IFS= read -r segment; do
  # Trim leading whitespace
  trimmed=$(echo "$segment" | sed 's/^[[:space:]]*//')
  # Check if this segment starts with "bd close" followed by space or end-of-string
  if [[ "$trimmed" =~ ^bd[[:space:]]+close([[:space:]]|$) ]]; then
    BD_CLOSE_SEGMENT="$trimmed"
    break
  fi
done < <(echo "$COMMAND" | tr ';&' '\n' | sed 's/|.*//')
# Note: pipes are handled by stripping everything after | in each segment
# This prevents matching "echo 'bd close'" or "git commit -m 'bd close ...'"

if [ -z "$BD_CLOSE_SEGMENT" ]; then
  # Not a bd close command — allow through immediately
  exit 0
fi

# Extract arguments after "bd close"
ARGS_STRING=$(echo "$BD_CLOSE_SEGMENT" | sed 's/^bd[[:space:]]*close[[:space:]]*//')

# Extract --reason value FIRST (before word-splitting destroys quoted strings)
# Handles: --reason "multi word", --reason 'multi word', --reason=value, -r "value"
CLOSE_REASON=""
if echo "$ARGS_STRING" | grep -qE '(--reason|^-r |-r )'; then
  # Extract quoted reason: --reason "..." or --reason '...'
  CLOSE_REASON=$(echo "$ARGS_STRING" | sed -n 's/.*--reason[= ]*"\([^"]*\)".*/\1/p')
  if [ -z "$CLOSE_REASON" ]; then
    CLOSE_REASON=$(echo "$ARGS_STRING" | sed -n "s/.*--reason[= ]*'\([^']*\)'.*/\1/p")
  fi
  # Unquoted single-word reason: --reason value
  if [ -z "$CLOSE_REASON" ]; then
    CLOSE_REASON=$(echo "$ARGS_STRING" | sed -n 's/.*--reason[= ]*\([^ ]*\).*/\1/p')
  fi
  # -r shorthand
  if [ -z "$CLOSE_REASON" ]; then
    CLOSE_REASON=$(echo "$ARGS_STRING" | sed -n 's/.*-r *"\([^"]*\)".*/\1/p')
  fi
  if [ -z "$CLOSE_REASON" ]; then
    CLOSE_REASON=$(echo "$ARGS_STRING" | sed -n 's/.*-r *\([^ ]*\).*/\1/p')
  fi
fi

# Parse arguments: separate flags from issue IDs
# Strip --reason and its value, --session and its value, shell redirections
CLEAN_ARGS=$(echo "$ARGS_STRING" | \
  sed 's/--reason[= ]*"[^"]*"//g' | \
  sed "s/--reason[= ]*'[^']*'//g" | \
  sed 's/--reason[= ]*[^ ]*//g' | \
  sed 's/-r *"[^"]*"//g' | \
  sed 's/-r *[^ ]*//g' | \
  sed 's/--session[= ]*[^ ]*//g' | \
  sed 's/[0-9]*>&[0-9]*//g')

ISSUE_IDS=""
for arg in $CLEAN_ARGS; do
  case "$arg" in
    --help|-h)
      exit 0
      ;;
    --force|-f|--continue|--claim-next|--suggest-next|--*)
      # Known flags — skip
      ;;
    -*)
      # Short flags — skip
      ;;
    *)
      # Potential issue ID: must contain at least one hyphen
      if echo "$arg" | grep -q '-'; then
        ISSUE_IDS="$ISSUE_IDS $arg"
      fi
      ;;
  esac
done

# Trim leading space
ISSUE_IDS=$(echo "$ISSUE_IDS" | sed 's/^[[:space:]]*//')

if [ -z "$ISSUE_IDS" ]; then
  # No valid issue IDs found — allow through (fail-open)
  EVENT=$(jq -nc --arg cmd "$COMMAND" '{"gate":"bd_close","action":"skipped","details":{"reason":"no issue IDs parsed","command":$cmd}}')
  log_event "$EVENT" "$INPUT"
  exit 0
fi

# ========================================
# Gate 1: bd close verification
# ========================================

START_MS=$(($(date +%s%N) / 1000000))

UNVERIFIED=""
DUPLICATE_IDS=""

for ID in $ISSUE_IDS; do
  # Single bd show call (text format for VERIFIED check + JSON for duplicate check)
  SHOW_OUTPUT=$(bd show "$ID" 2>/dev/null || true)

  # ========================================
  # R3: Check for duplicate exception
  # Uses JSON output to check for "duplicates" dependency type
  # ========================================
  JSON_OUTPUT=$(bd show "$ID" --json 2>/dev/null || true)
  if echo "$JSON_OUTPUT" | jq -e '.[0].dependencies[]? | select(.dependency_type == "duplicates")' >/dev/null 2>&1; then
    DUPLICATE_IDS="$DUPLICATE_IDS $ID"
    continue
  fi

  # Check if issue has a VERIFIED: note
  NOTES=$(echo "$SHOW_OUTPUT" | grep "VERIFIED:" | tail -1 || true)
  if [ -z "$NOTES" ]; then
    UNVERIFIED="$UNVERIFIED $ID"
  fi
done

END_MS=$(($(date +%s%N) / 1000000))
DURATION_MS=$((END_MS - START_MS))

# Log duplicate exceptions (R3 + R6)
for DID in $DUPLICATE_IDS; do
  EVENT=$(jq -nc --arg id "$DID" --arg cmd "$COMMAND" --argjson dur "$DURATION_MS" \
    '{"gate":"bd_close","action":"exception_allowed","duration_ms":$dur,"details":{"reason":"duplicate_close","issue_ids":$id,"command":$cmd}}')
  log_event "$EVENT" "$INPUT"
done

if [ -z "$UNVERIFIED" ]; then
  # All verified (or all duplicates) — log and allow
  EVENT=$(jq -nc --arg ids "$(echo $ISSUE_IDS | tr ' ' ',')" --arg cmd "$COMMAND" --argjson dur "$DURATION_MS" \
    '{"gate":"bd_close","action":"allowed","duration_ms":$dur,"details":{"issue_ids":$ids,"command":$cmd}}')
  log_event "$EVENT" "$INPUT"
  exit 0
fi

# ========================================
# R4: Circuit breaker — check block count for this session+issue
# ========================================
SESSION_ID=$(_extract_session_id "$INPUT")
BREAKER_THRESHOLD=3
BREAKER_ACTIVE=false

for UVID in $UNVERIFIED; do
  BLOCK_COUNT=0
  if [ "$SESSION_ID" != "unknown" ] && [ -f "$VERIFICATION_LOG" ]; then
    # Use chained grep for robustness — field order varies, log may have malformed lines
    BLOCK_COUNT=$(grep "$SESSION_ID" "$VERIFICATION_LOG" 2>/dev/null \
      | grep '"gate":"bd_close"' \
      | grep '"action":"blocked"' \
      | grep -c "$UVID" || echo 0)
  fi

  if [ "$BLOCK_COUNT" -ge "$BREAKER_THRESHOLD" ] 2>/dev/null; then
    BREAKER_ACTIVE=true

    # Circuit breaker triggered — check if agent provided a reason
    if [ -n "$CLOSE_REASON" ]; then
      # Agent provided reason — allow through as exception
      EVENT=$(jq -nc \
        --arg id "$UVID" \
        --arg cmd "$COMMAND" \
        --arg reason "$CLOSE_REASON" \
        --argjson count "$BLOCK_COUNT" \
        --argjson dur "$DURATION_MS" \
        '{"gate":"bd_close","action":"exception_allowed","duration_ms":$dur,"details":{"reason":"circuit_breaker","issue_ids":$id,"agent_reason":$reason,"block_count":$count,"command":$cmd}}')
      log_event "$EVENT" "$INPUT"
      # Remove this ID from unverified list
      UNVERIFIED=$(echo "$UNVERIFIED" | sed "s/$UVID//g" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    fi
  fi
done

# Re-check: if all unverified were resolved by circuit breaker or duplicates
UNVERIFIED=$(echo "$UNVERIFIED" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
if [ -z "$UNVERIFIED" ]; then
  exit 0
fi

# Block — require verification first
EVENT=$(jq -nc --arg ids "$(echo $UNVERIFIED | tr ' ' ',')" --arg cmd "$COMMAND" --argjson dur "$DURATION_MS" \
  '{"gate":"bd_close","action":"blocked","duration_ms":$dur,"details":{"issue_ids":$ids,"reason":"no VERIFIED note","command":$cmd}}')
log_event "$EVENT" "$INPUT"

if $BREAKER_ACTIVE; then
  # Circuit breaker message — agent has been blocked too many times
  cat >&2 <<EOF
CIRCUIT BREAKER: Issue(s)$UNVERIFIED blocked $BREAKER_THRESHOLD+ times this session.

To override, re-run with a reason explaining why verification should be skipped:
  bd close$UNVERIFIED --reason "your explanation here"

The reason will be logged as an escalated exception for process review.
If you believe the verification gate is wrong, file a bug.
EOF
  exit 2
fi

cat >&2 <<EOF
VERIFICATION REQUIRED before closing issue(s):$UNVERIFIED

You MUST spawn an independent verification agent before closing. Use the Agent tool with this prompt:

"You are an independent verification agent. Your job is to check if the work actually meets the acceptance criteria.

For each issue ID ($UNVERIFIED):
1. Run: bd show <id> — read the acceptance criteria and description
2. Run: git diff --stat — see what files changed
3. For each acceptance criterion:
   - Check the actual code/state to verify it was met
   - Run relevant tests if applicable
   - Note PASS or FAIL with specific evidence
4. If ALL criteria pass, mark it verified:
   bd update <id> --notes='VERIFIED: $(date -Iseconds) | <N>/<N> criteria passed | evidence: <summary>'
5. If ANY criterion fails, report which ones and why — do NOT mark as verified.

You have full tool access. Read files, run commands, check state. Be thorough but fast."

After the verification agent completes, retry: bd close$UNVERIFIED
EOF
exit 2
