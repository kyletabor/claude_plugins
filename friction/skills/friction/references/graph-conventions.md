# Friction Graph Schema & Conventions

**Database:** `/home/orangepi/projects/total-recall/data/friction-graph.db` (SQLite, local).
  Local because SQLite over NFS is unsafe. Backed up nightly via SQL dump to `/mnt/pi-data/friction-mining/backups/`.
**Canonical data home:** `/mnt/pi-data/friction-mining/` (JSON pass results, kyle-messages, etc.). Backed up.
**CLI:** `python3 /home/orangepi/projects/total-recall/scripts/friction-graph.py`

## Tables

### nodes

| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK | Auto-increment |
| type | TEXT | `moment`, `vision`, `category`, `experience_category`, `session`, `meta_friction` |
| title | TEXT | Short, descriptive |
| description | TEXT | Full incident report |
| source_quote | TEXT | Single most impactful Kyle quote |
| date | TEXT | ISO date |
| session_id | TEXT | Dedup key for moments |
| pidoc_id | TEXT | |
| story_number | INTEGER | If documented in a story |
| metadata | TEXT | JSON blob (see below) |
| created_at | DATETIME | |
| updated_at | DATETIME | |

### edges

| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK | |
| source_id | INTEGER | FK to nodes |
| target_id | INTEGER | FK to nodes |
| relationship | TEXT | `has_category`, `has_experience`, `addresses`, `appeared_in`, `caused_by`, `related_to`, `child_of`, `references` |
| weight | REAL | |
| notes | TEXT | |
| created_at | DATETIME | |

## Two-axis tagging (v3 taxonomy)

Every moment carries tags on both axes. See `category-taxonomy.md`.

- **Axis A (Mechanism):** `moment -> has_category -> category` node
- **Axis B (Experience):** `moment -> has_experience -> experience_category` node
- **Visions:** `moment -> addresses -> vision` node (optional)
- **Sub-categories:** v3 sub-categories like "Lost in Handoff" or "Forward Momentum" are not all in the graph yet as nodes. Until they are, store them in moment metadata under `v3_mechanism` as a list of `"Parent → Sub"` strings.

## Dedup Before Insert (CRITICAL)

Never create duplicate moments. Always check first, then insert or enrich.

```python
# Check for existing moment in this session
existing = db.execute(
    "SELECT id, title FROM nodes WHERE type='moment' AND session_id=?",
    (session_id,)
).fetchall()

if existing:
    # ENRICH the existing node
    node_id = existing[0][0]
    db.execute(
        "UPDATE nodes SET description=?, updated_at=datetime('now') WHERE id=?",
        (enriched_description, node_id)
    )
    meta = json.loads(existing_meta or '{}')
    meta.setdefault('additional_quotes', []).append(new_quote)
    meta.setdefault('enrichment_log', []).append(f"{today}: enriched from {source}")
    db.execute("UPDATE nodes SET metadata=? WHERE id=?", (json.dumps(meta), node_id))
else:
    # INSERT new moment
    db.execute(
        """INSERT INTO nodes (type, title, description, source_quote,
           session_id, date, metadata, created_at, updated_at)
           VALUES ('moment', ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))""",
        (title, description, source_quote, session_id, date, json.dumps(metadata))
    )
    node_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
```

## Mandatory Fields for Moments

- **type**: always `'moment'`
- **title**: short, descriptive
- **description**: what went wrong + what should have happened
- **source_quote**: single most impactful Kyle quote (can be NULL for inferred/meta moments)
- **session_id**: ALWAYS filled (this is the dedup key)
- **story_number**: if documented in a story
- **metadata.v3_mechanism**: array of `"Parent → Sub"` strings for Axis A sub-categories
- At least one `has_category` edge (Axis A top-level)
- At least one `has_experience` edge (Axis B)

## Metadata JSON Conventions

```json
{
  "v3_mechanism": ["Missing Context → Lost in Handoff", "Orchestration → Ship What You Build"],
  "v3_experience": ["Groundhog Day", "Cognitive Exhaustion"],
  "additional_sessions": ["session-id-2"],
  "source_comments": ["comment-uuid"],
  "kyle_label": "bad hygiene story",
  "additional_quotes": ["second quote", "third quote"],
  "enrichment_log": ["2026-04-11: enriched from story #11 comments"]
}
```

## Edge Conventions

- **Mechanism (Axis A):** `moment -> has_category -> category` (1+ per moment, apply ALL that fit)
- **Experience (Axis B):** `moment -> has_experience -> experience_category` (1+ per moment)
- **Visions:** `moment -> addresses -> vision` (optional, 0+ per moment)
- **Story links:** `moment -> appeared_in -> story` node
- **Cross-moment:** `moment -> related_to -> moment` with `notes` explaining the connection
- **Sub-category hierarchy:** `sub -> child_of -> parent` (when sub-categories become their own nodes)

## CLI Quick Reference

```bash
python3 scripts/friction-graph.py stats          # Summary counts
python3 scripts/friction-graph.py query moment   # List moments
python3 scripts/friction-graph.py query vision   # List visions
python3 scripts/friction-graph.py links 19       # Edges for node 19
python3 scripts/friction-graph.py search "text"  # Full-text search
```

## Backup

Nightly SQL dump runs via cron:

```bash
sqlite3 /home/orangepi/projects/total-recall/data/friction-graph.db .dump \
  > /mnt/pi-data/friction-mining/backups/friction-graph-$(date +%Y%m%d).sql
```

Restore from dump:

```bash
sqlite3 friction-graph.db < friction-graph-YYYYMMDD.sql
```
