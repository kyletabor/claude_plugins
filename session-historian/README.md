# Session Historian

Read and analyze Claude Code session history for debugging, continuity, and workflow analysis.

## Why This Matters

Every Claude Code session generates a complete record of your conversation, tool usage, commands run, files modified, and errors encountered. This data is stored locally in `~/.claude/projects/` as JSONL files. The Session Historian plugin makes this treasure trove of debugging data accessible and actionable.

Use it to:

- **Maintain continuity across sessions** - Pick up where you left off yesterday or last week
- **Debug past failures** - Investigate what went wrong in a previous session without replaying the entire conversation
- **Detect error patterns** - Identify recurring issues across multiple sessions
- **Analyze workflows** - Understand tool usage, command patterns, and development habits
- **Search historical context** - Find when you implemented a specific feature or made a particular change
- **Onboard to projects** - Quickly understand what's been happening on a codebase

This is not a replacement for git history (which tracks code changes). Session Historian tracks conversations, debugging sessions, and workflow patterns.

## Installation

### From Marketplace

Install from the kyletabor/claude_plugins repository:

```bash
claude plugin add kyletabor/claude_plugins/crew/fix_it/session-historian
```

### Manual Installation

Clone or copy the plugin directory and add it:

```bash
git clone https://github.com/kyletabor/claude_plugins.git
claude plugin add ./claude_plugins/crew/fix_it/session-historian
```

## What It Does

Session Historian provides 6 Python scripts that parse JSONL session files and output structured JSON. All scripts use only Python standard library (no external dependencies).

### list_sessions

**What it does:** Lists sessions with metadata summary - message counts, tool usage, errors, duration, git branch.

**When to use:** "What happened in the last week?" or "Show me recent sessions on this project."

**Example:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py --project myproject --days 7 --limit 10
```

**Output:** Array of sessions with session_id, start_time, duration_minutes, tool_calls, error_count, tools_used, git_branch, summary.

---

### summarize_session

**What it does:** Timeline and summary of a specific session - chronological tool calls, files touched, commands run.

**When to use:** "Walk me through what that session did" or "What files did I modify yesterday?"

**Example:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/summarize_session.py --session-id abc123-uuid
```

**Output:** Timeline array with timestamps and actions, plus aggregated stats for tools_used, files_touched (read/written/edited), commands_run.

---

### search_sessions

**What it does:** Flexible search with composable filters - search by text, tool, command, file, duration, errors, or PR activity.

**When to use:** "Find sessions where we worked on authentication" or "Which sessions modified config.py?"

**Example:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project myproject --text "authentication" --days 14
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project myproject --file "config.py" --has-errors --days 7
```

**Available filters:**
- `--text <str>` - Full-text search in messages
- `--tool <name>` - Sessions using specific tool (Bash, Read, Write, etc.)
- `--command <str>` - Sessions running specific bash command
- `--file <path>` - Sessions that touched specific file
- `--min-duration <min>` - Minimum session duration
- `--has-errors` - Only sessions with errors
- `--has-pr` - Only sessions involving pull requests

---

### find_errors

**What it does:** Error patterns across sessions - error rates, categorized patterns, affected sessions.

**When to use:** "What's been failing recently?" or "Show me error trends this week."

**Example:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/find_errors.py --project myproject --days 3
```

**Output:** error_rate, total_errors, patterns (categorized by error type), affected_sessions (list of session IDs with errors), recent_errors (last 10).

---

### get_session_context

**What it does:** Full context extraction for deep debugging - all tool calls, tool results, errors, and optionally full messages.

**When to use:** "Give me full context on that broken session" or "Show me every command that session ran."

