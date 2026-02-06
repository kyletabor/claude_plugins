#!/usr/bin/env python3
"""
List recent Claude Code sessions with metadata.

Usage:
    python list_sessions.py --project claude-life-dev --days 7
    python list_sessions.py --project claude-life-dev --days 7 --limit 10

Output: JSON with session list including id, start/end time, duration, tools used, error count.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


def encode_project_path(project_name: str) -> str:
    """Convert project name to encoded path format.

    For simple names like 'claude-life-dev', search all project dirs.
    For full paths like '/home/orangepi/claude-life-dev', encode directly.
    """
    if project_name.startswith("/"):
        return project_name.replace("/", "-")
    return None  # Will search for matching dirs


def find_project_dir(project_name: str) -> Optional[Path]:
    """Find the project directory in ~/.claude/projects/"""
    claude_projects = Path.home() / ".claude" / "projects"

    if not claude_projects.exists():
        return None

    # If it's a full path, encode it directly
    encoded = encode_project_path(project_name)
    if encoded:
        project_dir = claude_projects / encoded
        if project_dir.exists():
            return project_dir
        return None

    # Search for matching project dirs - prefer exact match at end
    candidates = []
    for d in claude_projects.iterdir():
        if d.is_dir() and project_name in d.name:
            # Prefer dirs that end with the project name (exact match)
            if d.name.endswith(project_name):
                return d
            candidates.append(d)

    # Return first partial match if no exact match
    return candidates[0] if candidates else None


def get_session_metadata(session_file: Path) -> dict:
    """Extract metadata from a session file."""
    metadata = {
        "session_id": session_file.stem,
        "file_path": str(session_file),
        "file_size_kb": round(session_file.stat().st_size / 1024, 1),
        "start_time": None,
        "end_time": None,
        "duration_minutes": None,
        "message_count": 0,
        "user_messages": 0,
        "assistant_messages": 0,
        "tool_calls": 0,
        "tools_used": set(),
        "error_count": 0,
        "summary": None,
        "git_branch": None,
        "cwd": None,
    }

    first_timestamp = None
    last_timestamp = None

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

                # Track timestamps
                if timestamp:
                    if first_timestamp is None:
                        first_timestamp = timestamp
                    last_timestamp = timestamp

                # Also check snapshot timestamps
                if entry_type == "file-history-snapshot":
                    snap_ts = entry.get("snapshot", {}).get("timestamp")
                    if snap_ts:
                        if first_timestamp is None:
                            first_timestamp = snap_ts
                        last_timestamp = snap_ts

                # Count messages
                if entry_type == "user":
                    metadata["message_count"] += 1
                    metadata["user_messages"] += 1

                    # Check for tool results with errors
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_result":
                                result = str(block.get("content", "")).lower()
                                if "error" in result or "failed" in result:
                                    metadata["error_count"] += 1

                    # Get context info from first user message
                    if metadata["git_branch"] is None:
                        metadata["git_branch"] = entry.get("gitBranch")
                        metadata["cwd"] = entry.get("cwd")

                elif entry_type == "assistant":
                    metadata["message_count"] += 1
                    metadata["assistant_messages"] += 1

                    # Count tool calls
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_use":
                                metadata["tool_calls"] += 1
                                metadata["tools_used"].add(block.get("name", "unknown"))

                elif entry_type == "summary":
                    metadata["summary"] = entry.get("summary")

        # Parse timestamps
        if first_timestamp:
            metadata["start_time"] = first_timestamp
        if last_timestamp:
            metadata["end_time"] = last_timestamp

        if first_timestamp and last_timestamp:
            try:
                start = datetime.fromisoformat(first_timestamp.replace("Z", "+00:00"))
                end = datetime.fromisoformat(last_timestamp.replace("Z", "+00:00"))
                duration = end - start
                metadata["duration_minutes"] = round(duration.total_seconds() / 60, 1)
            except (ValueError, TypeError):
                pass

        # Convert set to list for JSON
        metadata["tools_used"] = sorted(list(metadata["tools_used"]))

    except Exception as e:
        metadata["error"] = str(e)

    return metadata


def main():
    parser = argparse.ArgumentParser(description="List recent Claude Code sessions")
    parser.add_argument("--project", required=True, help="Project name to filter sessions")
    parser.add_argument("--days", type=int, default=7, help="Number of days to look back")
    parser.add_argument("--limit", type=int, default=50, help="Maximum sessions to return")

    args = parser.parse_args()

    # Find project directory
    project_dir = find_project_dir(args.project)

    if project_dir is None:
        result = {
            "status": "error",
            "error": f"Project '{args.project}' not found in ~/.claude/projects/",
            "project": args.project,
            "sessions": []
        }
        print(json.dumps(result, indent=2))
        return 1

    # Calculate cutoff date
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    # Find all session files
    session_files = list(project_dir.glob("*.jsonl"))

    # Get metadata for each session
    sessions = []
    for session_file in session_files:
        # Quick filter by file modification time
        mtime = datetime.fromtimestamp(session_file.stat().st_mtime, tz=timezone.utc)
        if mtime < cutoff:
            continue

        metadata = get_session_metadata(session_file)

        # Filter by actual start time if available
        if metadata["start_time"]:
            try:
                start = datetime.fromisoformat(metadata["start_time"].replace("Z", "+00:00"))
                if start < cutoff:
                    continue
            except (ValueError, TypeError):
                pass

        sessions.append(metadata)

    # Sort by start time (newest first)
    sessions.sort(key=lambda x: x.get("start_time") or "", reverse=True)

    # Apply limit
    sessions = sessions[:args.limit]

    result = {
        "status": "success",
        "project": args.project,
        "project_dir": str(project_dir),
        "days": args.days,
        "limit": args.limit,
        "total_sessions": len(sessions),
        "sessions": sessions
    }

    print(json.dumps(result, indent=2, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}), file=sys.stderr)
        sys.exit(1)
