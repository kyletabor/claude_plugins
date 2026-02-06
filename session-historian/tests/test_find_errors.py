#!/usr/bin/env python3
"""
Unit tests for find_errors.py
"""

import json
import pytest
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


class TestFindErrors:
    """Tests for find_errors functionality."""

    def test_script_returns_error_for_nonexistent_project(self, temp_home_dir):
        """Verify script returns error for nonexistent project."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "find_errors.py",
             "--project", "nonexistent-xyz-project", "--days", "1"],
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
            [sys.executable, SCRIPTS_DIR / "find_errors.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "total_sessions" in output
        assert "error_rate" in output
        assert "patterns" in output
        assert output["total_sessions"] >= 1, "Should analyze at least one fixture session"

    def test_error_detection_from_fixture(self, temp_home_dir):
        """Verify errors are detected from error_session.jsonl fixture."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "find_errors.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        # error_session.jsonl contains errors, so error_rate should be > 0
        # At least one session should have errors
        assert output["sessions_with_errors"] >= 1, "Should detect errors from error_session.jsonl"

    def test_error_categorization(self, temp_home_dir):
        """Verify errors are categorized properly."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "find_errors.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        # If there are patterns, verify structure
        if output.get("patterns"):
            for pattern in output["patterns"]:
                assert "category" in pattern
                assert "count" in pattern
                assert pattern["count"] >= 1, "Pattern count should be at least 1"

    def test_sessions_list_included(self, temp_home_dir):
        """Verify sessions list is included in output."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "find_errors.py",
             "--project", temp_home_dir["project_name"], "--days", "7"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        assert "affected_sessions" in output
        assert len(output["affected_sessions"]) >= 1, "Should include at least one session"
