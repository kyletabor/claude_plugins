---
name: tr
description: |
  Total Recall front door — query and operate Kyle's externalized self-model from any Claude
  session. Use when the user wants to check TR backend status, search memory, trigger an
  ingest, or get a cold-start briefing of where they left off.

  Trigger: /tr [mode], or when working with TR memory, sessions, or the TR pipeline.

  Modes: brief, status, search, ingest

  NOT for: editing TR backend code (work in ~/projects/total-recall/ directly), friction
  story authoring (use /friction), or generic note-taking (use /capture).
user_invocable: true
argument-hint: "<mode: brief|status|search|ingest> [query]"
allowed-tools:
  - "Bash"
  - "Read"
  - "Grep"
  - "Glob"
---

# Total Recall (TR)

Total Recall is Kyle's externalized self-model — a unified memory layer over voice notes,
sessions, captures, beads, and knowledge docs. This skill is the **front door** for any
Claude session to interact with that backend.

The backend lives at `~/projects/total-recall/`. The MCP server runs in a Docker container
(`total-recall`). Code edits to the backend are out of scope for this skill — work in that
repo directly.

## Iron Rules

1. **Read-only by default.** This skill queries TR and reports state. It does not mutate
   the L0–L4 corpus. The exceptions are `ingest` (debugging trigger) and any future
   write paths, which must be explicit.
2. **Fail-soft.** If the TR backend is down, every mode must degrade gracefully and tell
   the user "TR backend unavailable — here's what I could check anyway." Never crash.
3. **Don't leak secrets in summaries.** TR contents may include API keys or tokens that
   slipped through filters. When summarizing search results, paraphrase — don't dump raw
   `golden_nuggets` content into the chat.

---

## Mode: brief

When the user invokes `/tr brief`, delegate to the `/tr-brief` slash command. That command
runs `${CLAUDE_PLUGIN_ROOT}/scripts/tr-brief.sh` which pulls:

- beads in flight + ready (with central fallback if no `.beads` in cwd)
- 5 most recent capture-mcp inbox items (count + top item)
- TR backend health (container + last ingest timestamp)
- pending handoff files in `/mnt/pi-data/claude-workspace/handoffs/`

into a 6-line briefing. The script is fail-soft: if any source is unavailable it labels
that section and continues. Exit code is always 0.

If for some reason the slash command is not registered, you can run the script directly:
`bash ~/projects/claude_plugins/total-recall/scripts/tr-brief.sh`

---

## Mode: status

Report TR backend health. Run these checks and summarize the results in 5 lines or fewer.

```bash
# Container status
docker ps --filter name=total-recall --format '{{.Status}}' 2>/dev/null || echo "docker unavailable"

# MCP tool list (proxy for "MCP server is up")
# claude mcp list-tools total-recall 2>/dev/null  # if available in the harness

# Last ingest timestamp + collection counts (if container is up)
docker exec total-recall sqlite3 /data/db.sqlite \
  "SELECT collection, COUNT(*) FROM synthesis_l1 GROUP BY collection;" 2>/dev/null \
  || echo "synthesis_l1 query failed"
```

**Output format (5 lines max):**
- Container: `running 2h` / `not running` / `docker unavailable`
- MCP tools: `8 registered` / `unreachable`
- Collections: `stardate=4200, claude-code-sessions=0` (or whatever counts come back)
- Last ingest: most recent `created_at` from `synthesis_l1`
- Health: `OK` / `degraded — <reason>` / `down`

If anything fails, name what failed and move on. Don't block the user on a TR outage.

---

## Mode: search

**Status:** stub — passthrough to TR's `memory_search` MCP tool when available.

When the user invokes `/tr search "<query>"`:

1. If the `mcp__total-recall__memory_search` tool is registered, call it with the query.
2. If not registered, fall back to `docker exec total-recall ...` direct sqlite query
   against `synthesis_l1.summary` using FTS5 if present, LIKE otherwise.
3. Return at most 5 results. For each: `[collection] title — 1-line paraphrase`.
4. Never paste raw `golden_nuggets` content; paraphrase to avoid secret leakage.

If the backend is down, tell the user and stop. Do not try to reconstruct results from
random files on disk.

---

## Mode: ingest

**Status:** stub — manual pipeline trigger for debugging.

When the user invokes `/tr ingest`, run the TR pipeline once against current sources:

```bash
docker exec total-recall node /app/dist/run.js 2>&1 | tail -40
```

Report:
- Files discovered, files ingested (new), files deduped (mtime+hash unchanged)
- Any error lines from the tail output
- Resulting collection counts (re-run the status query)

**Do not** kick off a re-distill of the entire corpus from this skill — that's a backend
operation that belongs in the TR repo. This mode is just for "I added a file, did it land?"

---

## References

- Architecture spec: `/mnt/pi-data/pidocs/documents/tr-plugin-architecture-spec.html`
- Backend repo: `~/projects/total-recall/`
- Pre-mortem (Wave 1): `~/projects/total-recall/docs/pre-mortem/2026-04-16-tr-plugin-wave-1.md`
- Beads: R1=`kyle-dev-infra-3clp` (this scaffold), R6=`kyle-dev-infra-6l2d` (/tr-brief)
