#!/usr/bin/env python3
"""
Get full context for deep debugging of a specific session.

Usage:
    python get_session_context.py --session-id <uuid>
    python get_session_context.py --session-id <uuid> --include-messages

Output: Complete session data including message content when --include-messages is set.
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


def get_session_context(session_file: Path, include_messages: bool = False) -> dict:
    """Extract full context from a session for debugging."""
    context = {
        "session_id": session_file.stem,
        "file_path": str(session_file),
        "file_size_kb": round(session_file.stat().st_size / 1024, 1),
        "metadata": {
            "start_time": None,
            "end_time": None,
            "duration_minutes": None,
            "cwd": None,
            "git_branch": None,
            "version": None,
            "session_summary": None,
        },
        "statistics": {
            "total_entries": 0,
            "user_messages": 0,
            "assistant_messages": 0,
            "tool_calls": 0,
            "tool_results": 0,
            "errors": 0,
            "summaries": 0,
            "snapshots": 0,
            "parse_warnings": 0,  # Track skipped lines
        },
        "tool_calls": [],
        "tool_results": [],
        "errors": [],
        "messages": [],
        "messages_included": include_messages,
    }

    try:
        from datetime import datetime

        with open(session_file, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    context["statistics"]["parse_warnings"] += 1
                    continue

                context["statistics"]["total_entries"] += 1
                entry_type = entry.get("type")
                timestamp = entry.get("timestamp")

                # Track times
                if timestamp:
                    if context["metadata"]["start_time"] is None:
                        context["metadata"]["start_time"] = timestamp
                    context["metadata"]["end_time"] = timestamp

                # Handle different entry types
                if entry_type == "summary":
                    context["statistics"]["summaries"] += 1
                    context["metadata"]["session_summary"] = entry.get("summary")

                elif entry_type == "file-history-snapshot":
                    context["statistics"]["snapshots"] += 1

                elif entry_type == "user":
                    context["statistics"]["user_messages"] += 1

                    # Get metadata from first user message
                    if context["metadata"]["cwd"] is None:
                        context["metadata"]["cwd"] = entry.get("cwd")
                        context["metadata"]["git_branch"] = entry.get("gitBranch")
                        context["metadata"]["version"] = entry.get("version")

                    content = entry.get("message", {}).get("content", "")

                    # Check for tool results
                    if isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_result":
                                context["statistics"]["tool_results"] += 1
                                result_content = str(block.get("content", ""))

                                tool_result = {
                                    "timestamp": timestamp,
                                    "tool_use_id": block.get("tool_use_id"),
                                    "is_error": "error" in result_content.lower() or "failed" in result_content.lower(),
                                    "content_preview": result_content[:500] + ("..." if len(result_content) > 500 else ""),
                                }

                                if tool_result["is_error"]:
                                    context["statistics"]["errors"] += 1
                                    context["errors"].append(tool_result)

                                context["tool_results"].append(tool_result)

                    # Include messages if requested
                    if include_messages:
                        if isinstance(content, str) and content:
                            context["messages"].append({
                                "timestamp": timestamp,
                                "role": "user",
                                "content": content,
                            })
                        elif isinstance(content, list):
                            # Extract text content from list-format messages
                            text_parts = []
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "text":
                                    text_parts.append(block.get("text", ""))
                            if text_parts:
                                context["messages"].append({
                                    "timestamp": timestamp,
                                    "role": "user",
                                    "content": " ".join(text_parts),
                                })

                elif entry_type == "assistant":
                    context["statistics"]["assistant_messages"] += 1
                    content = entry.get("message", {}).get("content", [])

                    if isinstance(content, list):
                        for block in content:
                            block_type = block.get("type")

                            if block_type == "tool_use":
                                context["statistics"]["tool_calls"] += 1
                                tool_call = {
                                    "timestamp": timestamp,
                                    "id": block.get("id"),
                                    "name": block.get("name"),
                                    "input": block.get("input", {}),
                                }
                                context["tool_calls"].append(tool_call)

                            elif block_type == "text" and include_messages:
                                text = block.get("text", "")
                                if text:
                                    context["messages"].append({
                                        "timestamp": timestamp,
                                        "role": "assistant",
                                        "content": text[:2000] + ("..." if len(text) > 2000 else ""),
                                    })

        # Calculate duration
        if context["metadata"]["start_time"] and context["metadata"]["end_time"]:
            try:
                start = datetime.fromisoformat(context["metadata"]["start_time"].replace("Z", "+00:00"))
                end = datetime.fromisoformat(context["metadata"]["end_time"].replace("Z", "+00:00"))
                context["metadata"]["duration_minutes"] = round((end - start).total_seconds() / 60, 1)
            except (ValueError, TypeError):
                pass

        # Limit lists to prevent massive output
        context["tool_calls"] = context["tool_calls"][-100:]
        context["tool_results"] = context["tool_results"][-100:]
        context["errors"] = context["errors"][-50:]
        if include_messages:
            context["messages"] = context["messages"][-100:]

    except Exception as e:
        context["parse_error"] = f"{type(e).__name__}: {str(e)}"

    return context


def main():
    parser = argparse.ArgumentParser(description="Get full session context for debugging")
    parser.add_argument("--session-id", required=True, help="Session UUID to analyze")
    parser.add_argument("--include-messages", action="store_true",
                        help="Include full message content (verbose)")

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

    context = get_session_context(session_file, args.include_messages)
    context["status"] = "success"

    print(json.dumps(context, indent=2, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}), file=sys.stderr)
        sys.exit(1)
