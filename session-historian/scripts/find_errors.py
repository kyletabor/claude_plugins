#!/usr/bin/env python3
"""
Find error patterns across sessions.

Usage:
    python find_errors.py --project claude-life-dev --days 3

Output: JSON with error list, patterns, affected sessions, error rates.
"""

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional


def find_project_dir(project_name: str) -> Optional[Path]:
    """Find the project directory in ~/.claude/projects/"""
    claude_projects = Path.home() / ".claude" / "projects"

    if not claude_projects.exists():
        return None

    if project_name.startswith("/"):
        encoded = project_name.replace("/", "-")
        project_dir = claude_projects / encoded
        return project_dir if project_dir.exists() else None

    # Prefer exact match at end
    for d in claude_projects.iterdir():
        if d.is_dir() and d.name.endswith(project_name):
            return d

    # Fallback to partial match
    for d in claude_projects.iterdir():
        if d.is_dir() and project_name in d.name:
            return d

    return None


def categorize_error(error_content: str) -> str:
    """Categorize an error based on its content."""
    content_lower = error_content.lower()

    if "permission denied" in content_lower:
        return "permission_error"
    if "no such file" in content_lower or "not found" in content_lower:
        return "file_not_found"
    if "command not found" in content_lower:
        return "command_not_found"
    if "syntax error" in content_lower:
        return "syntax_error"
    if "timeout" in content_lower:
        return "timeout"
    if "connection" in content_lower and ("refused" in content_lower or "failed" in content_lower):
        return "connection_error"
    if "exit code" in content_lower or "exited with" in content_lower:
        return "command_failed"
    if "json" in content_lower and ("parse" in content_lower or "decode" in content_lower):
        return "json_parse_error"
    if "type" in content_lower and "error" in content_lower:
        return "type_error"
    if "import" in content_lower and "error" in content_lower:
        return "import_error"

    return "other_error"


def find_errors_in_session(session_file: Path) -> dict:
    """Find all errors in a single session."""
    session_info = {
        "session_id": session_file.stem,
        "file_path": str(session_file),
        "errors": [],
        "error_count": 0,
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
                    if session_info["start_time"] is None:
                        session_info["start_time"] = timestamp
                    session_info["end_time"] = timestamp

                # Check tool results for errors
                if entry_type == "user":
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_result":
                                result = str(block.get("content", ""))
                                result_lower = result.lower()

                                # Check for error indicators
                                if "error" in result_lower or "failed" in result_lower or "exception" in result_lower:
                                    tool_use_id = block.get("tool_use_id", "")
                                    category = categorize_error(result)

                                    session_info["errors"].append({
                                        "timestamp": timestamp,
                                        "tool_use_id": tool_use_id,
                                        "category": category,
                                        "preview": result[:300] + ("..." if len(result) > 300 else ""),
                                    })
                                    session_info["error_count"] += 1

    except Exception as e:
        session_info["parse_error"] = str(e)

    return session_info


def main():
    parser = argparse.ArgumentParser(description="Find errors across Claude Code sessions")
    parser.add_argument("--project", required=True, help="Project name to analyze")
    parser.add_argument("--days", type=int, default=3, help="Number of days to look back")

    args = parser.parse_args()

    # Find project directory
    project_dir = find_project_dir(args.project)

    if project_dir is None:
        result = {
            "status": "error",
            "error": f"Project '{args.project}' not found in ~/.claude/projects/",
            "project": args.project,
            "errors": []
        }
        print(json.dumps(result, indent=2))
        return 1

    # Calculate cutoff date
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    # Collect errors from all sessions
    all_errors = []
    affected_sessions = []
    total_sessions = 0
    sessions_with_errors = 0

    for session_file in project_dir.glob("*.jsonl"):
        # Quick filter by modification time
        mtime = datetime.fromtimestamp(session_file.stat().st_mtime, tz=timezone.utc)
        if mtime < cutoff:
            continue

        total_sessions += 1
        session_info = find_errors_in_session(session_file)

        if session_info["error_count"] > 0:
            sessions_with_errors += 1
            affected_sessions.append({
                "session_id": session_info["session_id"],
                "error_count": session_info["error_count"],
                "start_time": session_info["start_time"],
            })

            for error in session_info["errors"]:
                error["session_id"] = session_info["session_id"]
                all_errors.append(error)

    # Categorize errors
    error_categories = Counter(e["category"] for e in all_errors)

    # Find common patterns
    patterns = []
    for category, count in error_categories.most_common(10):
        # Get example errors for this category
        examples = [e for e in all_errors if e["category"] == category][:3]
        patterns.append({
            "category": category,
            "count": count,
            "examples": [e["preview"][:100] for e in examples],
        })

    # Calculate error rate
    error_rate = sessions_with_errors / total_sessions if total_sessions > 0 else 0

    # Sort errors by timestamp (most recent first)
    all_errors.sort(key=lambda x: x.get("timestamp") or "", reverse=True)

    result = {
        "status": "success",
        "project": args.project,
        "project_dir": str(project_dir),
        "days": args.days,
        "total_sessions": total_sessions,
        "sessions_with_errors": sessions_with_errors,
        "error_rate": round(error_rate, 2),
        "total_errors": len(all_errors),
        "patterns": patterns,
        "affected_sessions": affected_sessions[:20],
        "recent_errors": all_errors[:50],
    }

    print(json.dumps(result, indent=2, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}), file=sys.stderr)
        sys.exit(1)
