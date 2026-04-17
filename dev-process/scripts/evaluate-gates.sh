#!/usr/bin/env bash
# evaluate-gates.sh — Verification Suite evaluator
#
# Reads verification-gates.json and emits applicable gate IDs given spec or bead context.
# Fail-open: any internal error exits 0 with a logged event. Never crashes a caller.
#
# Consumers:
#   - dev-process SKILL.md Phase 1 Step 5 (spawn GATE beads per applicable gate)
#   - dev-process SKILL.md Phase 2 reviewer (reject spec if applicable gate missing)
#   - verification-hooks verify-before-close.sh (block close if applicable gate lacks evidence)
#
# Modes:
#   --list                          List all enabled gates (id + title)
#   --for-spec <path>               Emit applicable gate IDs for a spec file
#   --for-close <bead-id>           Emit applicable gate IDs for a closing bead (uses bd show + git diff)
#   --check-evidence <bead-id> <gate-id>
#                                   Exit 0 if a closed GATE bead exists in the project with the
#                                   gate's evidence_marker in its notes; exit 2 if not
#   --emit-create <gate-id>         Print a ready-to-run `bd create` command for this gate
#
# Exit codes:
#   0  — success (or fail-open on error)
#   2  — only for --check-evidence when evidence missing

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${EVAL_GATES_REGISTRY:-$SCRIPT_DIR/../config/verification-gates.json}"
SCHEMA_VERSION_EXPECTED=1
LOG_FILE="${EVAL_GATES_LOG:-$HOME/.local/share/verification-hooks/events.jsonl}"

_log_event() {
  local event_json="$1"
  [ -z "$event_json" ] && return 0
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  local ts
  ts=$(date -Iseconds 2>/dev/null || date)
  printf '%s\n' "$(jq -nc --arg ts "$ts" --argjson ev "$event_json" '$ev + {timestamp: $ts, source: "evaluate-gates.sh"}' 2>/dev/null || echo "$event_json")" >> "$LOG_FILE" 2>/dev/null || true
}

_die_fail_open() {
  local reason="$1"
  _log_event "$(jq -nc --arg r "$reason" '{"gate":"evaluator","action":"error","details":{"reason":$r}}' 2>/dev/null || echo '')"
  exit 0
}

# ---------- Registry load + schema check ----------
_load_registry() {
  [ -f "$REGISTRY" ] || _die_fail_open "registry file not found: $REGISTRY"
  jq empty "$REGISTRY" 2>/dev/null || _die_fail_open "malformed registry JSON"
  local sv
  sv=$(jq -r '.schema_version // 0' "$REGISTRY" 2>/dev/null)
  if [ "$sv" != "$SCHEMA_VERSION_EXPECTED" ]; then
    _log_event "$(jq -nc --arg got "$sv" --arg exp "$SCHEMA_VERSION_EXPECTED" '{"gate":"evaluator","action":"schema_mismatch","details":{"got":$got,"expected":$exp}}' 2>/dev/null || echo '')"
    _die_fail_open "schema_version mismatch (got=$sv, expected=$SCHEMA_VERSION_EXPECTED)"
  fi
}

_enabled_gates_json() {
  jq -c '.gates[] | select(.enabled == true)' "$REGISTRY" 2>/dev/null
}

# ---------- Trigger evaluators ----------
# Each returns 0 if the gate APPLIES to the given context, 1 if not.

_trigger_always() {
  return 0
}

