#!/usr/bin/env python3
"""
Unit tests for summarize_session.py
"""

import json
import pytest
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


class TestSummarizeSession:
    """Tests for summarize_session functionality."""

    def test_script_returns_error_for_nonexistent_session(self, temp_home_dir):
        """Verify script returns error for nonexistent session."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "summarize_session.py",
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
        # Use the known session ID from fixture
        session_id = temp_home_dir["session_ids"][0]  # "test-session-001"

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "summarize_session.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "timeline" in output
        assert "tools_used" in output
        assert "files_touched" in output

    def test_timeline_structure(self, temp_home_dir):
        """Verify timeline entries have expected fields."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "summarize_session.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert len(output["timeline"]) >= 1, "Timeline should have at least one entry"

        entry = output["timeline"][0]
        assert "time" in entry or "type" in entry

    def test_tools_used_detection(self, temp_home_dir):
        """Verify tools are detected from fixture session."""
        session_id = temp_home_dir["session_ids"][0]

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "summarize_session.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        # simple_session.jsonl has Bash tool call (git status)
        assert "Bash" in output["tools_used"], "Should detect Bash tool from fixture"

    def test_error_session_summarization(self, temp_home_dir):
        """Verify error session can be summarized."""
        session_id = temp_home_dir["session_ids"][1]  # "error-session-001"

        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "summarize_session.py",
             "--session-id", session_id],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "timeline" in output