**Example:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/get_session_context.py --session-id abc123-uuid
python ${CLAUDE_PLUGIN_ROOT}/scripts/get_session_context.py --session-id abc123-uuid --include-messages
```

**Output:** metadata, statistics, tool_calls array (with inputs), tool_results array (with outputs and error detection), errors array, and optionally messages array.

---

### cross_session_analysis

**What it does:** Pattern analysis across multiple sessions - aggregate statistics for failures, tools, duration, or commands.

**When to use:** "Show me patterns across sessions" or "What tools do I use most often?"

**Example:**
```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project myproject --days 30 --focus failures
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project myproject --days 30 --focus tools
```

**Focus areas:**
- `failures` - Error rates, worst sessions, errors by branch
- `tools` - Tool usage frequency, usage rates, avg calls per session
- `duration` - Min/max/avg/median duration, duration buckets, 90th percentile
- `commands` - Slash command and git/gh command frequency

## Usage Examples

### Debugging a Regression

Something broke yesterday and you need to figure out what happened:

```bash
# Find sessions from yesterday
python ${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py --project myapp --days 1

# Check for errors
python ${CLAUDE_PLUGIN_ROOT}/scripts/find_errors.py --project myapp --days 1

# Get full context on the suspicious session
python ${CLAUDE_PLUGIN_ROOT}/scripts/get_session_context.py --session-id <uuid> --include-messages
```

### Onboarding Context

New to a project and need to understand what's been happening:

```bash
# List recent activity
python ${CLAUDE_PLUGIN_ROOT}/scripts/list_sessions.py --project myapp --days 14

# Summarize key sessions
python ${CLAUDE_PLUGIN_ROOT}/scripts/summarize_session.py --session-id <uuid>

# Look for patterns
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project myapp --days 14 --focus tools
```

### Error Trend Analysis

Are we seeing more failures lately?

```bash
# Check error rate this week
python ${CLAUDE_PLUGIN_ROOT}/scripts/find_errors.py --project myapp --days 7

# Compare to last month
python ${CLAUDE_PLUGIN_ROOT}/scripts/cross_session_analysis.py --project myapp --days 30 --focus failures

# Find sessions with errors on specific branch
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project myapp --has-errors --days 7
```

### Finding Specific Work

When did we implement feature X?

```bash
# Search for keywords
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project myapp --text "feature X" --days 30

# Find sessions that modified specific files
python ${CLAUDE_PLUGIN_ROOT}/scripts/search_sessions.py --project myapp --file "feature_x.py" --days 30

# Get timeline of the session
python ${CLAUDE_PLUGIN_ROOT}/scripts/summarize_session.py --session-id <uuid>
```

## How It Works

Session Historian reads JSONL session files from `~/.claude/projects/{encoded-path}/` and parses them according to the Claude Code session format.

### Project Path Encoding

Project paths are encoded by replacing `/` with `-`:

```
/home/user/myproject → -home-user-myproject
```

Scripts accept partial matches, so `--project myproject` will match `-home-user-myproject`.

### Session Format

Each line in a session file is a JSON object with a `type` field:
- `user` - User messages and tool results
- `assistant` - Assistant messages and tool calls
- `summary` - Session summary
- `file-history-snapshot` - File state tracking

Tool calls are embedded in assistant message content arrays as `tool_use` blocks. Tool results come back as `tool_result` blocks in user messages.

See `skills/session-historian/references/session_format.md` for the complete schema.

### Output Format

All scripts output JSON to stdout with the following structure:

```json
{
  "status": "success",
  "data": { ... },
  "parse_warnings": 0
}
```

On error:
```json
{
  "status": "error",
  "error": "Error description"
}
```

Exit codes: `0` for success, `1` for error.

## What It's NOT For

**Not a replacement for git history** - Session Historian tracks conversations and debugging workflows, not code changes. Use git for understanding code evolution.

**Not for real-time monitoring** - This reads historical session files. It doesn't watch active sessions or provide live updates.

**Can be slow with large searches** - Session files can be large (megabytes of JSONL). Searching many days across multiple projects can take time. Use `--limit` and narrow time ranges when possible.

**Requires sessions to exist** - Scripts can only analyze sessions that have been saved. If you just started using Claude Code or deleted `~/.claude/projects/`, there's nothing to analyze yet.

**Limited to local sessions** - Only reads from the local filesystem (`~/.claude/projects/`). Doesn't access remote or cloud-synced sessions.

## Troubleshooting

### Project Not Found

If you get `{"status": "error", "error": "Project 'X' not found"}`:

1. Check projects exist: `ls ~/.claude/projects/`
2. Remember path encoding: `/home/user/project` becomes `-home-user-project`
3. Use partial match: `--project myproject` matches `-home-user-myproject`

### Parse Warnings

Scripts track malformed JSONL lines in the `parse_warnings` field. A non-zero value means some lines were skipped but analysis continued. This is usually harmless (incomplete sessions, interrupted writes).

### Empty Results

If searches return no results:
- Verify the project name with `ls ~/.claude/projects/`
- Try wider time range (`--days 30` instead of `--days 1`)
- Check if sessions exist for that time period with `list_sessions`
- Remove filters and search broadly first

## Development

### Running Tests

```bash
# Run unit tests
python -m unittest discover tests/

# Run specific test
python -m unittest tests/test_list_sessions.py
```

### Contributing

This plugin is part of the [kyletabor/claude_plugins](https://github.com/kyletabor/claude_plugins) repository. Contributions welcome:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

### Adding New Scripts

Follow the pattern in existing scripts:
1. Parse arguments with `argparse`
2. Output JSON to stdout
3. Use exit code 0 for success, 1 for error
4. Handle `parse_warnings` for malformed JSONL
5. Document in SKILL.md

## License

MIT License - see repository for details.

## Author

Kyle Tabor - [https://github.com/kyletabor](https://github.com/kyletabor)
