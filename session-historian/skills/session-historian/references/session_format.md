# Claude Code Session JSONL Format

> **✅ VERIFIED**: Schema verified against real session files on 2025-12-25.

Session data is stored in `~/.claude/projects/{project-path-encoded}/` as JSONL files.

## File Naming

```
{session-uuid}.jsonl      # Regular sessions
agent-{short-id}.jsonl    # Agent/sub-agent sessions
```

## Entry Types

Each line is a JSON object with a `type` field at the top level:

### Summary Entry

Session summary (usually first entry after context compaction):

```json
{
  "type": "summary",
  "summary": "Brief description of session topic",
  "leafUuid": "uuid-of-last-message"
}
```

### File History Snapshot

Tracks file state for undo/recovery:

```json
{
  "type": "file-history-snapshot",
  "messageId": "uuid",
  "snapshot": {
    "messageId": "uuid",
    "trackedFileBackups": {},
    "timestamp": "2025-12-25T10:30:00.000Z"
  },
  "isSnapshotUpdate": false
}
```

### User Message

```json
{
  "type": "user",
  "parentUuid": "uuid-of-previous-message",
  "uuid": "this-message-uuid",
  "sessionId": "session-uuid",
  "timestamp": "2025-12-25T10:30:00.000Z",
  "cwd": "/home/orangepi/claude-life-dev",
  "gitBranch": "main",
  "version": "2.0.75",
  "userType": "external",
  "isSidechain": false,
  "message": {
    "role": "user",
    "content": "User's message text"
  }
}
```

### Tool Result (in User Message)

Tool results come as user messages with structured content:

```json
{
  "type": "user",
  "parentUuid": "uuid-of-tool-use",
  "uuid": "this-message-uuid",
  "message": {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_xxx",
        "content": "Tool output text or JSON"
      }
    ]
  }
}
```

### Assistant Message

```json
{
  "type": "assistant",
  "parentUuid": "uuid-of-previous",
  "uuid": "this-message-uuid",
  "sessionId": "session-uuid",
  "timestamp": "2025-12-25T10:30:05.000Z",
  "requestId": "req_xxx",
  "message": {
    "model": "claude-opus-4-5-20251101",
    "id": "msg_xxx",
    "type": "message",
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "Assistant's response"
      }
    ],
    "stop_reason": "end_turn",
    "usage": {
      "input_tokens": 1000,
      "output_tokens": 500
    }
  }
}
```

### Tool Use (in Assistant Message)

Tool calls are embedded in assistant message content:

```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {
        "type": "tool_use",
        "id": "toolu_xxx",
        "name": "Bash",
        "input": {
          "command": "git status"
        }
      }
    ],
    "stop_reason": "tool_use"
  }
}
```

### Thinking Block (in Assistant Message)

Extended thinking appears in content array:

```json
{
  "type": "assistant",
  "message": {
    "content": [
      {
        "type": "thinking",
        "thinking": "Internal reasoning text..."
      }
    ]
  }
}
```

## Key Fields Reference

| Field | Location | Description |
|-------|----------|-------------|
| `type` | Top level | Entry type: user, assistant, summary, file-history-snapshot |
| `uuid` | Top level | Unique identifier for this entry |
| `parentUuid` | Top level | UUID of previous message (conversation threading) |
| `sessionId` | Top level | Session identifier |
| `timestamp` | Top level | ISO 8601 timestamp |
| `cwd` | Top level | Working directory |
| `gitBranch` | Top level | Current git branch |
| `message.content` | message | Array of content blocks (text, tool_use, tool_result, thinking) |
| `message.stop_reason` | message | Why assistant stopped: end_turn, tool_use |
| `message.usage` | message | Token usage stats |

## Common Tool Names

| Tool | Purpose | Input Fields |
|------|---------|--------------|
| `Bash` | Shell commands | `command`, `description` |
| `Read` | Read files | `file_path`, `offset`, `limit` |
| `Write` | Write files | `file_path`, `content` |
| `Edit` | Edit files | `file_path`, `old_string`, `new_string` |
| `Glob` | Find files | `pattern`, `path` |
| `Grep` | Search content | `pattern`, `path`, `output_mode` |
| `Task` | Sub-agents | `prompt`, `subagent_type`, `description` |
| `WebFetch` | Fetch URLs | `url`, `prompt` |
| `TodoWrite` | Task tracking | `todos` |

## Project Path Encoding

The project path is encoded by replacing `/` with `-`:

```
/home/orangepi/claude-life-dev
→ -home-orangepi-claude-life-dev
```

Sessions stored in:
```
~/.claude/projects/-home-orangepi-claude-life-dev/{session-id}.jsonl
```

## Parsing Patterns

### Find All Tool Calls

```python
import json

tool_calls = []
with open(session_file) as f:
    for line in f:
        entry = json.loads(line)
        if entry.get("type") == "assistant":
            content = entry.get("message", {}).get("content", [])
            for block in content:
                if block.get("type") == "tool_use":
                    tool_calls.append({
                        "name": block["name"],
                        "input": block["input"],
                        "timestamp": entry.get("timestamp")
                    })
```

### Find Errors

```python
errors = []
with open(session_file) as f:
    for line in f:
        entry = json.loads(line)
        if entry.get("type") == "user":
            content = entry.get("message", {}).get("content", [])
            if isinstance(content, list):
                for block in content:
                    if block.get("type") == "tool_result":
                        # Check for error indicators in content
                        result = block.get("content", "")
                        if "error" in result.lower() or "failed" in result.lower():
                            errors.append(entry)
```

### Get Session Duration

```python
import json
from datetime import datetime

with open(session_file) as f:
    lines = [l for l in f if l.strip()]

first = json.loads(lines[0])
last = json.loads(lines[-1])

# Find first and last timestamps
start = first.get("timestamp") or first.get("snapshot", {}).get("timestamp")
end = last.get("timestamp") or last.get("snapshot", {}).get("timestamp")

if start and end:
    start_dt = datetime.fromisoformat(start.replace("Z", "+00:00"))
    end_dt = datetime.fromisoformat(end.replace("Z", "+00:00"))
    duration = end_dt - start_dt
```

### Count by Message Type

```python
from collections import Counter

types = Counter()
with open(session_file) as f:
    for line in f:
        entry = json.loads(line)
        types[entry.get("type", "unknown")] += 1
```
