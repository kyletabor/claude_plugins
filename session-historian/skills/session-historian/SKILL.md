---
name: session-historian
description: Read and analyze Claude Code session history stored in ~/.claude/projects/. Use when asking about previous sessions, debugging past workflows, finding error patterns, searching conversations, understanding what agents did, or maintaining continuity across sessions. Triggers on questions like "what did the last session do", "show errors from recent sessions", "find sessions about X", "summarize session Y", "which sessions modified Z file".
---

# Session Historian

Read and analyze Claude Code session history for debugging, continuity, and workflow analysis.

## Quick Start

```bash
# List recent sessions
python ${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py --project claude-life-dev --days 7

# Summarize a session
python ${CLAUDE_PLUGIN_ROOT}/scripts/summarize_session.py --session-id <uuid>

# Search sessions
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project claude-life-dev --text "WebSocket" --days 7

# Find errors
python ${CLAUDE_PLUGIN_ROOT}/scripts/find_errors.py --project claude-life-dev --days 3

# Deep context for debugging
python ${CLAUDE_PLUGIN_ROOT}/scripts/get_session_context.py --session-id <uuid>

# Cross-session patterns
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project claude-life-dev --days 7 --focus failures
```

## Scripts Reference

### list_sessions.py

List sessions with metadata summary.

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py --project <name> --days <n> [--limit <n>]
```

**Output fields:** session_id, start_time, end_time, duration_minutes, tool_calls, tools_used, error_count, git_branch, cwd, message_count, user_messages, assistant_messages, summary, file_path, file_size_kb

### summarize_session.py

Timeline and summary of a specific session.

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/summarize_session.py --session-id <uuid>
```

**Output fields:** session_id, file_path, timeline, tools_used, files_touched (read/written/edited), commands_run, final_status, total_messages, total_tool_calls, session_summary, start_time, end_time

### search_sessions.py

Flexible search with composable filters.

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project <name> --days <n> [filters...]
```

**Filters:**
| Flag | Description |
|------|-------------|
| `--text <str>` | Full-text search in messages |
| `--tool <name>` | Sessions using specific tool (Bash, Read, etc.) |
| `--command <str>` | Sessions running specific command (substring match in Bash) |
| `--file <path>` | Sessions that touched specific file |
| `--min-duration <min>` | Minimum session duration in minutes |
| `--has-errors` | Only sessions with errors |
| `--has-pr` | Only sessions that touched PRs |
| `--limit <n>` | Max results to return |

### find_errors.py

Error patterns across sessions.

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/find_errors.py --project <name> --days <n>
```

**Output fields:** total_sessions, sessions_with_errors, error_rate, total_errors, patterns (categorized errors), affected_sessions, recent_errors

### get_session_context.py

Full context extraction for deep debugging.

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/get_session_context.py --session-id <uuid> [--include-messages]
```

**Output fields:**
- `metadata` - start/end time, duration, cwd, git_branch, version
- `statistics` - message counts, tool calls, errors, parse_warnings
- `tool_calls` - list of all tool invocations with inputs
- `tool_results` - list of tool outputs with error detection
- `errors` - extracted error events with context
- `messages` - full message content (only with --include-messages)

### cross_session_analysis.py

Pattern analysis across multiple sessions.

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project <name> --days <n> --focus <area>
```

**Focus areas:**

| Focus | Analysis |
|-------|----------|
| `failures` | Error rates, worst sessions, errors by branch |
| `tools` | Tool usage frequency, usage rates, avg calls per session |
| `duration` | Min/max/avg/median duration, duration buckets, 90th percentile |
| `commands` | Slash command and git/gh command frequency |

## Data Location

Sessions are stored in `~/.claude/projects/{encoded-path}/`:
- Path `/home/user/project` encodes to `-home-user-project`
- Each session is a `.jsonl` file with the session UUID as filename

See `references/session_format.md` for JSONL schema.

## Troubleshooting

### Project Not Found

If you get `{"status": "error", "error": "Project 'X' not found"}`:
- Check projects exist: `ls ~/.claude/projects/`
- Path encoding: `/home/user/project` becomes `-home-user-project`
- Use partial match: `--project myproject` matches `-home-user-myproject`

### Parse Warnings

Scripts track malformed JSONL lines in `parse_warnings` field. Non-zero value means some lines were skipped but analysis continued.

### Exit Codes

- `0` = Success (check `"status": "success"` in JSON)
- `1` = Error (check `"error"` field for details)

## Example Workflows

**Debug a failed workflow:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/find_errors.py --project myproject --days 3
python ${CLAUDE_PLUGIN_ROOT}/scripts/get_session_context.py --session-id <uuid> --include-messages
```

**Understand what happened yesterday:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py --project myproject --days 1
python ${CLAUDE_PLUGIN_ROOT}/scripts/summarize_session.py --session-id <uuid>
```

**Find sessions about a topic:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project myproject --text "authentication" --days 14
```

**Analyze patterns over time:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project myproject --days 30 --focus tools
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project myproject --days 30 --focus failures
```
