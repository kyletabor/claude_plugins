---
name: friction
description: |
  Friction mining lifecycle for Total Recall. Use when working on any friction-related content:
  writing v2 stories, extracting moments from Kyle's comments, logging to the graph, enriching
  existing moments, or reviewing the current state.

  Trigger: /friction [mode], or when working in the total-recall repo on friction stories,
  the friction graph, or session transcript mining.

  Modes: mine, story, extract, log, enrich, status

  NOT for: general Total Recall development (search, portraits, clustering),
  piDocs features, or non-friction content.
user_invocable: true
argument-hint: "<mode: mine|story|extract|log|enrich|status>"
allowed-tools:
  - "Bash"
  - "Read"
  - "Write"
  - "Edit"
  - "Grep"
  - "Glob"
  - "Agent"
  - "mcp__pidocs__treehouse_read"
  - "mcp__pidocs__treehouse_create"
  - "mcp__pidocs__treehouse_update"
  - "mcp__pidocs__treehouse_comment_list"
  - "mcp__pidocs__treehouse_comment_add"
  - "mcp__pidocs__treehouse_search"
---

# Friction Mining

Kyle is building "1,000 AI Failures" — a publishable dataset about how AI fails neurodivergent
users. This skill encodes the lifecycle for mining, documenting, and cataloging those failures.

## The Iron Rule

**This is collaborative sense-making, not batch data processing.** Kyle's comments on stories
are the primary data source. Your job is to think critically about each moment — not fill in
fields, not run extraction scripts, not produce generic summaries. Read `references/quality-bar.md`
before producing any friction content.

## Lifecycle Overview

```
mine → story → [Kyle comments] → extract → log → [Kyle comments] → enrich
```

Each mode has specific rules. Read the mode section below, then load relevant references.

---

## Mode: mine

Scan session transcripts for friction incidents worth documenting.

**Where sessions live:** `/home/orangepi/.claude/projects/-home-orangepi/{uuid}.jsonl`

**What to look for:**
- Kyle expressing frustration, confusion, or surprise
- Trust being broken (especially after trust was built)
- Kyle re-teaching something the agent should have known
- Kyle discovering something that should have been caught earlier
- Kyle naming a pattern ("this is Groundhog Day," "this is a hygiene failure")

**What to extract per incident:**
- Session ID (the UUID from the filename)
- Approximate timestamp (convert to Pacific Time)
- Kyle's key quotes (verbatim, never paraphrased)
- What went wrong (your assessment)
- What should have happened (your assessment)

**Before mining:** Check what's already in the graph to avoid re-mining documented incidents.
```bash
python3 /home/orangepi/projects/total-recall/scripts/friction-graph.py query moment
```

---

## Mode: story

Write a v2 friction story for Kyle's review. Read `references/v2-story-format.md` for full rules.

**The short version:**
- Write TO Kyle in second person ("you were skiing")
- Chronological play-by-play with Pacific Time markers
- Kyle's verbatim quotes are the most important content
- Conversational, like Claude talking to Kyle directly
- No editorial flourish. Interpretation of problems is fine.
- Dark background CSS (see reference for template)

**Publish to piDocs:**
```
Path: total-recall/friction-stories/XX-slug-v2.html
```
Give Kyle the link. His comments are the deliverable, not the story.

---

## Mode: extract

Read Kyle's comments on a story and extract friction moments, vision ideas, and categories.

**THIS IS LLM REASONING, NOT SCRIPTING.** Kyle's comments are voice-transcribed, verbose, and
rich with context. Only an LLM can read them and extract meaning without losing intent.

Read `references/moment-field-guide.md` for what each moment needs. The guide includes 5 diverse
examples showing how the weight shifts between fields depending on what the moment actually is.

**For each comment, identify:**
1. **Friction moments** — specific things that went wrong. Give them short, descriptive titles.
2. **Vision ideas** — how Kyle thinks things should work. His aspirations for AI.
3. **New categories** — if Kyle names a failure pattern, add it as a category node.
4. **Corrections** — if Kyle says the story got something wrong, note it.
5. **Preferences** — if Kyle expresses a permanent preference, save it as a memory.

**Use Kyle's words.** If he named it, use his name. "Excessive Cognitive Tax" not "User Burden."
"Groundhog Day" not "Recurring State Loss." See `references/quality-bar.md` for why this matters.

