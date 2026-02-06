#!/usr/bin/env python3
"""
Flexible session search with composable filters.

Usage:
    python search_sessions.py --project claude-life-dev --days 7 --text "WebSocket"
    python search_sessions.py --tool "gh" --command "/feat" --has-errors
    python search_sessions.py --file "gateway.ts" --min-duration 30

Available filters:
    --project       Filter by project name
    --days          Limit to last N days
    --text          Full-text search in messages
    --tool          Sessions that used specific tool
    --command       Sessions that ran specific command
    --file          Sessions that touched specific file
    --min-duration  Minimum session duration (minutes)
    --has-errors    Only sessions with errors
    --has-pr        Only sessions that touched PRs

Output: JSON with matching sessions and match context.
"""

import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional


def find_project_dirs(project_name: Optional[str] = None) -> List[Path]:
    """Find project directories, optionally filtered by name."""
    claude_projects = Path.home() / ".claude" / "projects"

    if not claude_projects.exists():
        return []

    if project_name is None:
        return [d for d in claude_projects.iterdir() if d.is_dir()]

    if project_name.startswith("/"):
        encoded = project_name.replace("/", "-")
        project_dir = claude_projects / encoded
        return [project_dir] if project_dir.exists() else []

    # Prefer exact match at end
    matches = []
    for d in claude_projects.iterdir():
        if d.is_dir() and project_name in d.name:
            if d.name.endswith(project_name):
                return [d]
            matches.append(d)

    return matches


def search_session(session_file: Path, filters: dict) -> Optional[dict]:
    """Search a single session file and return match info if it matches all filters."""
    match_info = {
        "session_id": session_file.stem,
        "file_path": str(session_file),
        "matches": [],
        "start_time": None,
        "end_time": None,
        "duration_minutes": None,
        "error_count": 0,
        "tool_calls": 0,
        "has_pr": False,
    }

    text_pattern = filters.get("text")
    tool_filter = filters.get("tool")
    command_filter = filters.get("command")
    file_filter = filters.get("file")
    min_duration = filters.get("min_duration")
    has_errors = filters.get("has_errors")
    has_pr = filters.get("has_pr")

    text_matched = text_pattern is None
    tool_matched = tool_filter is None
    command_matched = command_filter is None
    file_matched = file_filter is None

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
                    if match_info["start_time"] is None:
                        match_info["start_time"] = timestamp
                    match_info["end_time"] = timestamp

                # Text search in user messages
                if entry_type == "user" and text_pattern:
                    content = entry.get("message", {}).get("content", "")
                    if isinstance(content, str) and text_pattern.lower() in content.lower():
                        text_matched = True
                        match_info["matches"].append({
                            "type": "text",
                            "location": "user_message",
                            "preview": content[:100]
                        })

                # Check for errors
                if entry_type == "user":
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_result":
                                result = str(block.get("content", "")).lower()
                                if "error" in result or "failed" in result:
                                    match_info["error_count"] += 1

                # Text search in assistant messages
                if entry_type == "assistant":
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "text" and text_pattern:
                                text = block.get("text", "")
                                if text_pattern.lower() in text.lower():
                                    text_matched = True
                                    match_info["matches"].append({
                                        "type": "text",
                                        "location": "assistant_message",
                                        "preview": text[:100]
                                    })

                            if block.get("type") == "tool_use":
                                match_info["tool_calls"] += 1
                                tool_name = block.get("name", "")
                                tool_input = block.get("input", {})

                                # Tool filter
                                if tool_filter and tool_filter.lower() in tool_name.lower():
                                    tool_matched = True
                                    match_info["matches"].append({
                                        "type": "tool",
                                        "tool": tool_name,
                                        "input_preview": str(tool_input)[:100]
                                    })

                                # Command filter (look for slash commands in Bash or user messages)
                                if command_filter and tool_name == "Bash":
                                    cmd = tool_input.get("command", "")
                                    if command_filter in cmd:
                                        command_matched = True
                                        match_info["matches"].append({
                                            "type": "command",
                                            "command": cmd[:100]
                                        })

                                # File filter
                                if file_filter:
                                    file_path = tool_input.get("file_path", "")
                                    if file_filter in file_path:
                                        file_matched = True
                                        match_info["matches"].append({
                                            "type": "file",
                                            "operation": tool_name,
                                            "file": file_path
                                        })

                                # PR detection
                                if tool_name == "Bash":
                                    cmd = tool_input.get("command", "")
                                    if "gh pr" in cmd or "git push" in cmd:
                                        match_info["has_pr"] = True

        # Calculate duration
        if match_info["start_time"] and match_info["end_time"]:
            try:
                start = datetime.fromisoformat(match_info["start_time"].replace("Z", "+00:00"))
                end = datetime.fromisoformat(match_info["end_time"].replace("Z", "+00:00"))
                match_info["duration_minutes"] = round((end - start).total_seconds() / 60, 1)
            except (ValueError, TypeError):
                pass

        # Apply filters
        if not text_matched:
            return None
        if not tool_matched:
            return None
        if not command_matched:
            return None
        if not file_matched:
            return None
        if min_duration and (match_info["duration_minutes"] or 0) < min_duration:
            return None
        if has_errors and match_info["error_count"] == 0:
            return None
        if has_pr and not match_info["has_pr"]:
            return None

        return match_info

    except Exception as e:
        return None


