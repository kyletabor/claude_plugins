# Secret Vault

**EXPERIMENTAL -- v0.1.0 -- Incomplete and under active development.**

Intercepts secrets pasted in chat and stores them securely before they enter the conversation.

## What It Does

Secret Vault provides a safety net for when API keys, tokens, or passwords are pasted directly into a Claude Code session. A UserPromptSubmit hook detects common secret patterns, saves the value to `~/.secrets/` with 600 permissions, scrubs it from session logs, and blocks the prompt from entering the conversation. This prevents secrets from being stored in conversation history or memory files.

## Components

- **Skills:** `secret-vault` -- guidance for reading and storing secrets
- **Commands:** `/secret` -- guided flow for securely entering a new secret (asks for type and label)
- **Hooks:** `UserPromptSubmit` via `intercept-secret.sh` -- automatically detects and intercepts secrets in user prompts

## Detected Secret Patterns

The intercept hook recognizes:

- GitHub fine-grained PATs (`github_pat_...`)
- GitHub classic PATs (`ghp_...`)
- Anthropic OAuth tokens (`sk-ant-oat...`)
- Anthropic API keys (`sk-ant-api...`)
- OpenAI API keys (`sk-...`)
- AWS access keys (`AKIA...`)
- Tailscale auth keys (`tskey-auth-...`)
- Generic long tokens (60+ character strings in short prompts)

## Usage

### Storing a Secret

Run `/secret` for the guided flow, or just paste a token directly -- the hook will catch it.

### Using a Stored Secret

Say something like "use the github_token for X" and Claude will read it from `~/.secrets/`.

### Security Rules

- Secrets are never echoed, printed, or included in text responses
- Secrets are never stored in conversation history, memory files, or CLAUDE.md
- Secrets are never committed to git
- All files in `~/.secrets/` have chmod 600

## Limitations

This plugin is experimental. The pattern matching is regex-based and may not catch all secret formats. The transcript scrubbing is best-effort.

## Installation

From the kyle-plugins marketplace -- already included if you have kyle-plugins installed.
