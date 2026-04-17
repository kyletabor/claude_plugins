#!/usr/bin/env bash
# Dispatcher for domain-specific verifiers (registry-based).
#
# Reads $PLUGIN_ROOT/config/verifiers.json (provided by caller via env), discovers
# verifiers whose `label` matches any label on any of the issues being closed, and
# (when the registry is non-empty) invokes their agent files.
#
# DESIGN INVARIANTS — DO NOT VIOLATE:
#   1. Fail-open: any error path exits 0. Never block bd close from this script.
#      The caller (verify-before-close.sh) also wraps invocation with `|| true`.
#   2. No shell-eval of registry-derived strings. Specifically, no field from
#      verifiers.json or from `bd show <id>` output is ever passed through
#      `bash -c`, `eval`, or unquoted command substitution. R3 mitigation.
#   3. agent_path entries must resolve under $HOME/projects/claude_plugins/.
#      Reject anything else (handles symlinks/.. via `realpath -m`).
#   4. Tamper protection: hash registry on first read per session, cache to
#      /tmp/verification-hooks-registry-hash-$session_id. If hash differs on
#      a later read in the same session, log warning and skip dispatch.
#
# Usage:
#   PLUGIN_ROOT=/path/to/plugin bash dispatch-verifiers.sh "<id1> <id2>"
#
# Exit codes:
#   0  — always (fail-open). Status communicated via JSONL log.
#
# When the registry is empty (the V1 ship state), this script logs nothing,
# does nothing, and returns 0 immediately.

set -u
set -o pipefail

# ----- Resolve sourcing -----
# PLUGIN_ROOT must be set by caller. If not, derive from script location.
if [ -z "${PLUGIN_ROOT:-}" ]; then
  PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 2>/dev/null || exit 0
fi

REGISTRY="${PLUGIN_ROOT}/config/verifiers.json"
ID_LIST="${1:-}"

# Bring in log_event (best-effort; if unavailable we'll skip logging)
# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/scripts/log-event.sh" 2>/dev/null || true

_dispatcher_log() {
  # Safe wrapper: if log_event is undefined, no-op.
  if declare -F log_event >/dev/null 2>&1; then
    log_event "$1" "${2:-}" || true
  fi
}

# ----- Empty / unreadable registry: silent no-op -----
[ -f "$REGISTRY" ] || exit 0

# Validate JSON. If malformed, log + fail-open.
if ! jq empty "$REGISTRY" >/dev/null 2>&1; then
  EVENT=$(jq -nc --arg reg "$REGISTRY" \
    '{"gate":"verifier_dispatch","action":"error","details":{"reason":"malformed registry JSON","registry":$reg}}' 2>/dev/null || echo '')
  [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""
  exit 0
fi

# Count verifiers. The `?` keeps jq quiet on empty .verifiers.
VERIFIER_COUNT=$(jq -r '.verifiers | length // 0' "$REGISTRY" 2>/dev/null || echo 0)
# Defensive: jq returning empty / non-numeric
case "$VERIFIER_COUNT" in
  ''|*[!0-9]*) VERIFIER_COUNT=0 ;;
esac

if [ "$VERIFIER_COUNT" -eq 0 ]; then
  # Empty registry. Ship state. No log noise.
  exit 0
fi

# ----- Tamper protection -----
# Hash registry. If we've seen this session before with a different hash, warn + skip.
# Best-effort session id from env (set by caller) or fall back to PPID.
SID="${VERIFICATION_SESSION_ID:-${CLAUDE_SESSION_ID:-pid-$PPID}}"
HASH_CACHE="/tmp/verification-hooks-registry-hash-${SID}"
CURRENT_HASH=$(sha256sum "$REGISTRY" 2>/dev/null | awk '{print $1}')

