---
name: secret-vault
description: Securely store secrets pasted in chat. Use when user mentions giving you a token, API key, password, or secret. Also use when you need to READ a previously stored secret.
---

# Secret Vault

Secrets are stored in `~/.secrets/` with chmod 600.

## Reading secrets

When a user says "use the github token" or "put my API key in X", check `~/.secrets/` first:

```bash
ls ~/.secrets/
cat ~/.secrets/<filename>
```

Common filenames: `github_token`, `anthropic_api_key`, `aws_access_key`, `tailscale_auth_key`, `unknown_token`

## Storing secrets

If the user wants to give you a secret, use `/secret` for the guided flow, or just tell them to paste it — the UserPromptSubmit hook will catch common patterns automatically.

## NEVER:
- Echo, print, or include secret values in your text responses
- Store secrets in conversation, memory files, or CLAUDE.md
- Commit secrets to git