def main():
    parser = argparse.ArgumentParser(description="Search Claude Code sessions")
    parser.add_argument("--project", help="Project name to filter")
    parser.add_argument("--days", type=int, default=7, help="Number of days to look back")
    parser.add_argument("--text", help="Full-text search in messages")
    parser.add_argument("--tool", help="Filter by tool usage")
    parser.add_argument("--command", help="Filter by command executed")
    parser.add_argument("--file", help="Filter by file touched")
    parser.add_argument("--min-duration", type=int, help="Minimum session duration in minutes")
    parser.add_argument("--has-errors", action="store_true", help="Only sessions with errors")
    parser.add_argument("--has-pr", action="store_true", help="Only sessions that touched PRs")
    parser.add_argument("--limit", type=int, default=20, help="Maximum results to return")

    args = parser.parse_args()

    # Build filters dict
    filters = {
        "text": args.text,
        "tool": args.tool,
        "command": args.command,
        "file": args.file,
        "min_duration": args.min_duration,
        "has_errors": args.has_errors,
        "has_pr": args.has_pr,
    }

    # Find project directories
    project_dirs = find_project_dirs(args.project)

    if not project_dirs:
        result = {
            "status": "error",
            "error": f"No projects found" + (f" matching '{args.project}'" if args.project else ""),
            "matches": []
        }
        print(json.dumps(result, indent=2))
        return 1

    # Calculate cutoff date
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    # Search all sessions
    matches = []
    sessions_searched = 0

    for project_dir in project_dirs:
        for session_file in project_dir.glob("*.jsonl"):
            # Quick filter by modification time
            mtime = datetime.fromtimestamp(session_file.stat().st_mtime, tz=timezone.utc)
            if mtime < cutoff:
                continue

            sessions_searched += 1
            match_info = search_session(session_file, filters)
            if match_info:
                match_info["project_dir"] = str(project_dir)
                matches.append(match_info)

    # Sort by start time (newest first)
    matches.sort(key=lambda x: x.get("start_time") or "", reverse=True)

    # Apply limit
    matches = matches[:args.limit]

    result = {
        "status": "success",
        "filters_applied": {k: v for k, v in filters.items() if v},
        "days": args.days,
        "sessions_searched": sessions_searched,
        "total_matches": len(matches),
        "matches": matches
    }

    print(json.dumps(result, indent=2, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}), file=sys.stderr)
        sys.exit(1)