if [ -n "$CURRENT_HASH" ] && [ -f "$HASH_CACHE" ]; then
  CACHED_HASH=$(cat "$HASH_CACHE" 2>/dev/null || echo "")
  if [ -n "$CACHED_HASH" ] && [ "$CACHED_HASH" != "$CURRENT_HASH" ]; then
    EVENT=$(jq -nc --arg cur "$CURRENT_HASH" --arg cached "$CACHED_HASH" \
      '{"gate":"verifier_dispatch","action":"tamper_warning","details":{"reason":"verifiers.json hash changed mid-session","current_hash":$cur,"cached_hash":$cached}}' 2>/dev/null || echo '')
    [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""
    exit 0
  fi
fi
# Cache hash (best-effort; ignore errors)
[ -n "$CURRENT_HASH" ] && echo "$CURRENT_HASH" > "$HASH_CACHE" 2>/dev/null || true

# ----- Path safety helper -----
# Resolves ${PLUGIN_ROOT} prefix and validates final path is under
# ~/projects/claude_plugins/ (no symlink/.. escape).
_safe_agent_path() {
  local raw="$1"
  # No absolute paths allowed (must be PLUGIN_ROOT-prefixed).
  case "$raw" in
    /*) return 1 ;;
  esac
  # Substitute ${PLUGIN_ROOT}
  local expanded="${raw//\$\{PLUGIN_ROOT\}/$PLUGIN_ROOT}"
  # If still contains $, reject (no other vars allowed)
  case "$expanded" in
    *\$*) return 1 ;;
  esac
  local resolved
  resolved=$(realpath -m "$expanded" 2>/dev/null) || return 1
  case "$resolved" in
    "$HOME/projects/claude_plugins/"*) printf '%s' "$resolved"; return 0 ;;
    *) return 1 ;;
  esac
}

# ----- Iterate verifiers (only reached when registry has entries) -----
# We support label-based dispatch: each verifier declares a `label` and
# `applies_to_gates`. We only dispatch ones whose gate includes "bd_close".
# Everything below is plumbing for the future first verifier.

# Collect labels from all issues being closed.
ALL_LABELS=""
for ID in $ID_LIST; do
  L=$(bd show "$ID" --json 2>/dev/null | jq -r '.[0].labels[]? // empty' 2>/dev/null || true)
  if [ -n "$L" ]; then
    ALL_LABELS="$ALL_LABELS $L"
  fi
done

ANY_FAIL=0

# Iterate verifiers from registry (-c to keep one-per-line, no shell eval of contents)
while IFS= read -r V_JSON; do
  [ -z "$V_JSON" ] && continue

  V_NAME=$(echo "$V_JSON" | jq -r '.name // empty' 2>/dev/null || echo "")
  V_LABEL=$(echo "$V_JSON" | jq -r '.label // empty' 2>/dev/null || echo "")
  V_AGENT=$(echo "$V_JSON" | jq -r '.agent_path // empty' 2>/dev/null || echo "")
  V_GATES=$(echo "$V_JSON" | jq -r '.applies_to_gates[]? // empty' 2>/dev/null || echo "")

  # Sanity: required fields
  if [ -z "$V_NAME" ] || [ -z "$V_LABEL" ] || [ -z "$V_AGENT" ]; then
    EVENT=$(jq -nc --arg name "$V_NAME" \
      '{"gate":"verifier_dispatch","action":"skipped","details":{"reason":"missing required fields","verifier":$name}}' 2>/dev/null || echo '')
    [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""
    continue
  fi

  # Gate filter: must apply to bd_close
  if ! echo "$V_GATES" | grep -qx "bd_close"; then
    continue
  fi

  # Label filter: only fire if any issue has the verifier's label
  if ! echo "$ALL_LABELS" | tr ' ' '\n' | grep -qFx "$V_LABEL"; then
    continue
  fi

  # Path safety: validate agent_path BEFORE any invocation
  AGENT_RESOLVED=""
  if AGENT_RESOLVED=$(_safe_agent_path "$V_AGENT"); then
    :
  else
    EVENT=$(jq -nc --arg name "$V_NAME" --arg path "$V_AGENT" \
      '{"gate":"verifier_dispatch","action":"rejected","details":{"reason":"unsafe agent_path","verifier":$name,"agent_path":$path}}' 2>/dev/null || echo '')
    [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""
    ANY_FAIL=1
    continue
  fi

  if [ ! -f "$AGENT_RESOLVED" ]; then
    EVENT=$(jq -nc --arg name "$V_NAME" --arg path "$AGENT_RESOLVED" \
      '{"gate":"verifier_dispatch","action":"skipped","details":{"reason":"agent file not found","verifier":$name,"agent_path":$path}}' 2>/dev/null || echo '')
    [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""
    continue
  fi

  # Read-only enforcement: reject agents that declare Edit/Write/Bash mutation.
  # We require the agent frontmatter to declare allowed-tools without Edit/Write.
  if grep -qE '^allowed-tools:.*\b(Edit|Write|MultiEdit)\b' "$AGENT_RESOLVED" 2>/dev/null; then
    EVENT=$(jq -nc --arg name "$V_NAME" --arg path "$AGENT_RESOLVED" \
      '{"gate":"verifier_dispatch","action":"rejected","details":{"reason":"agent not read-only","verifier":$name,"agent_path":$path}}' 2>/dev/null || echo '')
    [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""
    ANY_FAIL=1
    continue
  fi

  # ----- Invocation placeholder -----
  # Domain verifier invocation is intentionally NOT IMPLEMENTED in V1.
  # The registry ships empty; this branch is unreachable until the first verifier
  # is added with its own bead. Whoever adds the first verifier owns wiring the
  # actual Agent-tool dispatch (which must NOT be a `bash -c` of any registry-
  # or notes-derived string — see R3 in the pre-mortem).
  #
  # For now, log that we WOULD dispatch and treat as pass.
  EVENT=$(jq -nc --arg name "$V_NAME" --arg path "$AGENT_RESOLVED" --arg ids "$ID_LIST" \
    '{"gate":"verifier_dispatch","action":"would_dispatch","details":{"verifier":$name,"agent_path":$path,"issue_ids":$ids,"note":"V1 plumbing only — invocation deferred to first real verifier bead"}}' 2>/dev/null || echo '')
  [ -n "$EVENT" ] && _dispatcher_log "$EVENT" ""

done < <(jq -c '.verifiers[]?' "$REGISTRY" 2>/dev/null || true)

# Aggregate. Even on ANY_FAIL we exit 0 (fail-open). The would-be block path
# is the responsibility of the first verifier's wiring agent to implement
# alongside the actual invocation logic.
exit 0
