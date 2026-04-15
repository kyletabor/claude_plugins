#!/bin/bash
# Manual test runner for deploy-standard PreToolUse hook.
# Simulates hook input as JSON on stdin and asserts expected block/allow behavior.
#
# Run: bash hooks/test-hook.sh
# Exits 0 if all tests pass, 1 otherwise.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/pre-tool-use.sh"

if [ ! -x "$HOOK" ]; then
  echo "FAIL: hook not executable at $HOOK"
  exit 1
fi

PASS=0
FAIL=0

# run_case <name> <expected: block|allow> <json-input>
run_case() {
  local name="$1"
  local expected="$2"
  local input="$3"

  local output
  output=$(printf '%s' "$input" | bash "$HOOK" 2>/dev/null)
  local exit_code=$?

  local got="allow"
  if echo "$output" | grep -q '"decision":"block"'; then
    got="block"
  elif [ $exit_code -eq 2 ]; then
    got="block"
  fi

  if [ "$got" = "$expected" ]; then
    printf '  PASS  %s  (expected=%s got=%s)\n' "$name" "$expected" "$got"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s  (expected=%s got=%s)\n         output: %s\n' "$name" "$expected" "$got" "$output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== deploy-standard PreToolUse hook tests ==="

# --- Block cases ---

run_case "Write to /opt/<proj>/current/" "block" \
  '{"tool_name":"Write","tool_input":{"file_path":"/opt/treehouse/current/src/server.js","content":"x"}}'

run_case "Edit /opt/<proj>/current/" "block" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/opt/treehouse/current/Dockerfile","old_string":"a","new_string":"b"}}'

run_case "Write to /opt/<proj>/releases/" "block" \
  '{"tool_name":"Write","tool_input":{"file_path":"/opt/treehouse/releases/20260414-abc/foo","content":"x"}}'

run_case "Write to /etc/systemd/system/" "block" \
  '{"tool_name":"Write","tool_input":{"file_path":"/etc/systemd/system/treehouse-prod.service","content":"[Unit]"}}'

run_case "Bash: cp into /opt/<proj>/current" "block" \
  '{"tool_name":"Bash","tool_input":{"command":"cp build.tgz /opt/treehouse/current/"}}'

run_case "Bash: sudo cp into /opt/<proj>/releases" "block" \
  '{"tool_name":"Bash","tool_input":{"command":"sudo cp foo.js /opt/treehouse/releases/latest/"}}'

run_case "Bash: rsync into /opt/<proj>/current" "block" \
  '{"tool_name":"Bash","tool_input":{"command":"rsync -a build/ /opt/treehouse/current/"}}'

run_case "Bash: docker compose up outside /opt/current" "block" \
  '{"tool_name":"Bash","tool_input":{"command":"cd /home/orangepi/projects/pidocs && docker compose up -d"}}'

run_case "Bash: docker-compose up (legacy)" "block" \
  '{"tool_name":"Bash","tool_input":{"command":"docker-compose up -d"}}'

# --- Allow cases (positive controls) ---

run_case "Write elsewhere (home)" "allow" \
  '{"tool_name":"Write","tool_input":{"file_path":"/home/orangepi/projects/pidocs/src/server.js","content":"x"}}'

run_case "Edit in project repo" "allow" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/home/orangepi/projects/pidocs/Dockerfile","old_string":"a","new_string":"b"}}'

run_case "Bash: deploy CLI invocation" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"deploy treehouse staging master"}}'

run_case "Bash: deploy init" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"deploy init treehouse"}}'

run_case "Bash: docker compose up with DEPLOY_RUNNING bypass" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"DEPLOY_RUNNING=1 docker compose -f /tmp/foo/docker-compose.yml up -d --wait"}}'

run_case "Bash: docker compose up inside /opt/<proj>/current" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"cd /opt/treehouse/current && docker compose up -d --wait"}}'

run_case "Bash: unrelated command" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"git status"}}'

run_case "Bash: ls /opt (read-only)" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"ls /opt/treehouse/current/"}}'

run_case "Bash: docker ps (not up)" "allow" \
  '{"tool_name":"Bash","tool_input":{"command":"docker ps"}}'

run_case "Non-matching tool" "allow" \
  '{"tool_name":"Read","tool_input":{"file_path":"/opt/treehouse/current/foo.js"}}'

run_case "Malformed input (empty)" "allow" \
  ''

run_case "Malformed input (not JSON)" "allow" \
  'not json at all'

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ]
