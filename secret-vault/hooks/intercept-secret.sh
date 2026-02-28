#!/usr/bin/env bash
# Secret interceptor hook for UserPromptSubmit
# Detects secret patterns in user prompts, saves them securely,
# scrubs session logs, and blocks the prompt from entering conversation.

set -euo pipefail

SECRETS_DIR="$HOME/.secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Read hook input from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")

if [ -z "$PROMPT" ]; then
  exit 0
fi

# Secret patterns: prefix -> label
# Each pattern: regex prefix, human label, filename
detect_secret() {
  local prompt="$1"

  # GitHub fine-grained PAT
  if echo "$prompt" | grep -qoP 'github_pat_[A-Za-z0-9_\-]{30,}'; then
    SECRET=$(echo "$prompt" | grep -oP 'github_pat_[A-Za-z0-9_\-]{30,}')
    echo "github_pat|github_token|GitHub fine-grained PAT|$SECRET"
    return 0
  fi

  # GitHub classic PAT
  if echo "$prompt" | grep -qoP 'ghp_[A-Za-z0-9]{30,}'; then
    SECRET=$(echo "$prompt" | grep -oP 'ghp_[A-Za-z0-9]{30,}')
    echo "ghp_|github_token_classic|GitHub classic PAT|$SECRET"
    return 0
  fi

  # Anthropic OAuth token
  if echo "$prompt" | grep -qoP 'sk-ant-oat[A-Za-z0-9_\-]{30,}'; then
    SECRET=$(echo "$prompt" | grep -oP 'sk-ant-oat[A-Za-z0-9_\-]{30,}')
    echo "sk-ant-oat|anthropic_oauth|Anthropic OAuth token|$SECRET"
    return 0
  fi

  # Anthropic API key
  if echo "$prompt" | grep -qoP 'sk-ant-api[A-Za-z0-9_\-]{30,}'; then
    SECRET=$(echo "$prompt" | grep -oP 'sk-ant-api[A-Za-z0-9_\-]{30,}')
    echo "sk-ant-api|anthropic_api_key|Anthropic API key|$SECRET"
    return 0
  fi

  # OpenAI API key
  if echo "$prompt" | grep -qoP 'sk-[A-Za-z0-9]{40,}'; then
    SECRET=$(echo "$prompt" | grep -oP 'sk-[A-Za-z0-9]{40,}')
    echo "sk-|openai_api_key|OpenAI API key|$SECRET"
    return 0
  fi

  # AWS access key
  if echo "$prompt" | grep -qoP 'AKIA[A-Z0-9]{16}'; then
    SECRET=$(echo "$prompt" | grep -oP 'AKIA[A-Z0-9]{16}')
    echo "AKIA|aws_access_key|AWS access key|$SECRET"
    return 0
  fi

  # Tailscale auth key
  if echo "$prompt" | grep -qoP 'tskey-auth-[A-Za-z0-9\-]{30,}'; then
    SECRET=$(echo "$prompt" | grep -oP 'tskey-auth-[A-Za-z0-9\-]{30,}')
    echo "tskey|tailscale_auth_key|Tailscale auth key|$SECRET"
    return 0
  fi

  # Generic long hex/base64 that looks like a token (50+ chars, no spaces)
  # Only match if user seems to be sharing a token (prompt is short, mostly the token)
  local word_count=$(echo "$prompt" | wc -w)
  if [ "$word_count" -le 15 ]; then
    if echo "$prompt" | grep -qoP '[A-Za-z0-9_\-]{60,}'; then
      # Don't match if it looks like a URL or file path
      if ! echo "$prompt" | grep -qP '(https?://|/home/|/usr/|/var/)'; then
        SECRET=$(echo "$prompt" | grep -oP '[A-Za-z0-9_\-]{60,}' | head -1)
        echo "generic|unknown_token|unrecognized token|$SECRET"
        return 0
      fi
    fi
  fi

  return 1
}

DETECTION=$(detect_secret "$PROMPT") || true

if [ -z "$DETECTION" ]; then
  # No secret detected, allow prompt through
  exit 0
fi

# Parse detection result
IFS='|' read -r PREFIX FILENAME LABEL SECRET <<< "$DETECTION"

# Save the secret securely
SECRET_PATH="$SECRETS_DIR/$FILENAME"
echo "$SECRET" > "$SECRET_PATH"
chmod 600 "$SECRET_PATH"

# Scrub the secret from the transcript file if we have one
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # Escape special chars for sed
  ESCAPED_SECRET=$(printf '%s\n' "$SECRET" | sed 's/[&/\]/\\&/g')
  sed -i "s/${ESCAPED_SECRET}/[VAULT:${FILENAME}]/g" "$TRANSCRIPT" 2>/dev/null || true
fi

# Also scrub from history.jsonl
HISTORY="$HOME/.claude/history.jsonl"
if [ -f "$HISTORY" ]; then
  ESCAPED_SECRET=$(printf '%s\n' "$SECRET" | sed 's/[&/\]/\\&/g')
  sed -i "s/${ESCAPED_SECRET}/[VAULT:${FILENAME}]/g" "$HISTORY" 2>/dev/null || true
fi

# Block the prompt and inform user
echo "Caught a ${LABEL} and saved it to ${SECRET_PATH}" >&2
echo "Tell Claude to read it from there (e.g. \"use the ${FILENAME} for openclaw\")." >&2
exit 2
