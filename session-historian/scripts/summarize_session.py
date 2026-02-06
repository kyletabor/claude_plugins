#!/usr/bin/env python3
"""
Extract key actions and timeline from a specific session.

Usage:
    python summarize_session.py --session-id <uuid>

Output: JSON with timeline of actions, tools used, files touched, final status.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional


def find_session_file(session_id: str) -> Optional[Path]:
    """Find a session file by its ID across all projects."""
    claude_projects = Path.home() / ".claude" / "projects"

    if not claude_projects.exists():
        return None

    # Search all project directories
    for project_dir in claude_projects.iterdir():
        if not project_dir.is_dir():
            continue

        # Try exact match
        session_file = project_dir / f"{session_id}.jsonl"
        if session_file.exists():
            return session_file

        # Try with agent- prefix
        if not session_id.startswith("agent-"):
            agent_file = project_dir / f"agent-{session_id}.jsonl"
            if agent_file.exists():
                return agent_file

    return None


def summarize_session(session_file: Path) -> dict:
    """Extract a summary of the session."""
    summary = {
        "session_id": session_file.stem,
        "file_path": str(session_file),
        "timeline": [],
        "tools_used": {},
        "files_touched": {
            "read": set(),
            "written": set(),
            "edited": set(),
        },
        "commands_run": [],
        "final_status": "unknown",
        "total_messages": 0,
        "total_tool_calls": 0,
        "session_summary": None,
        "start_time": None,
        "end_time": None,
    }

    try:
        with open(session_file, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                entry_type = entry.get("type")
                timestamp = entry.get("timestamp")

                # Track times
                if timestamp:
                    if summary["start_time"] is None:
                        summary["start_time"] = timestamp
                    summary["end_time"] = timestamp

                # Capture session summary
                if entry_type == "summary":
                    summary["session_summary"] = entry.get("summary")

                # Process user messages
                if entry_type == "user":
                    summary["total_messages"] += 1
                    content = entry.get("message", {}).get("content", "")

                    # Direct user input (not tool result)
                    if isinstance(content, str) and content:
                        summary["timeline"].append({
                            "time": timestamp,
                            "type": "user_message",
                            "preview": content[:100] + ("..." if len(content) > 100 else "")
                        })

                # Process assistant messages
                elif entry_type == "assistant":
                    summary["total_messages"] += 1
                    content = entry.get("message", {}).get("content", [])

                    if isinstance(content, list):
                        for block in content:
                            block_type = block.get("type")

                            if block_type == "tool_use":
                                tool_name = block.get("name", "unknown")
                                tool_input = block.get("input", {})

                                summary["total_tool_calls"] += 1
                                summary["tools_used"][tool_name] = summary["tools_used"].get(tool_name, 0) + 1

                                # Track file operations
                                if tool_name == "Read":
                                    file_path = tool_input.get("file_path", "")
                                    if file_path:
                                        summary["files_touched"]["read"].add(file_path)

                                elif tool_name == "Write":
                                    file_path = tool_input.get("file_path", "")
                                    if file_path:
                                        summary["files_touched"]["written"].add(file_path)

                                elif tool_name == "Edit":
                                    file_path = tool_input.get("file_path", "")
                                    if file_path:
                                        summary["files_touched"]["edited"].add(file_path)

                                elif tool_name == "Bash":
                                    command = tool_input.get("command", "")
                                    if command:
                                        summary["commands_run"].append(command[:200])

                                # Add to timeline (limit to important tools)
                                if tool_name in ["Write", "Edit", "Bash", "Task"]:
                                    desc = tool_input.get("description", "")
                                    if not desc and tool_name == "Bash":
                                        desc = tool_input.get("command", "")[:50]
                                    summary["timeline"].append({
                                        "time": timestamp,
                                        "type": "tool_use",
                                        "tool": tool_name,
                                        "description": desc[:100] if desc else None
                                    })

                            elif block_type == "text":
                                text = block.get("text", "")
                                # Only add significant text responses
                                if len(text) > 200:
                                    summary["timeline"].append({
                                        "time": timestamp,
                                        "type": "assistant_response",
                                        "preview": text[:100] + "..."
                                    })

        # Convert sets to lists
        summary["files_touched"]["read"] = sorted(list(summary["files_touched"]["read"]))
        summary["files_touched"]["written"] = sorted(list(summary["files_touched"]["written"]))
        summary["files_touched"]["edited"] = sorted(list(summary["files_touched"]["edited"]))

        # Determine final status
        if summary["total_messages"] > 0:
            summary["final_status"] = "completed"
        else:
            summary["final_status"] = "empty"

        # Limit timeline to most recent entries
        summary["timeline"] = summary["timeline"][-50:]

    except Exception as e:
        summary["error"] = str(e)
        summary["final_status"] = "error"

    return summary


def main():
    parser = argparse.ArgumentParser(description="Summarize a Claude Code session")
    parser.add_argument("--session-id", required=True, help="Session UUID to summarize")

    args = parser.parse_args()

    # Find session file
    session_file = find_session_file(args.session_id)

    if session_file is None:
        result = {
            "status": "error",
            "error": f"Session '{args.session_id}' not found",
            "session_id": args.session_id
        }
        print(json.dumps(result, indent=2))
        return 1

    summary = summarize_session(session_file)
    summary["status"] = "success"

    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}), file=sys.stderr)
        sys.exit(1)
