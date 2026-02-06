#!/usr/bin/env python3
"""
Analyze patterns across multiple sessions.

Usage:
    python cross_session_analysis.py --project claude-life-dev --days 7 --focus failures
    python cross_session_analysis.py --project claude-life-dev --days 14 --focus tools
    python cross_session_analysis.py --project claude-life-dev --days 7 --focus duration

Focus options:
    failures  - Analyze failure patterns and success rates
    tools     - Analyze tool usage patterns
    duration  - Analyze session duration patterns
    commands  - Analyze command usage patterns

Output: Statistics on success rates, common patterns, failure hotspots.
"""

import argparse
import json
import statistics
import sys
from collections import Counter, defaultdict
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

    for d in claude_projects.iterdir():
        if d.is_dir() and d.name.endswith(project_name):
            return d

    for d in claude_projects.iterdir():
        if d.is_dir() and project_name in d.name:
            return d

    return None


def analyze_session(session_file: Path) -> dict:
    """Analyze a single session for cross-session analysis."""
    analysis = {
        "session_id": session_file.stem,
        "start_time": None,
        "end_time": None,
        "duration_minutes": None,
        "tool_counts": Counter(),
        "error_count": 0,
        "message_count": 0,
        "commands": [],
        "has_errors": False,
        "git_branch": None,
        "parse_warnings": 0,  # Track skipped lines
        "parse_error": None,  # Track file-level errors
    }

    try:
        with open(session_file, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    analysis["parse_warnings"] += 1
                    continue

                entry_type = entry.get("type")
                timestamp = entry.get("timestamp")

                if timestamp:
                    if analysis["start_time"] is None:
                        analysis["start_time"] = timestamp
                    analysis["end_time"] = timestamp

                if entry_type == "user":
                    analysis["message_count"] += 1
                    if analysis["git_branch"] is None:
                        analysis["git_branch"] = entry.get("gitBranch")

                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_result":
                                result = str(block.get("content", "")).lower()
                                if "error" in result or "failed" in result:
                                    analysis["error_count"] += 1
                                    analysis["has_errors"] = True

                elif entry_type == "assistant":
                    analysis["message_count"] += 1
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_use":
                                tool_name = block.get("name", "unknown")
                                analysis["tool_counts"][tool_name] += 1

                                if tool_name == "Bash":
                                    cmd = block.get("input", {}).get("command", "")
                                    # Extract slash commands or git/gh commands
                                    if cmd.startswith("/") or cmd.startswith("gh ") or cmd.startswith("git "):
                                        analysis["commands"].append(cmd[:100])

        # Calculate duration
        if analysis["start_time"] and analysis["end_time"]:
            try:
                start = datetime.fromisoformat(analysis["start_time"].replace("Z", "+00:00"))
                end = datetime.fromisoformat(analysis["end_time"].replace("Z", "+00:00"))
                analysis["duration_minutes"] = round((end - start).total_seconds() / 60, 1)
            except (ValueError, TypeError):
                pass

    except Exception as e:
        analysis["parse_error"] = f"{type(e).__name__}: {str(e)}"

    return analysis


def analyze_failures(sessions: List[dict]) -> dict:
    """Analyze failure patterns across sessions."""
    total = len(sessions)
    with_errors = sum(1 for s in sessions if s["has_errors"])
    error_rate = with_errors / total if total > 0 else 0

    # Sessions with most errors
    error_sessions = sorted(
        [s for s in sessions if s["error_count"] > 0],
        key=lambda x: x["error_count"],
        reverse=True
    )[:10]

    # Error distribution by branch
    branch_errors = defaultdict(lambda: {"total": 0, "with_errors": 0})
    for s in sessions:
        branch = s["git_branch"] or "unknown"
        branch_errors[branch]["total"] += 1
        if s["has_errors"]:
            branch_errors[branch]["with_errors"] += 1

    branch_analysis = [
        {
            "branch": branch,
            "total_sessions": data["total"],
            "sessions_with_errors": data["with_errors"],
            "error_rate": round(data["with_errors"] / data["total"], 2) if data["total"] > 0 else 0,
        }
        for branch, data in sorted(branch_errors.items(), key=lambda x: x[1]["with_errors"], reverse=True)[:10]
    ]

    return {
        "total_sessions": total,
        "sessions_with_errors": with_errors,
        "error_rate": round(error_rate, 2),
        "worst_sessions": [
            {"session_id": s["session_id"], "error_count": s["error_count"], "branch": s["git_branch"]}
            for s in error_sessions
        ],
        "error_by_branch": branch_analysis,
    }


def analyze_tools(sessions: List[dict]) -> dict:
    """Analyze tool usage patterns across sessions."""
    total_tool_counts = Counter()
    sessions_using_tool = defaultdict(int)

    for s in sessions:
        for tool, count in s["tool_counts"].items():
            total_tool_counts[tool] += count
            sessions_using_tool[tool] += 1

    total_sessions = len(sessions)
    tool_analysis = [
        {
            "tool": tool,
            "total_calls": count,
            "sessions_using": sessions_using_tool[tool],
            "usage_rate": round(sessions_using_tool[tool] / total_sessions, 2) if total_sessions > 0 else 0,
            "avg_calls_per_session": round(count / sessions_using_tool[tool], 1) if sessions_using_tool[tool] > 0 else 0,
        }
        for tool, count in total_tool_counts.most_common(20)
    ]

    return {
        "total_sessions": total_sessions,
        "total_tool_calls": sum(total_tool_counts.values()),
        "unique_tools": len(total_tool_counts),
        "tool_usage": tool_analysis,
    }


def analyze_duration(sessions: List[dict]) -> dict:
    """Analyze session duration patterns."""
    durations = [s["duration_minutes"] for s in sessions if s["duration_minutes"] is not None]

    if not durations:
        return {"error": "No duration data available"}

    durations.sort()
    total = len(durations)

    # Bucket sessions by duration
    buckets = {
        "under_1min": 0,
        "1_to_5min": 0,
        "5_to_15min": 0,
        "15_to_30min": 0,
        "30_to_60min": 0,
        "over_60min": 0,
    }

    for d in durations:
        if d < 1:
            buckets["under_1min"] += 1
        elif d < 5:
            buckets["1_to_5min"] += 1
        elif d < 15:
            buckets["5_to_15min"] += 1
        elif d < 30:
            buckets["15_to_30min"] += 1
        elif d < 60:
            buckets["30_to_60min"] += 1
        else:
            buckets["over_60min"] += 1

    # Use statistics module for proper median calculation
    median = statistics.median(durations)

    # Proper 90th percentile calculation
    percentile_90 = None
    if total >= 10:
        # Use linear interpolation for percentile
        idx = 0.9 * (total - 1)
        lower = int(idx)
        upper = lower + 1
        if upper < total:
            percentile_90 = round(durations[lower] + (idx - lower) * (durations[upper] - durations[lower]), 1)
        else:
            percentile_90 = durations[lower]

    return {
        "total_sessions": total,
        "min_duration": min(durations),
        "max_duration": max(durations),
        "avg_duration": round(sum(durations) / total, 1),
        "median_duration": round(median, 1),
        "percentile_90": percentile_90,
        "duration_buckets": buckets,
    }


def analyze_commands(sessions: List[dict]) -> dict:
    """Analyze command usage patterns."""
    command_counts = Counter()
    for s in sessions:
        for cmd in s["commands"]:
            # Extract the base command
            if cmd.startswith("/"):
                base = cmd.split()[0] if " " in cmd else cmd
                command_counts[base] += 1
            elif "gh pr" in cmd:
                command_counts["gh pr"] += 1
            elif "gh issue" in cmd:
                command_counts["gh issue"] += 1
            elif "git " in cmd:
                parts = cmd.split()
                if len(parts) >= 2:
                    command_counts[f"git {parts[1]}"] += 1

    return {
        "total_sessions": len(sessions),
        "sessions_with_commands": sum(1 for s in sessions if s["commands"]),
        "command_frequency": [
            {"command": cmd, "count": count}
            for cmd, count in command_counts.most_common(20)
        ],
    }


def main():
    parser = argparse.ArgumentParser(description="Cross-session pattern analysis")
    parser.add_argument("--project", required=True, help="Project name to analyze")
    parser.add_argument("--days", type=int, default=7, help="Number of days to analyze")
    parser.add_argument("--focus", choices=["failures", "tools", "duration", "commands"],
                        default="failures", help="Analysis focus area")

    args = parser.parse_args()

    # Find project directory
    project_dir = find_project_dir(args.project)

    if project_dir is None:
        result = {
            "status": "error",
            "error": f"Project '{args.project}' not found",
            "project": args.project
        }
        print(json.dumps(result, indent=2))
        return 1

    # Calculate cutoff date
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    # Analyze all sessions
    sessions = []
    for session_file in project_dir.glob("*.jsonl"):
        mtime = datetime.fromtimestamp(session_file.stat().st_mtime, tz=timezone.utc)
        if mtime < cutoff:
            continue

        analysis = analyze_session(session_file)
        if analysis["start_time"]:  # Only include sessions with data
            sessions.append(analysis)

    if not sessions:
        result = {
            "status": "error",
            "error": f"No sessions found in last {args.days} days",
            "project": args.project
        }
        print(json.dumps(result, indent=2))
        return 1

    # Run focused analysis
    if args.focus == "failures":
        analysis_result = analyze_failures(sessions)
    elif args.focus == "tools":
        analysis_result = analyze_tools(sessions)
    elif args.focus == "duration":
        analysis_result = analyze_duration(sessions)
    elif args.focus == "commands":
        analysis_result = analyze_commands(sessions)

    result = {
        "status": "success",
        "project": args.project,
        "project_dir": str(project_dir),
        "days": args.days,
        "focus": args.focus,
        "sessions_analyzed": len(sessions),
        "analysis": analysis_result,
    }

    print(json.dumps(result, indent=2, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}), file=sys.stderr)
        sys.exit(1)
