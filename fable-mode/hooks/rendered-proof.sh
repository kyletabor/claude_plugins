#!/bin/bash
# fable-mode Stop hook: rendered-proof
# Blocks ending the turn when frontend files were edited this session but no
# rendered-pixel evidence (Playwright screenshot / saved image) exists.
# Evidence source: 50/289 mined friction moments = "lacking verification";
# standing CLAUDE.md rule kept failing as prose, so it becomes a tripwire.
# Fail-open: any parse error exits 0. Blocks at most once (stop_hook_active).

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0

TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Frontend files edited this session via Edit/Write/MultiEdit
FRONTEND_EDITS=$(jq -r '
  select(.type == "assistant") | .message.content[]? |
  select(.type == "tool_use") |
  select(.name == "Edit" or .name == "Write" or .name == "MultiEdit") |
  .input.file_path // empty' "$TRANSCRIPT" 2>/dev/null |
  grep -E '\.(tsx|jsx|css|scss|html|vue|svelte)$|/(frontend|ui|components|pages)/[^ ]*\.(ts|js)$' |
  grep -vE '/(tests?|__tests__|fixtures|node_modules|scratchpad)/' |
  grep -v '^/tmp/' | sort -u)
[ -z "$FRONTEND_EDITS" ] && exit 0

# Rendered evidence: a Playwright screenshot tool call or an image file produced/referenced
if grep -qE 'browser_take_screenshot|\.png|\.jpe?g' "$TRANSCRIPT" 2>/dev/null; then
  exit 0
fi

FILES=$(echo "$FRONTEND_EDITS" | head -5 | tr '\n' ' ')
jq -nc --arg files "$FILES" \
  '{decision: "block", reason: ("rendered-proof: frontend files were edited this session (" + $files + ") but no rendered-pixel evidence exists. Grepping bundles or passing unit tests is NOT UI verification. Drive the real UI (Playwright), take a screenshot proving the change renders correctly, and include it in your summary — or state explicitly why UI verification does not apply here. Then finish.")}'
exit 0
