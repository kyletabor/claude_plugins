---
name: tr-brief
description: Cold-start briefing — "where are we?" in 6 lines from beads, captures, TR memory, and pending handoffs
allowed-tools: ["Bash"]
argument-hint: "(no arguments — runs against current cwd)"
---

# Total Recall — Cold-Start Briefing

Run the briefing script and print its output verbatim. Do not paraphrase.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tr-brief.sh"
```

## What it does

Produces a 6-line briefing covering:

1. **Last session** — most recent file in the handoff dir (slug only)
2. **In flight** — count + first 3 IDs from `bd list --status=in_progress`
3. **Needs you** — count + first 3 from `bd ready --limit=3` (id + first words of title)
4. **New captures** — total inbox count + first item title from capture-mcp
5. **Footer** — handoff count and TR backend health

## Fail-soft behavior

- TR container down → `TR: TR offline` (set `TR_FORCE_OFFLINE=1` to simulate)
- No `.beads` in cwd → falls back to `~/projects/kyle-dev-infra/.beads/` (tagged `[central]`)
- Captures DB locked → 1s retry, then `captures unavailable`
- No in-progress beads → `none in progress`
- Handoff dir missing → `(no handoffs)`, count `0`

The script always exits 0. It never blocks the session on any single source's failure.

## References

- Script: `${CLAUDE_PLUGIN_ROOT}/scripts/tr-brief.sh`
- Spec: `/mnt/pi-data/pidocs/documents/tr-plugin-architecture-spec.html` (Component 2)
- Bead: `kyle-dev-infra-6l2d`