---

## Mode: log

Insert canonical moments into the friction graph. Read `references/graph-conventions.md` for
schema, dedup rules, and metadata conventions.

**Before inserting ANY moment:**
```python
import sqlite3
DB = '/home/orangepi/projects/total-recall/data/friction-graph.db'
db = sqlite3.connect(DB)

# Check for duplicates
existing = db.execute(
    "SELECT id, title FROM nodes WHERE type='moment' AND session_id=?",
    (session_id,)
).fetchall()
```

If the moment already exists, use `enrich` mode instead.

**Mandatory fields per moment:**
- `type`: always 'moment'
- `title`: short, descriptive, uses Kyle's framing when available
- `description`: full incident report — what went wrong + what should have happened
- `source_quote`: the single most impactful Kyle quote
- `session_id`: always filled (this is the dedup key)
- `story_number`: if documented in a story

**Categories are many-to-many via edges.** A moment typically carries 2-4 categories.
Apply ALL that fit — don't pick one primary. Check `references/category-taxonomy.md` for
the current taxonomy with discrimination tests.

---

## Mode: enrich

Update existing moments with new context from Kyle's comments or newly discovered sessions.

**Enrichment updates the existing node — never creates a duplicate.**

What to update:
- `description` — expand with new context
- `metadata` — add to `additional_quotes`, `enrichment_log`, `source_comments`
- New category edges — if Kyle's comment reveals additional categories
- Related moment edges — if Kyle connects this to another failure

```python
import sqlite3, json
DB = '/home/orangepi/projects/total-recall/data/friction-graph.db'
db = sqlite3.connect(DB)

# Read existing metadata
row = db.execute("SELECT metadata FROM nodes WHERE id=?", (node_id,)).fetchone()
meta = json.loads(row[0]) if row[0] else {}

# Add enrichment
meta.setdefault('enrichment_log', []).append('2026-04-11: enriched from story #11 comments')
meta.setdefault('additional_quotes', []).append('new quote here')

db.execute("UPDATE nodes SET metadata=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
    (json.dumps(meta), node_id))
db.commit()
```

---

## Mode: status

Show the current state of friction work.

```bash
# Graph stats
python3 /home/orangepi/projects/total-recall/scripts/friction-graph.py stats

# Recent moments
python3 /home/orangepi/projects/total-recall/scripts/friction-graph.py query moment

# Categories
python3 /home/orangepi/projects/total-recall/scripts/friction-graph.py query category
```

**Key piDocs:**
- Examples doc (gold standard): `e07dbb4163e16dad`
- Category taxonomy: `307aace35aa87da4`
- Stories: search piDocs for `total-recall/friction-stories/`

---

## Anti-Patterns

| What Goes Wrong | Why It's Wrong | What To Do Instead |
|---|---|---|
| Using a single template for all moments | Checkbox behavior — fields get filled, not thought about | Read the 5 diverse examples. Each shifts which field carries the weight |
| Paraphrasing Kyle's quotes | Loses his voice, which is the publishable content | Copy-paste verbatim. His exact words matter |
| Picking one category per moment | Moments have multiple failure modes | Apply ALL categories that fit (2-4 typical) via many-to-many edges |
| Running extraction scripts on comments | Deterministic code can't read voice-transcribed intent | LLM reads and reasons. Script stores the result |
| Creating duplicate moments | Fragments the graph, makes traversal unreliable | Check session_id before insert. Enrich existing nodes |
| Writing stories ABOUT Kyle (3rd person) | Feels published and finished — Kyle can't engage with it | Write TO Kyle (2nd person). He reacts to play-by-play |
| Consultant-speak categories | "Unstructured workflow degradation" — Kyle won't use it | Plain English, 10th-grader readable. Use Kyle's own words |
| Delivering a finished artifact without discussion | Skips the collaborative sense-making that produces quality | Show your thinking. Flag judgment calls. Let Kyle react |

## References

Load these on-demand when working in a specific mode:

- `references/quality-bar.md` — What good friction content looks like (READ FIRST)
- `references/v2-story-format.md` — Full rules for writing v2 stories
- `references/moment-field-guide.md` — What each field should contain, with 5 diverse examples
- `references/graph-conventions.md` — Schema, dedup, metadata, edge conventions
- `references/category-taxonomy.md` — Current categories with discrimination tests
