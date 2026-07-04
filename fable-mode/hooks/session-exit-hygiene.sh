#!/bin/bash
# fable-mode Stop hook: session-exit-hygiene
# Blocks ending the turn when files THIS SESSION edited are sitting uncommitted
# in a git repo. Evidence source: 35/289 friction moments = "no concept of
# tomorrow" (Groundhog Day sessions, uncommitted complete features).
# Only fires on files this session touched — pre-existing repo dirt is ignored.
# Fail-open: any parse error exits 0. Blocks at most once (stop_hook_active).

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0

TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

EDITED=$(jq -r '
  select(.type == "assistant") | .message.content[]? |
  select(.type == "tool_use") |
  select(.name == "Edit" or .name == "Write" or .name == "MultiEdit") |
  .input.file_path // empty' "$TRANSCRIPT" 2>/dev/null | sort -u)
[ -z "$EDITED" ] && exit 0

DIRTY=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    /tmp/*|*/scratchpad/*|"$HOME"/.claude/*) continue ;;
  esac
  d=$(dirname "$f")
  [ -d "$d" ] || continue
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || continue
  if [ -n "$(git -C "$d" status --porcelain -- "$f" 2>/dev/null)" ]; then
    DIRTY="${DIRTY}${f}
"
  fi
done <<< "$EDITED"
[ -z "$DIRTY" ] && exit 0

FILES=$(echo "$DIRTY" | head -8 | tr '\n' ' ')
jq -nc --arg files "$FILES" \
  '{decision: "block", reason: ("session-exit-hygiene: files edited THIS session are uncommitted: " + $files + ". Commit them with a clear message now, or write an explicit handoff note stating what is uncommitted and why. Never hand back silent uncommitted work — the next session starts from Groundhog Day. Then finish.")}'
exit 0