# $1 = spec file path
# $2 = trigger JSON (contains .section, .require_rows)
_trigger_spec_section_present() {
  local spec="$1"
  local trigger="$2"
  [ -f "$spec" ] || return 1
  local section require_rows
  section=$(echo "$trigger" | jq -r '.section // empty')
  require_rows=$(echo "$trigger" | jq -r '.require_rows // false')
  [ -z "$section" ] && return 1

  # Find "## <section>" line; collect lines after until next "## " header
  local content
  content=$(awk -v sec="## $section" '
    $0 == sec {found=1; next}
    found && /^## / {exit}
    found {print}
  ' "$spec" 2>/dev/null)

  [ -z "$content" ] && return 1

  if [ "$require_rows" = "true" ]; then
    # Accept table data rows OR bulleted list items as "rows".
    # Reject: header rows ("| Dependency"), separator rows ("|---|..."), empty lines.
    local data_rows
    data_rows=$(echo "$content" \
      | grep -E '^\|' \
      | grep -vE '^\|[- :|]+\|$' \
      | grep -vE '^\| *Dependency ' \
      | wc -l | tr -d ' ')
    local bullet_rows
    bullet_rows=$(echo "$content" | grep -cE '^[-*]|^[0-9]+\.' | tr -d ' ')
    # Normalize to plain integers (grep -c may print "0" when no match)
    data_rows=${data_rows:-0}
    bullet_rows=${bullet_rows:-0}
    if [ "$data_rows" -gt 0 ] 2>/dev/null || [ "$bullet_rows" -gt 0 ] 2>/dev/null; then
      return 0
    fi
    return 1
  fi
  return 0
}

# $1 = spec file path (may be "")
# $2 = trigger JSON (contains .match[], .also_check_git_diff)
# $3 = optional git diff string (lines from git diff --name-only)
_trigger_paths_touched() {
  local spec="$1"
  local trigger="$2"
  local git_diff="$3"
  local match_json also_check
  match_json=$(echo "$trigger" | jq -c '.match // []')
  also_check=$(echo "$trigger" | jq -r '.also_check_git_diff // false')

  local matched=1

  # Source 1: spec's "Files to Modify/Create" section and "Files to Modify" section
  if [ -n "$spec" ] && [ -f "$spec" ]; then
    local spec_paths
    spec_paths=$(awk '
      /^## Files to Modify/ {found=1; next}
      found && /^## / {exit}
      found {print}
    ' "$spec" 2>/dev/null)

    # Also scan entire spec body for path-like tokens (cautious: any text match counts)
    local spec_body
    spec_body=$(cat "$spec" 2>/dev/null)

    while IFS= read -r prefix; do
      [ -z "$prefix" ] && continue
      # Expand ~ for matching purposes
      local expanded="${prefix/#\~/$HOME}"
      if echo "$spec_paths" | grep -qF "$prefix" 2>/dev/null || \
         echo "$spec_paths" | grep -qF "$expanded" 2>/dev/null || \
         echo "$spec_body" | grep -qF "$prefix" 2>/dev/null || \
         echo "$spec_body" | grep -qF "$expanded" 2>/dev/null; then
        matched=0
        break
      fi
    done < <(echo "$match_json" | jq -r '.[]?')
  fi

  # Source 2: git diff (at close time)
  if [ "$matched" -eq 1 ] && [ "$also_check" = "true" ] && [ -n "$git_diff" ]; then
    while IFS= read -r prefix; do
      [ -z "$prefix" ] && continue
      local expanded="${prefix/#\~/$HOME}"
      if echo "$git_diff" | grep -qF "$prefix" 2>/dev/null || \
         echo "$git_diff" | grep -qF "$expanded" 2>/dev/null; then
        matched=0
        break
      fi
    done < <(echo "$match_json" | jq -r '.[]?')
  fi

  return $matched
}

# $1 = bead ID
# $2 = trigger JSON (contains .issue_types[])
_trigger_bead_type() {
  local bead_id="$1"
  local trigger="$2"
  [ -z "$bead_id" ] && return 1
  local types_json
  types_json=$(echo "$trigger" | jq -c '.issue_types // []')
  local bead_type
  bead_type=$(bd show "$bead_id" --json 2>/dev/null | jq -r '.[0].issue_type // empty' 2>/dev/null)
  [ -z "$bead_type" ] && return 1

  if echo "$types_json" | jq -e --arg t "$bead_type" '.[] | select(. == $t)' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Returns applicable gate IDs for a given spec file (spec-time evaluation).
_applicable_for_spec() {
  local spec="$1"
  _load_registry
  local gate_json trigger_type trigger_body gate_id
  while IFS= read -r gate_json; do
    [ -z "$gate_json" ] && continue
    gate_id=$(echo "$gate_json" | jq -r '.id')
    trigger_body=$(echo "$gate_json" | jq -c '.trigger')
    trigger_type=$(echo "$trigger_body" | jq -r '.type // "always"')
    case "$trigger_type" in
      always)
        echo "$gate_id"
        ;;
      spec_section_present)
        _trigger_spec_section_present "$spec" "$trigger_body" && echo "$gate_id"
        ;;
      paths_touched)
        _trigger_paths_touched "$spec" "$trigger_body" "" && echo "$gate_id"
        ;;
      bead_type)
        # Only resolvable at close time; skip at spec time.
        ;;
      *)
        _log_event "$(jq -nc --arg t "$trigger_type" --arg g "$gate_id" '{"gate":"evaluator","action":"unknown_trigger","details":{"trigger_type":$t,"gate_id":$g}}' 2>/dev/null || echo '')"
        ;;
    esac
  done < <(_enabled_gates_json)
  return 0
}

