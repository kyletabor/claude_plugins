#!/bin/bash
# Verification gate for bd close commands and infrastructure operations
# PreToolUse hook on Bash — exits instantly for non-matching commands
# Exit 0 = allow, Exit 2 = block
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/log-event.sh" 2>/dev/null || true

# Fail-open: if the hook itself errors, allow through and log
trap 'log_event "{\"gate\":\"pretooluse\",\"action\":\"error\",\"details\":{\"error\":\"hook script failed\",\"fallback\":\"allowed\"}}"; exit 0' ERR

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# No command to check — allow through
if [ -z "$COMMAND" ]; then
  exit 0
fi

# ========================================
# Gate 1: bd close verification
# ========================================
if echo "$COMMAND" | grep -q "bd close"; then
  START_MS=$(($(date +%s%N) / 1000000))

  # Extract issue IDs (bd close supports multiple IDs)
  # IDs contain hyphens (e.g., kyle-dev-infra-pm7), so extract all non-flag words after "bd close"
  ISSUE_IDS=$(echo "$COMMAND" | sed 's/.*bd close//' | tr -s ' ' '\n' | grep -v '^--' | grep -v '^$' | grep '-' || true)

  if [ -z "$ISSUE_IDS" ]; then
    # Can't parse IDs — allow through (fail-open)
    EVENT=$(jq -nc --arg cmd "$COMMAND" '{"gate":"bd_close","action":"skipped","details":{"reason":"no issue IDs parsed","command":$cmd}}')
    log_event "$EVENT"
    exit 0
  fi

  UNVERIFIED=""
  for ID in $ISSUE_IDS; do
    # Check if issue has a VERIFIED: note
    NOTES=$(bd show "$ID" 2>/dev/null | grep "VERIFIED:" | tail -1 || true)
    if [ -z "$NOTES" ]; then
      UNVERIFIED="$UNVERIFIED $ID"
    fi
  done

  END_MS=$(($(date +%s%N) / 1000000))
  DURATION_MS=$((END_MS - START_MS))

  if [ -z "$UNVERIFIED" ]; then
    # All verified — log and allow
    EVENT=$(jq -nc --arg ids "$(echo $ISSUE_IDS | tr ' ' ',')" --arg cmd "$COMMAND" --argjson dur "$DURATION_MS" \
      '{"gate":"bd_close","action":"allowed","duration_ms":$dur,"details":{"issue_ids":$ids,"command":$cmd}}')
    log_event "$EVENT"
    exit 0
  fi

  # Block — require verification first
  EVENT=$(jq -nc --arg ids "$(echo $UNVERIFIED | tr ' ' ',')" --arg cmd "$COMMAND" --argjson dur "$DURATION_MS" \
    '{"gate":"bd_close","action":"blocked","duration_ms":$dur,"details":{"issue_ids":$ids,"reason":"no VERIFIED note","command":$cmd}}')
  log_event "$EVENT"

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
fi

# ========================================
# Gate 2: Infrastructure gates
# ========================================

# Docker build gate — log but don't block
if echo "$COMMAND" | grep -qE "docker (build|compose.*(up|build))"; then
  EVENT=$(jq -nc --arg cmd "$COMMAND" '{"gate":"infra","action":"allowed","details":{"trigger":"docker_build","command":$cmd}}')
  log_event "$EVENT"
  exit 0
fi

# Batch operation gate — require single-item test first
if echo "$COMMAND" | grep -qE "(qmd embed|migrate|import).*--all|npx qmd embed"; then
  if [ ! -f /tmp/single-item-test-passed ]; then
    EVENT=$(jq -nc --arg cmd "$COMMAND" '{"gate":"infra","action":"blocked","details":{"trigger":"batch_operation","command":$cmd,"single_item_test":false,"reason":"single-item test required first"}}')
    log_event "$EVENT"
    echo "BATCH OPERATION DETECTED. Before processing all items, test with one first." >&2
    echo "Run the same command on a single item, verify it works, then: touch /tmp/single-item-test-passed" >&2
    exit 2
  fi
  rm -f /tmp/single-item-test-passed
  EVENT=$(jq -nc --arg cmd "$COMMAND" '{"gate":"infra","action":"allowed","details":{"trigger":"batch_operation","command":$cmd,"single_item_test":true}}')
  log_event "$EVENT"
fi

# Not a gated command — allow through immediately
exit 0
