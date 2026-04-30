#!/usr/bin/env bash
# session-start-latency.sh — asserts the deploy-standard SessionStart audit hook
# completes within Kyle's latency budget.
#
# Budgets:
#   cold run (no cache): ≤ 500ms
#   warm run (hot cache): ≤ 100ms
#
# Latency matters because this hook runs on every Claude Code session —
# slow hook = daily friction = Kyle disables the plugin. CAPA-15 Phase 5 T2.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$SCRIPT_DIR/.." && pwd)/hooks/session-start.sh"
CACHE="${DEPLOY_STANDARD_AUDIT_CACHE:-/tmp/deploy-standard-audit.cache}"

COLD_BUDGET_MS=500
WARM_BUDGET_MS=100

fail=0

_ms() {
  # Time a command, echo duration ms. Redirects hook stderr+stdout to /dev/null
  # so we measure work-time not terminal IO.
  local start end
  start=$(date +%s%N)
  "$@" >/dev/null 2>&1 || true
  end=$(date +%s%N)
  echo $(( (end - start) / 1000000 ))
}

[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK" >&2; exit 3; }

# Cold: clear cache first
rm -f "$CACHE" 2>/dev/null || true
cold_ms=$(_ms bash "$HOOK")
# Warm: run immediately (cache should be fresh)
warm_ms=$(_ms bash "$HOOK")

printf "cold=%4dms  budget=%dms\n" "$cold_ms" "$COLD_BUDGET_MS"
printf "warm=%4dms  budget=%dms\n" "$warm_ms" "$WARM_BUDGET_MS"

[ "$cold_ms" -le "$COLD_BUDGET_MS" ] || { echo "FAIL: cold run exceeded budget" >&2; fail=$((fail+1)); }
[ "$warm_ms" -le "$WARM_BUDGET_MS" ] || { echo "FAIL: warm run exceeded budget" >&2; fail=$((fail+1)); }

[ $fail -eq 0 ] && { echo "PASS"; exit 0; } || exit 1