# Returns applicable gate IDs for a closing bead (close-time evaluation).
_applicable_for_close() {
  local bead_id="$1"
  _load_registry

  # Exemption: GATE: beads are the enforcement mechanism itself. Requiring gates
  # on their own close creates a chicken-and-egg cycle. They close on VERIFIED
  # evidence only (enforced by Gate 1 in verify-before-close.sh).
  local title
  title=$(bd show "$bead_id" --json 2>/dev/null | jq -r '.[0].title // empty' 2>/dev/null)
  case "$title" in
    "GATE:"*|"GATE :"*) return 0 ;;
  esac

  # Gather git diff across known plugin repos + current working directory.
  # Plugin work lives in ~/projects/claude_plugins/ but `bd close` typically runs
  # from ~/projects/kyle-dev-infra/. Checking both gives us visibility either way.
  # Includes unstaged+staged changes AND untracked files (real work often untracked
  # before a commit). Uses `ls-files --others --exclude-standard` for untracked.
  local git_diff=""
  local repo
  for repo in "$HOME/projects/claude_plugins" "$HOME/projects/kyle-dev-infra" "$PWD"; do
    [ -d "$repo/.git" ] || continue
    local repo_changes
    repo_changes=$(
      {
        git -C "$repo" diff --name-only HEAD 2>/dev/null
        git -C "$repo" diff --cached --name-only 2>/dev/null
        git -C "$repo" ls-files --others --exclude-standard 2>/dev/null \
          | sed "s|^|$repo/|"
      } || true
    )
    # Prefix non-absolute paths with repo root so `paths_touched` prefix matching works
    local prefixed
    prefixed=$(echo "$repo_changes" | awk -v r="$repo" '
      /^[^/]/ && NF { print r "/" $0; next }
      NF { print }
    ')
    git_diff="${git_diff}${prefixed}
"
  done

  local gate_json trigger_type trigger_body gate_id
  while IFS= read -r gate_json; do
    [ -z "$gate_json" ] && continue
    gate_id=$(echo "$gate_json" | jq -r '.id')
    trigger_body=$(echo "$gate_json" | jq -c '.trigger')
    trigger_type=$(echo "$trigger_body" | jq -r '.type // "always"')
    case "$trigger_type" in
      always)
        echo "$gate_id"
        ;;
      spec_section_present)
        # Spec not available at close time; skip. (Could be extended to read a spec path from bead description.)
        ;;
      paths_touched)
        _trigger_paths_touched "" "$trigger_body" "$git_diff" && echo "$gate_id"
        ;;
      bead_type)
        _trigger_bead_type "$bead_id" "$trigger_body" && echo "$gate_id"
        ;;
      *)
        _log_event "$(jq -nc --arg t "$trigger_type" --arg g "$gate_id" '{"gate":"evaluator","action":"unknown_trigger","details":{"trigger_type":$t,"gate_id":$g}}' 2>/dev/null || echo '')"
        ;;
    esac
  done < <(_enabled_gates_json)
  return 0
}

