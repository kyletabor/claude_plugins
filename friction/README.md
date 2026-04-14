# Friction Mining Plugin

Encodes the friction mining lifecycle for [Total Recall](https://github.com/kyletabor/total-recall) — Kyle's project to document how AI fails neurodivergent users.

## What It Does

Provides a single skill (`/friction`) with 6 modes covering the full lifecycle:

| Mode | What It Does |
|------|-------------|
| `mine` | Scan session transcripts for friction incidents |
| `story` | Write v2 stories for Kyle's review |
| `extract` | Read Kyle's comments and identify moments/visions/categories |
| `log` | Insert canonical moments into the knowledge graph |
| `enrich` | Update existing moments with new context |
| `status` | Show current state of the graph and stories |

## Components

- **Skill:** `friction` — main lifecycle skill with 5 reference files
- **Agent:** `friction-extractor` — reads piDocs comments and extracts structured content

## Dependencies

- Total Recall repo at `/home/orangepi/projects/total-recall/`
- Friction graph DB at `data/friction-graph.db`
- Graph CLI at `scripts/friction-graph.py`
- piDocs MCP server (treehouse tools)

## Install

```bash
claude /plugin install friction
```
