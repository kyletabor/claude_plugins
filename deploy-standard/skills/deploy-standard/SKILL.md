---
name: deploy-standard
description: >
  Use this skill any time you are about to deploy a project, touch `/opt/<project>/`, write a
  systemd unit, write a `docker-compose.yml`, run `docker compose up` outside a release directory,
  discuss production/staging strategy, edit a `.deploy.yaml`, or bind-mount persistent state.
  Kyle's Deploy Standard v1 is mandatory for every deployable project — this skill tells you the
  rules and the `deploy` CLI workflow.
when_to_use:
  - About to run `docker compose up`, `systemctl start`, or any deploy command
  - Writing or editing files under `/opt/<project>/`
  - Writing a systemd service unit for a long-running service
  - Writing or editing `docker-compose.yml` / `docker-compose.<env>.yml` / `.deploy.yaml`
  - Planning production / staging split or rollback strategy
  - Choosing where to put persistent data (databases, uploads, content)
  - User says "deploy", "ship", "production", "staging", "rollback"
  - PreToolUse hook blocked an action with a pointer to this skill
---

# Deploy Standard v1

**Every deployable Kyle-owned project uses this standard.** No exceptions. Canonical spec:
`~/projects/kyle-dev-infra/docs/deploy-standard.md`.

## When to use

Trigger this skill the moment you see any of the following in a task:

- The word "deploy", "ship", "production", "staging", "rollback"
- A path starting with `/opt/` or `/mnt/pi-data/`
- A `docker-compose*.yml`, `Dockerfile`, `.deploy.yaml`, or systemd unit file
- A `docker compose up` / `docker compose down` / `systemctl restart` command
- Any decision about where persistent data lives

If a PreToolUse hook just blocked your action with a pointer to this skill, re-read the **Rules**
section below and switch to the `deploy` CLI.

## Rules (non-negotiable)

1. **Prod deploys ONLY from master.** `deploy <project> prod` forces `ref=master`; any other ref is
   rejected. Staging accepts any committed ref.
2. **Stateful data lives in `/mnt/pi-data/<project>/<env>/<category>/`.** Bind-mounted into the
   container. **Never use named docker volumes for state** — they are invisible to rsync and hard
   to back up. Named volumes are only acceptable for regeneratable caches.
3. **Base `docker-compose.yml` declares ZERO volumes.** All bind mounts live in
   `docker-compose.<env>.yml`. Compose multi-file merge appends volume entries, so any volume in
   the base leaks into every environment.
4. **Images run as UID 1000.** `/mnt/pi-data/<project>/<env>/` is chowned to `1000:1000` at
   scaffold time by `deploy init`. Host `orangepi` user is UID 1000.
5. **`/opt/<project>/current/` is root-owned.** Agents cannot write there. The filesystem enforces
   this; the hook is belt, root ownership is suspenders.
6. **Never `cp` files into `/opt/*/`.** The `deploy` CLI is the only legitimate way to publish a
   release. Use `git clone` via `deploy`, not `cp`.
7. **Never hand-write a systemd unit for a deployed project.** `deploy init` generates a
   compliant unit with correct `After=`, `RequiresMountsFor=`, and `Type=oneshot
   RemainAfterExit=true`. Hand-written units miss the Tailscale/NFS ordering and break on reboot.
8. **Never run `docker compose up` outside `/opt/<project>/current/`.** Use `deploy <project>
   <env>` — it handles build, health-probe, symlink swap, systemd restart, and rollback atomically.
9. **`/healthz` endpoint is required** in the app (returns `{"ok": true}`). The Dockerfile
   `HEALTHCHECK` and the deploy tool's pre-/post-swap probe both hit it.

## Workflow

### Is this project onboarded to the Deploy Standard?

Check for `.deploy.yaml` at the repo root:

```bash
test -f .deploy.yaml && echo "onboarded" || echo "not onboarded"
```

- **Onboarded** → use `deploy <project> <env> [ref]` to deploy. Never bypass.
- **Not onboarded** → run `deploy init <name>` first to scaffold `/opt/<name>/`,
  `/mnt/pi-data/<name>/{prod,staging}/`, systemd units, and port registration. Then author the
  `.deploy.yaml`, `Dockerfile`, `docker-compose.yml`, `docker-compose.prod.yml`, and
  `docker-compose.staging.yml` per the spec (§2-§4).

### Deploying

```bash
deploy treehouse staging master        # staging deploy from master
deploy treehouse staging feature-x     # staging deploy from any committed ref
deploy treehouse prod                  # prod deploy (always master, ref ignored)
```

The deploy tool:

1. Clones the repo into a fresh `/opt/<project>/releases/<ts-sha>/`.
2. Builds the image, runs a read-only pre-swap health probe on an ephemeral port.
3. Atomically swaps the `current` symlink (`ln + mv -Tf`).
4. `systemctl restart <project>-<env>.service`.
5. Runs post-restart `/healthz` probe.
6. On ANY failure in 1-5: rolls back symlink + restarts, exits non-zero.

### Rolling back

```bash
deploy rollback treehouse prod         # reverts to N-1 release, target <15s
```

### Observing

```bash
deploy status treehouse
deploy list                            # all known projects, in-opt / in-projects / both
deploy logs treehouse prod -f
deploy doctor                          # verifies docker, yq, jq, tailscale, UID alignment
```

## Quick reference

| Subcommand | Purpose |
|------------|---------|
| `deploy <project> <env> [ref]` | Deploy (prod forces master; staging accepts any ref) |
| `deploy rollback <project> <env>` | Swap symlink back to N-1 release, target <15s |
| `deploy status <project>` | Show current sha, previous sha, last deploy time |
| `deploy list` | All projects with in-opt / in-projects / both divergence column |
| `deploy init <name>` | Scaffold `/opt/<name>/`, `/mnt/pi-data/<name>/`, systemd, ports |
| `deploy logs <project> <env> [-f]` | Tail deploy + container logs |
| `deploy doctor` | Verify dependencies, port registry, UID alignment |

## Common mistakes

- **"I'll just `docker compose up` to test"** — no. Use `deploy <project> staging <ref>`. Staging
  is the test environment; stop making throwaway ones.
- **"I'll just drop a file into `/opt/treehouse/current/`"** — blocked by the filesystem (root
  ownership) and by the PreToolUse hook. Commit to the repo, then `deploy`.
- **"I'll add a named volume for the DB, it's fine"** — it's not fine. Named volumes can't be
  rsynced by the existing `/mnt/pi-data/` backup. Bind-mount to
  `/mnt/pi-data/<project>/<env>/db/`.
- **"I'll write a systemd unit by hand"** — miss `RequiresMountsFor=/mnt/pi-data/...` and
  `After=tailscaled.service remote-fs.target` and the service will fail to start on reboot. Use
  `deploy init`.

## Full spec

`~/projects/kyle-dev-infra/docs/deploy-standard.md` — read this when authoring new `.deploy.yaml`
files, migrating a project, or debugging the deploy tool.