# $1 = bead ID being closed (for log context)
# $2 = gate ID whose evidence we need
# Returns 0 if a CLOSED bead titled exactly the gate's title has the evidence_marker in its notes/description;
#         2 otherwise.
_check_evidence() {
  local bead_id="$1"
  local gate_id="$2"
  _load_registry
  local gate_json title marker
  gate_json=$(jq -c --arg id "$gate_id" '.gates[] | select(.id == $id)' "$REGISTRY" 2>/dev/null)
  if [ -z "$gate_json" ]; then
    # Unknown gate: evidence definitively cannot exist. Do NOT fail-open here —
    # that would silently accept typos as "evidence present". Return missing.
    _log_event "$(jq -nc --arg g "$gate_id" --arg b "$bead_id" '{"gate":"evaluator","action":"evidence_missing","details":{"reason":"unknown gate id","gate_id":$g,"closing_bead":$b}}' 2>/dev/null || echo '')"
    return 2
  fi
  title=$(echo "$gate_json" | jq -r '.title')
  marker=$(echo "$gate_json" | jq -r '.evidence_marker')

  # Find a closed bead with this title
  local closed_list
  closed_list=$(bd list --status=closed 2>/dev/null || true)
  local gate_bead_id
  gate_bead_id=$(echo "$closed_list" | awk -v t="$title" 'index($0, t) {print $2; exit}')

  if [ -z "$gate_bead_id" ]; then
    _log_event "$(jq -nc --arg g "$gate_id" --arg b "$bead_id" '{"gate":"evaluator","action":"evidence_missing","details":{"reason":"no closed GATE bead with matching title","gate_id":$g,"closing_bead":$b}}' 2>/dev/null || echo '')"
    return 2
  fi

  # Check the gate bead's full text for the evidence_marker
  local gate_text
  gate_text=$(bd show "$gate_bead_id" 2>/dev/null || true)
  if echo "$gate_text" | grep -qF "$marker"; then
    _log_event "$(jq -nc --arg g "$gate_id" --arg gb "$gate_bead_id" --arg b "$bead_id" '{"gate":"evaluator","action":"evidence_ok","details":{"gate_id":$g,"gate_bead":$gb,"closing_bead":$b}}' 2>/dev/null || echo '')"
    return 0
  fi
  _log_event "$(jq -nc --arg g "$gate_id" --arg gb "$gate_bead_id" --arg b "$bead_id" --arg m "$marker" '{"gate":"evaluator","action":"evidence_missing","details":{"reason":"gate bead found but evidence_marker not in notes","gate_id":$g,"gate_bead":$gb,"closing_bead":$b,"marker":$m}}' 2>/dev/null || echo '')"
  return 2
}

# $1 = gate ID — prints a bd create command the caller can pipe to bash.
_emit_create() {
  local gate_id="$1"
  _load_registry
  local gate_json title description acceptance
  gate_json=$(jq -c --arg id "$gate_id" '.gates[] | select(.id == $id)' "$REGISTRY" 2>/dev/null)
  [ -z "$gate_json" ] && _die_fail_open "unknown gate id: $gate_id"
  title=$(echo "$gate_json" | jq -r '.title')
  description=$(echo "$gate_json" | jq -r '.description + " Acceptance: " + .acceptance')
  # Emit a shell-safe bd create command
  printf 'bd create --title=%q --description=%q --type=task --priority=1\n' "$title" "$description"
}

_list() {
  _load_registry
  jq -r '.gates[] | select(.enabled == true) | "\(.id)\t\(.title)"' "$REGISTRY" 2>/dev/null
}

# ---------- Main dispatch ----------
case "${1:-}" in
  --list)
    _list
    ;;
  --for-spec)
    [ -z "${2:-}" ] && _die_fail_open "missing spec path"
    _applicable_for_spec "$2"
    ;;
  --for-close)
    [ -z "${2:-}" ] && _die_fail_open "missing bead id"
    _applicable_for_close "$2"
    ;;
  --check-evidence)
    [ -z "${2:-}" ] || [ -z "${3:-}" ] && _die_fail_open "usage: --check-evidence <bead-id> <gate-id>"
    _check_evidence "$2" "$3"
    exit $?
    ;;
  --emit-create)
    [ -z "${2:-}" ] && _die_fail_open "missing gate id"
    _emit_create "$2"
    ;;
  -h|--help|"")
    cat <<EOF
Usage:
  $(basename "$0") --list
  $(basename "$0") --for-spec <spec-path>
  $(basename "$0") --for-close <bead-id>
  $(basename "$0") --check-evidence <bead-id> <gate-id>
  $(basename "$0") --emit-create <gate-id>

Registry: $REGISTRY
Log:      $LOG_FILE
EOF
    ;;
  *)
    _die_fail_open "unknown command: $1"
    ;;
esac
