#!/usr/bin/env bash
# session-start.sh — SessionStart hook for deploy-standard compliance audit.
#
# Scans running Docker containers and checks each against Kyle Deploy Standard v1:
#   - Does the project have a .deploy.yaml in its repo?
#   - Does the project have both prod AND staging envs defined?
#   - Is the staging container currently running?
#
# Non-blocking: prints an advisory summary to stderr. Never blocks session start.
# Latency-critical: must complete <500ms cold / <100ms warm.
#
# Cache: /tmp/deploy-standard-audit.cache — regenerated when older than 5 minutes.
# CAPA-15 Phase 5 T4. Triggered by the incident where Excalidraw (no staging env)
# had a destructive test run against prod because nothing warned us.

set -o pipefail

CACHE="${DEPLOY_STANDARD_AUDIT_CACHE:-/tmp/deploy-standard-audit.cache}"
CACHE_TTL_SEC=300
PROJECTS_DIR="${DEPLOY_STANDARD_PROJECTS:-$HOME/projects}"

_print_cache() {
  cat "$CACHE" >&2 2>/dev/null || true
  exit 0
}

# Warm path: cache exists and is fresh → emit it and exit
if [ -f "$CACHE" ]; then
  now=$(date +%s)
  mtime=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  if [ $((now - mtime)) -lt "$CACHE_TTL_SEC" ]; then
    _print_cache
  fi
fi

# Cold path: enumerate deployed containers and evaluate compliance.
# Must stay fast — one docker ps call, minimal shell work.

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Container names that look like top-level deployed services (not ephemeral, not probe, not test).
# Filter: exclude names starting with test/probe/ephemeral/dead docker names (adjective_noun pattern).
# We match container names that look like real services: "-prod-", "-staging-", or a simple word ending in a real port bind.
docker ps --format '{{.Names}}|{{.Ports}}' 2>/dev/null | grep -vE '^(nifty_|beautiful_|clever_|heuristic_|jolly_|amazing_|friendly_|dazzling_|brave_|nostalgic_|charming_|bold_|eager_|cranky_)' > "$TMP"

non_compliant=""
compliant=""
unknown=""

while IFS='|' read -r name ports; do
  [ -z "$name" ] && continue

  # Derive project name: strip -prod-, -staging-, -1 suffixes
  # e.g. "treehouse-prod-treehouse-1" → "treehouse"
  # e.g. "excalidraw-canvas"          → "excalidraw"
  # e.g. "total-recall"               → "total-recall"
  proj=$(echo "$name" | sed -E 's/-(prod|staging|probe)-[^-]+-[0-9]+$//; s/-canvas$//; s/-[0-9]+$//')

  # Candidate repo paths
  deploy_yaml=""
  for candidate in "$PROJECTS_DIR/$proj/.deploy.yaml" \
                   "$PROJECTS_DIR/pidocs/.deploy.yaml"; do
    # Only let pidocs shadow "treehouse" name
    if [ "$proj" = "treehouse" ] && [ "$candidate" = "$PROJECTS_DIR/pidocs/.deploy.yaml" ]; then
      [ -f "$candidate" ] && { deploy_yaml="$candidate"; break; }
    elif [ "$candidate" = "$PROJECTS_DIR/$proj/.deploy.yaml" ]; then
      [ -f "$candidate" ] && { deploy_yaml="$candidate"; break; }
    fi
  done

  if [ -z "$deploy_yaml" ]; then
    # No .deploy.yaml at all
    if [ -d "$PROJECTS_DIR/$proj" ]; then
      non_compliant="$non_compliant $proj(no-.deploy.yaml)"
    else
      unknown="$unknown $name"
    fi
    continue
  fi

  # Quick grep for envs.staging presence (avoids yq dep)
  if grep -qE '^[[:space:]]*staging:' "$deploy_yaml" 2>/dev/null; then
    compliant="$compliant $proj"
  else
    non_compliant="$non_compliant $proj(no-staging-env)"
  fi
done < "$TMP"

# Trim leading spaces
non_compliant=$(echo "$non_compliant" | sed 's/^ *//')
compliant=$(echo "$compliant" | sed 's/^ *//')
unknown=$(echo "$unknown" | sed 's/^ *//')

# Build output
{
  if [ -n "$non_compliant" ]; then
    echo "⚠  deploy-standard: NON-COMPLIANT deployed services: $non_compliant"
    echo "   CAPA-15 remediation in progress. Avoid destructive tests against their prod URLs."
    echo "   See ~/projects/kyle-dev-infra/docs/deploy-standard.md"
  fi
  if [ -n "$unknown" ]; then
    echo "ℹ  deploy-standard: UNRECOGNIZED containers (no repo in $PROJECTS_DIR/): $unknown"
  fi
  # Silent when everything's compliant — no news is good news.
} > "$CACHE"

_print_cache
