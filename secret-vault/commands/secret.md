---
name: secret
description: Securely accept and store a secret (token, API key, etc.)
user_invocable: true
---

# Secret Vault — Guided Token Entry

The user wants to give you a secret (API key, token, password, etc.) securely.

## Your job:

1. Use AskUserQuestion to ask what KIND of secret (use these options):
   - GitHub token
   - Anthropic API key
   - AWS credentials
   - Tailscale key
   - Other (let them type)

2. Use AskUserQuestion to ask for a **label** (short name like "openclaw-github" or "prod-api-key"). Suggest a reasonable default based on their answer.

3. Tell the user:
   > Ready! Paste your token in the next message. The vault hook will catch it before it enters the conversation, save it to `~/.secrets/<label>`, and scrub it from all logs.
   >
   > Just paste the raw token and hit enter.

4. After the user pastes (the hook will block it and show a confirmation), tell them:
   > Done. To use it, just say something like "put the <label> token in openclaw" and I'll read it from the vault.

## Important:
- The UserPromptSubmit hook handles the actual interception. You don't need to process the secret yourself.
- If the hook didn't catch it (e.g., the secret didn't match known patterns), immediately read the transcript_path, scrub the secret manually using sed, and save it to ~/.secrets/ yourself.
- NEVER echo, print, or repeat the secret value in your responses.
- After storing, confirm the file exists and its permissions are 600.
