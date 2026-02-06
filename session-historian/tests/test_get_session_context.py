#!/usr/bin/env python3
"""
Unit tests for get_session_context.py
"""

import json
import pytest
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


class TestGetSessionContext:
    """Tests for get_session_context functionality."""

    def test_script_returns_error_for_nonexistent_session(self, temp_home_dir):
        """Verify script returns error for nonexistent session."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", "nonexistent-session-id"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "error"
        assert "not found" in output["error"]

    def test_json_output_format_with_fixture(self, temp_home_dir):
        """Verify output structure for fixture session."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "metadata" in output
        assert "statistics" in output
        assert "tool_calls" in output

    def test_metadata_fields(self, temp_home_dir):
        """Verify metadata contains expected fields."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        metadata = output["metadata"]
        assert "start_time" in metadata
        assert "cwd" in metadata
        assert "git_branch" in metadata

    def test_statistics_populated(self, temp_home_dir):
        """Verify statistics are populated from fixture."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        stats = output["statistics"]
        assert stats["total_entries"] >= 1, "Should have at least one entry"
        assert stats["user_messages"] >= 1, "Should have at least one user message"

    def test_include_messages_flag(self, temp_home_dir):
        """Verify --include-messages flag works."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", session_id, "--include-messages"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert output["messages_included"] is True
        assert "messages" in output

    def test_tool_calls_detected(self, temp_home_dir):
        """Verify tool calls are detected from fixture."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        # simple_session.jsonl has a Bash tool call (git status)
        assert len(output["tool_calls"]) >= 1, "Should detect at least one tool call"
        assert output["tool_calls"][0]["name"] == "Bash"

    def test_parse_warnings_tracked(self, temp_home_dir):
        """Verify parse_warnings field exists in statistics."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "get_session_context.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "parse_warnings" in output["statistics"]
