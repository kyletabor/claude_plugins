# deploy-standard

Enforces **Kyle Deploy Standard v1** for all deployable Kyle-owned projects.

Canonical spec: `~/projects/kyle-dev-infra/docs/deploy-standard.md`.

## What it does

### 1. Skill: `deploy-standard`

Triggers on any deploy/production/`/opt/`/docker-compose/systemd/`.deploy.yaml`/bind-mount
keyword. Tells the agent the rules and the `deploy <project> <env>` CLI workflow.

### 2. PreToolUse hook

Blocks agent actions that would violate the standard:

| # | Pattern | Example | Message action |
|---|---------|---------|----------------|
| 1 | `Write`/`Edit`/`MultiEdit` to `/opt/<project>/current/*` | editing active release in place | commit to repo, run `deploy` |
| 2 | `Write`/`Edit`/`MultiEdit` to `/opt/<project>/releases/*` | touching the deploy tool's area | commit to repo, run `deploy` |
| 3 | `Write`/`Edit`/`MultiEdit` to `/etc/systemd/system/*` | hand-writing systemd units | `deploy init <project>` generates compliant units |
| 4 | `Bash`: `cp ... /opt/<proj>/current\|releases` | copy-deploy (CAPA-9, CAPA-13) | use `deploy` |
| 5 | `Bash`: `mv`/`rsync ... /opt/<proj>/current\|releases` | same | use `deploy` |
| 6 | `Bash`: `docker compose up` outside `/opt/*/current` | ad-hoc `docker compose up` | use `deploy` |

**Bypass signals (for the deploy CLI itself or test harnesses):**

- Command starts with `deploy ` (followed by a subcommand)
- Command contains `DEPLOY_RUNNING=1` as an env var prefix
- Command runs from within `/opt/<project>/current/`

**Fail-open:** if the hook script errors, `jq` is missing, or input is malformed, the hook
allows the action and exits 0. No action is silently lost.

### 3. Tests

`hooks/test-hook.sh` simulates 21 hook invocations (9 block, 12 allow) and asserts each
produces the right response.

Run:
```bash
bash hooks/test-hook.sh
```

## Install

This plugin is published via the `kyle-plugins` marketplace (GitHub:
kyletabor/claude_plugins).

1. `/plugin marketplace add kyletabor/claude_plugins` (if not already added)
2. `/plugin install deploy-standard@kyle-plugins`
3. Restart Claude Code or start a fresh session.

The SessionStart marketplace validator will confirm the plugin is registered.

## Update workflow (maintainers)

1. Edit files under `~/projects/claude_plugins/deploy-standard/`.
2. Bump version in BOTH `.claude-plugin/plugin.json` AND the matching entry in
   `~/projects/claude_plugins/.claude-plugin/marketplace.json`.
3. Re-run `bash hooks/test-hook.sh` — all 21 tests must pass.
4. Commit and push. Fresh sessions fetch the new version.

## Why hooks

Per Kyle's core principle: **skills are suggestions, hooks are enforcement.** The skill
tells the agent what to do; the hook makes it impossible to violate the standard
accidentally. Root ownership of `/opt/<project>/current/` is the suspenders — the hook is
the belt. Bypassing both requires deliberate action (CAPA-13 prevention).

## Spec

Full spec at `~/projects/kyle-dev-infra/docs/deploy-standard.md` — §11 covers this plugin.
