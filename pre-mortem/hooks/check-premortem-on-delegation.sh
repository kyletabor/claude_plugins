#!/bin/bash
# PreToolUse hook on Agent tool — checks if delegation includes success/failure criteria
# Exit 0 = allow, Exit 2 = block
# This is a soft gate: warns but doesn't block (yet). Set PREMORTEM_HARD_GATE=1 to block.

INPUT=$(cat 2>/dev/null || true)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only check Agent tool calls
if [ "$TOOL_NAME" != "Agent" ]; then
  exit 0
fi

# Extract the prompt being sent to the sub-agent
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null)

# Short prompts (under 200 chars) are likely simple lookups, not multi-step work
if [ ${#PROMPT} -lt 200 ]; then
  exit 0
fi

# Check if the prompt contains success/failure criteria indicators
HAS_SUCCESS=$(echo "$PROMPT" | grep -ciE 'success (looks like|criteria|means)|what (success|good) looks like|acceptance criteria' 2>/dev/null || echo 0)
HAS_FAILURE=$(echo "$PROMPT" | grep -ciE 'failure (looks like|criteria|means|modes)|what (failure|bad) looks like|what could go wrong|pre-mortem' 2>/dev/null || echo 0)

if [ "$HAS_SUCCESS" -gt 0 ] && [ "$HAS_FAILURE" -gt 0 ]; then
  # Has both — allow
  exit 0
fi

if [ "$HAS_SUCCESS" -gt 0 ] || [ "$HAS_FAILURE" -gt 0 ]; then
  # Has one but not both — warn but allow
  cat >&2 <<EOF
PRE-MORTEM NOTICE: Agent delegation has partial criteria.
Missing: $([ "$HAS_SUCCESS" -eq 0 ] && echo "success criteria")$([ "$HAS_FAILURE" -eq 0 ] && echo "failure criteria")
Consider invoking the pre-mortem skill before delegating multi-step work.
EOF
  exit 0
fi

# Has neither — warn (or block if hard gate enabled)
if [ "${PREMORTEM_HARD_GATE:-0}" = "1" ]; then
  cat >&2 <<EOF
PRE-MORTEM REQUIRED: You are delegating multi-step work without success/failure criteria.

Before spawning this agent, invoke the pre-mortem skill to define:
1. What success looks like (specific, testable)
2. What failure looks like (specific, observable)
3. What assumptions you're relying on

Run /pre-mortem first, then retry the delegation.
EOF
  exit 2
fi

# Soft gate — warn but allow
cat >&2 <<EOF
PRE-MORTEM REMINDER: Delegating work without success/failure criteria.
Consider using /pre-mortem before multi-step delegations.
EOF
exit 0
