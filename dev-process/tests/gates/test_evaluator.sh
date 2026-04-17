#!/usr/bin/env bash
# Unit tests for evaluate-gates.sh
# Usage: bash test_evaluator.sh
# Exit 0 on all pass, 1 on any fail.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVAL="$ROOT/scripts/evaluate-gates.sh"
FIX="$ROOT/tests/fixtures"

PASS=0
FAIL=0
FAILED_CASES=()

_sort() { tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ *$//'; }

assert_eq_sorted() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  local e_sorted a_sorted
  e_sorted=$(echo "$expected" | _sort)
  a_sorted=$(echo "$actual" | _sort)
  if [ "$e_sorted" = "$a_sorted" ]; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    echo "  expected: [$e_sorted]"
    echo "  actual:   [$a_sorted]"
    FAIL=$((FAIL+1))
    FAILED_CASES+=("$name")
  fi
}

# ---------- --list ----------
actual=$("$EVAL" --list | awk '{print $1}' | tr '\n' ' ' | sed 's/ *$//')
assert_eq_sorted "--list returns the 3 v1 gates" \
  "deps-verified plugin-installed pre-mortem-filed" \
  "$actual"

# ---------- --for-spec ----------
# plugin-only: touches ~/projects/claude_plugins/ → plugin-installed
actual=$("$EVAL" --for-spec "$FIX/spec-plugin-only.md" | tr '\n' ' ' | sed 's/ *$//')
assert_eq_sorted "--for-spec plugin-only → plugin-installed" \
  "plugin-installed" \
  "$actual"

# non-plugin: no claude_plugins paths, no deps section → none
actual=$("$EVAL" --for-spec "$FIX/spec-non-plugin.md" | tr '\n' ' ' | sed 's/ *$//')
assert_eq_sorted "--for-spec non-plugin → (none)" \
  "" \
  "$actual"

# has-deps: populated Dep Verification table → deps-verified
actual=$("$EVAL" --for-spec "$FIX/spec-has-deps.md" | tr '\n' ' ' | sed 's/ *$//')
assert_eq_sorted "--for-spec has-deps → deps-verified" \
  "deps-verified" \
  "$actual"

# empty-deps: header only, no rows → (none)
actual=$("$EVAL" --for-spec "$FIX/spec-empty-deps.md" | tr '\n' ' ' | sed 's/ *$//')
assert_eq_sorted "--for-spec empty-deps → (none)" \
  "" \
  "$actual"

# combined: plugin + deps → both
actual=$("$EVAL" --for-spec "$FIX/spec-plugin-and-deps.md" | tr '\n' ' ' | sed 's/ *$//')
assert_eq_sorted "--for-spec plugin-and-deps → deps-verified + plugin-installed" \
  "deps-verified plugin-installed" \
  "$actual"

# ---------- --for-close against real beads ----------
# Epic bead kyle-dev-infra-01v3 has issue_type=epic → pre-mortem-filed
# It does NOT yet have code changes pending, so paths_touched depends on the caller's git state.
# We only assert pre-mortem-filed is among the output (subset check, not exact match).
if bd show kyle-dev-infra-01v3 >/dev/null 2>&1; then
  actual=$("$EVAL" --for-close kyle-dev-infra-01v3 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
  if echo "$actual" | grep -qw pre-mortem-filed; then
    echo "PASS: --for-close epic-bead includes pre-mortem-filed"
    PASS=$((PASS+1))
  else
    echo "FAIL: --for-close epic-bead includes pre-mortem-filed"
    echo "  actual: [$actual]"
    FAIL=$((FAIL+1))
    FAILED_CASES+=("--for-close epic pre-mortem-filed")
  fi
fi

# R-bead (issue_type=feature) should NOT include pre-mortem-filed
if bd show kyle-dev-infra-cs8r >/dev/null 2>&1; then
  actual=$("$EVAL" --for-close kyle-dev-infra-cs8r 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
  if echo "$actual" | grep -qw pre-mortem-filed; then
    echo "FAIL: --for-close feature-bead should NOT include pre-mortem-filed"
    echo "  actual: [$actual]"
    FAIL=$((FAIL+1))
    FAILED_CASES+=("--for-close feature excludes pre-mortem")
  else
    echo "PASS: --for-close feature-bead excludes pre-mortem-filed"
    PASS=$((PASS+1))
  fi
fi

# ---------- --emit-create ----------
actual=$("$EVAL" --emit-create plugin-installed)
# %q escapes spaces — match on distinctive tokens only (GATE:, Plugin, tmux)
if echo "$actual" | grep -q 'bd create' \
   && echo "$actual" | grep -qF 'GATE' \
   && echo "$actual" | grep -qF 'tmux'; then
  # Verify the output is actually executable by eval'ing it in a dry-run context
  dry_cmd="${actual} --dry-run"
  if bash -c "$dry_cmd" >/dev/null 2>&1; then
    echo "PASS: --emit-create plugin-installed prints executable bd create command"
    PASS=$((PASS+1))
  else
    echo "FAIL: --emit-create plugin-installed output is not executable"
    echo "  actual: $actual"
    FAIL=$((FAIL+1))
    FAILED_CASES+=("--emit-create plugin-installed executable")
  fi
else
  echo "FAIL: --emit-create plugin-installed missing expected tokens"
  echo "  actual: $actual"
  FAIL=$((FAIL+1))
  FAILED_CASES+=("--emit-create plugin-installed tokens")
fi

# ---------- --check-evidence against the real closed dep-GATE bead (jwdp) ----------
# kyle-dev-infra-jwdp was closed with VERIFIED: note. --check-evidence for deps-verified should pass (exit 0).
if bd show kyle-dev-infra-jwdp >/dev/null 2>&1; then
  if "$EVAL" --check-evidence kyle-dev-infra-cs8r deps-verified 2>/dev/null; then
    echo "PASS: --check-evidence finds closed deps-verified GATE"
    PASS=$((PASS+1))
  else
    echo "FAIL: --check-evidence deps-verified (should find closed GATE with VERIFIED note)"
    FAIL=$((FAIL+1))
    FAILED_CASES+=("--check-evidence deps-verified")
  fi
fi

# --check-evidence for a definitely-nonexistent gate must return missing.
# (Using a real gate_id here would be state-dependent: once a GATE is closed
# with the right evidence marker in any test run, a real gate's check returns 0.)
if "$EVAL" --check-evidence kyle-dev-infra-cs8r no-such-gate-gibberish 2>/dev/null; then
  echo "FAIL: --check-evidence for bogus gate should not return 0"
  FAIL=$((FAIL+1))
  FAILED_CASES+=("--check-evidence bogus gate false-positive")
else
  echo "PASS: --check-evidence bogus gate correctly returns missing"
  PASS=$((PASS+1))
fi

# ---------- Summary ----------
echo
echo "=== $PASS passed, $FAIL failed ==="
if [ $FAIL -gt 0 ]; then
  echo "Failed cases:"
  printf '  - %s\n' "${FAILED_CASES[@]}"
  exit 1
fi
exit 0
