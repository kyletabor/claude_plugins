#!/usr/bin/env python3
"""
Unit tests for search_sessions.py
"""

import json
import pytest
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


class TestSearchSessions:
    """Tests for search_sessions functionality."""

    def test_script_returns_error_for_nonexistent_project(self, temp_home_dir):
        """Verify script returns error for nonexistent project."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "search_sessions.py",
             "--project", "nonexistent-project-xyz", "--days", "1"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "error"
        assert "not found" in output["error"]

    def test_json_output_format_with_fixture(self, temp_home_dir):
        """Verify output structure using fixtures."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "search_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "filters_applied" in output
        assert "sessions_searched" in output
        assert "matches" in output
        assert output["sessions_searched"] >= 1, "Should search at least one fixture session"

    def test_tool_filter(self, temp_home_dir):
        """Test filtering by tool usage."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "search_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7",
             "--tool", "Read"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        filters = output.get("filters_applied", {})
        assert "tool" in filters
        assert filters["tool"] == "Read"

    def test_has_errors_filter(self, temp_home_dir):
        """Test --has-errors flag returns only error sessions."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "search_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7",
             "--has-errors"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        # All matches should have errors (error_session.jsonl has errors)
        for match in output.get("matches", []):
            assert match.get("error_count", 0) > 0, "All matches should have errors when --has-errors is set"

    def test_limit_flag(self, temp_home_dir):
        """Test --limit restricts number of results."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "search_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7",
             "--limit", "1"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert len(output.get("matches", [])) <= 1

    def test_combined_filters(self, temp_home_dir):
        """Test multiple filters applied together."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "search_sessions.py",
             "--project", temp_home_dir["project_name"], "--days", "7",
             "--has-errors", "--limit", "5"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        filters = output.get("filters_applied", {})
        assert "has_errors" in filters
