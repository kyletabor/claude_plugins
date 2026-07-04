#!/bin/bash
# fable-mode hook tests — fixture transcripts + a temp git repo.
# Usage: bash tests/test-hooks.sh   (exit 0 = all pass)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$HERE/../hooks"
TMP=$(mktemp -d)
# Repo fixture must NOT live in /tmp — the hygiene hook excludes /tmp by design.
REPO_BASE=$(mktemp -d "$HOME/.fable-mode-test.XXXXXX")
trap 'rm -rf "$TMP" "$REPO_BASE"' EXIT
PASS=0; FAIL=0

assert() { # name, expected(block|allow), actual_output
  local name="$1" expected="$2" out="$3"
  local got="allow"
  echo "$out" | grep -q '"decision":"block"' && got="block"
  if [ "$got" = "$expected" ]; then
    PASS=$((PASS+1)); echo "PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "FAIL: $name (expected $expected, got $got) out=$out"
  fi
}

mk_input() { # transcript_path, stop_active, cwd
  jq -nc --arg t "$1" --argjson s "$2" --arg c "$3" \
    '{transcript_path:$t, stop_hook_active:$s, cwd:$c, session_id:"test", hook_event_name:"Stop"}'
}

tool_use_line() { # tool_name, file_path
  jq -nc --arg n "$1" --arg f "$2" \
    '{type:"assistant", message:{content:[{type:"tool_use", name:$n, input:{file_path:$f}}]}}'
}

# ---------- rendered-proof ----------

# 1. frontend edit, no screenshot -> block
T1="$TMP/t1.jsonl"
tool_use_line Edit "/home/user/app/src/components/Button.tsx" > "$T1"
assert "rendered-proof: frontend edit, no evidence -> block" block \
  "$(mk_input "$T1" false "$TMP" | bash "$HOOKS/rendered-proof.sh")"

# 2. frontend edit + screenshot evidence -> allow
T2="$TMP/t2.jsonl"
tool_use_line Edit "/home/user/app/src/components/Button.tsx" > "$T2"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"mcp__plugin_playwright_playwright__browser_take_screenshot","input":{}}]}}' >> "$T2"
assert "rendered-proof: frontend edit + screenshot -> allow" allow \
  "$(mk_input "$T2" false "$TMP" | bash "$HOOKS/rendered-proof.sh")"

# 3. stop_hook_active -> allow (never loop)
assert "rendered-proof: stop_hook_active -> allow" allow \
  "$(mk_input "$T1" true "$TMP" | bash "$HOOKS/rendered-proof.sh")"

# 4. backend-only edit -> allow
T4="$TMP/t4.jsonl"
tool_use_line Edit "/home/user/app/server/db.py" > "$T4"
assert "rendered-proof: backend edit -> allow" allow \
  "$(mk_input "$T4" false "$TMP" | bash "$HOOKS/rendered-proof.sh")"

# 5. frontend TEST file edit -> allow (excluded path)
T5="$TMP/t5.jsonl"
tool_use_line Edit "/home/user/app/src/components/__tests__/Button.test.tsx" > "$T5"
assert "rendered-proof: test-file edit -> allow" allow \
  "$(mk_input "$T5" false "$TMP" | bash "$HOOKS/rendered-proof.sh")"

# ---------- session-exit-hygiene ----------

REPO="$REPO_BASE/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t && git -C "$REPO" config user.name t

# 6. session-edited file, uncommitted -> block
echo "x" > "$REPO/feature.py"
T6="$TMP/t6.jsonl"
tool_use_line Write "$REPO/feature.py" > "$T6"
assert "hygiene: uncommitted session edit -> block" block \
  "$(mk_input "$T6" false "$REPO" | bash "$HOOKS/session-exit-hygiene.sh")"

# 7. same file committed -> allow
git -C "$REPO" add -A && git -C "$REPO" commit -qm "commit feature"
assert "hygiene: committed session edit -> allow" allow \
  "$(mk_input "$T6" false "$REPO" | bash "$HOOKS/session-exit-hygiene.sh")"

# 8. stop_hook_active -> allow
echo "y" >> "$REPO/feature.py"
assert "hygiene: stop_hook_active -> allow" allow \
  "$(mk_input "$T6" true "$REPO" | bash "$HOOKS/session-exit-hygiene.sh")"

# 9. pre-existing repo dirt NOT touched by session -> allow
echo "z" > "$REPO/other.py"   # dirty but never edited via tools this session
T9="$TMP/t9.jsonl"
tool_use_line Read "$REPO/other.py" > "$T9"
assert "hygiene: pre-existing dirt untouched by session -> allow" allow \
  "$(mk_input "$T9" false "$REPO" | bash "$HOOKS/session-exit-hygiene.sh")"

# 10. scratchpad/tmp edits -> allow (excluded)
T10="$TMP/t10.jsonl"
tool_use_line Write "/tmp/claude-1000/x/scratchpad/note.md" > "$T10"
assert "hygiene: scratchpad edit -> allow" allow \
  "$(mk_input "$T10" false "$TMP" | bash "$HOOKS/session-exit-hygiene.sh")"

# 11. malformed input fails open -> allow
assert "both: malformed stdin -> allow" allow \
  "$(echo 'not json' | bash "$HOOKS/rendered-proof.sh"; echo 'not json' | bash "$HOOKS/session-exit-hygiene.sh")"

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
