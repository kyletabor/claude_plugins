#!/usr/bin/env bash
# Validates that every plugin directory has a matching marketplace.json entry.
# Runs as a SessionStart hook via verification-hooks plugin.
# Exit 0 always (informational only — never blocks session start).

set -euo pipefail

# CLAUDE_PLUGIN_ROOT points to verification-hooks/, so go up one level for repo root
REPO_ROOT="${CLAUDE_PLUGIN_ROOT:-.}/.."
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
  exit 0
fi

# Extract registered plugin names from marketplace.json
registered=$(python3 -c "
import json, sys
with open('$MARKETPLACE') as f:
    data = json.load(f)
for p in data.get('plugins', []):
    print(p['name'])
" 2>/dev/null || exit 0)

missing=()

# Check each directory that contains a .claude-plugin/plugin.json
for dir in "$REPO_ROOT"/*/; do
  dirname=$(basename "$dir")
  plugin_json="$dir/.claude-plugin/plugin.json"

  [[ -f "$plugin_json" ]] || continue

  if ! echo "$registered" | grep -qx "$dirname"; then
    missing+=("$dirname")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "⚠️  Unregistered plugins detected in kyle-plugins marketplace:"
  for name in "${missing[@]}"; do
    echo "   - $name (has .claude-plugin/plugin.json but missing from marketplace.json)"
  done
  echo "   Fix: add entries to .claude-plugin/marketplace.json"
fi

exit 0
