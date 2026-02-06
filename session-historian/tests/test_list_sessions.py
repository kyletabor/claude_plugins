#!/usr/bin/env python3
"""
Unit tests for list_sessions.py
"""

import json
import pytest
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


class TestListSessions:
    """Tests for list_sessions functionality."""

    def test_script_returns_error_for_nonexistent_project(self, temp_home_dir):
        """Verify script returns error for nonexistent project."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "list_sessions.py",
             "--project", "nonexistent-project-xyz", "--days", "1"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "error"
        assert "not found" in output["error"]

    def test_json_output_format_with_fixture(self, temp_home_dir):
        """Verify output structure using test fixtures."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "list_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "sessions" in output
        assert "total_sessions" in output
        # Should find our fixture sessions
        assert output["total_sessions"] >= 1, "Should find at least one session from fixtures"

    def test_sessions_have_required_fields(self, temp_home_dir):
        """Verify each session has required metadata fields."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "list_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert len(output["sessions"]) > 0, "Must have at least one session"

        session = output["sessions"][0]
        assert "session_id" in session
        assert "start_time" in session

    def test_limit_flag(self, temp_home_dir):
        """Test --limit flag restricts number of sessions."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "list_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "30", "--limit", "1"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert len(output["sessions"]) <= 1

    def test_project_dir_in_output(self, temp_home_dir):
        """Verify project_dir is included in output."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "list_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "project_dir" in output
        assert temp_home_dir["project_name"] in output["project_dir"]
