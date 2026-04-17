# Total Recall Plugin

Front door for [Total Recall](https://github.com/kyletabor/total-recall) — Kyle's externalized self-model. Provides a single skill (`/tr`) and a cold-start briefing slash command (`/tr-brief`) so any Claude session can query the unified memory layer (voice notes, sessions, captures, beads, knowledge docs) without spelunking the backend.

## What It Does

| Component | What It Does |
|------|-------------|
| Skill `tr` mode `brief` | Delegates to the `/tr-brief` slash command |
| Skill `tr` mode `status` | Reports TR backend health (container, MCP, collection counts, last ingest) |
| Skill `tr` mode `search` | Passthrough to TR `memory_search` MCP tool |
| Skill `tr` mode `ingest` | Manual TR pipeline trigger for debugging |
| Command `/tr-brief` | 5-line cold-start briefing (STUB — fleshed out in L6) |

## Components

- **Skill:** `tr` — main lifecycle skill with 4 modes
- **Command:** `tr-brief` — cold-start briefing (currently a stub, L6 will implement)

## Dependencies

- Total Recall backend at `~/projects/total-recall/`
- TR Docker container `total-recall` (MCP server + sqlite at `/data/db.sqlite`)
- For `/tr-brief`: `bd` (beads), `capture-mcp`, `/mnt/pi-data/claude-workspace/handoffs/`

## Install

```bash
claude /plugin install total-recall
```

## Status

- **v0.1.0** — initial scaffold (L1, bead `kyle-dev-infra-3clp`).
- `brief` and `tr-brief` are stubs; full implementation tracked in `kyle-dev-infra-6l2d` (L6).
- `search` and `ingest` modes are functional but rely on the backend MCP being live.

## References

- Architecture spec: `/mnt/pi-data/pidocs/documents/tr-plugin-architecture-spec.html`
- Pre-mortem (Wave 1): `~/projects/total-recall/docs/pre-mortem/2026-04-16-tr-plugin-wave-1.md`
