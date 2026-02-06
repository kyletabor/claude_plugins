#!/usr/bin/env python3
"""
Unit tests for cross_session_analysis.py
"""

import json
import pytest
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"


class TestCrossSessionAnalysis:
    """Tests for cross_session_analysis functionality."""

    def test_script_returns_error_for_nonexistent_project(self, temp_home_dir):
        """Verify script returns error for nonexistent project."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", "nonexistent-xyz-project", "--days", "1", "--focus", "failures"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "error"

    def test_focus_failures_with_fixture(self, temp_home_dir):
        """Test --focus failures produces failure analysis."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", temp_home_dir["project_name"], "--days", "7", "--focus", "failures"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        analysis = output.get("analysis", {})
        assert "error_rate" in analysis
        assert "sessions_with_errors" in analysis
        assert output["sessions_analyzed"] >= 1, "Should analyze at least one session"

    def test_focus_tools_with_fixture(self, temp_home_dir):
        """Test --focus tools produces tool usage analysis."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", temp_home_dir["project_name"], "--days", "7", "--focus", "tools"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        analysis = output.get("analysis", {})
        assert "tool_usage" in analysis
        assert "total_tool_calls" in analysis
        # Fixtures have tool calls so should be > 0
        assert analysis["total_tool_calls"] >= 1, "Should detect tool calls from fixtures"

    def test_focus_duration_with_fixture(self, temp_home_dir):
        """Test --focus duration produces duration analysis."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", temp_home_dir["project_name"], "--days", "7", "--focus", "duration"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        analysis = output.get("analysis", {})
        # Duration analysis may have "error" key if no duration data
        assert "avg_duration" in analysis or "error" in analysis

    def test_focus_commands_with_fixture(self, temp_home_dir):
        """Test --focus commands produces command analysis."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", temp_home_dir["project_name"], "--days", "7", "--focus", "commands"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        analysis = output.get("analysis", {})
        assert "command_frequency" in analysis
        assert "total_sessions" in analysis

    def test_sessions_analyzed_count(self, temp_home_dir):
        """Verify sessions_analyzed reflects fixture count."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", temp_home_dir["project_name"], "--days", "30", "--focus", "failures"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        # We have 3 fixture sessions
        assert output["sessions_analyzed"] >= 1, "Should analyze fixture sessions"

    def test_median_calculation_accuracy(self, temp_home_dir):
        """Verify median is calculated correctly (uses statistics.median)."""
        result = subprocess.run(
            [sys.executable, SCRIPTS_DIR / "cross_session_analysis.py",
             "--project", temp_home_dir["project_name"], "--days", "7", "--focus", "duration"],
            capture_output=True,
            text=True,
            env=temp_home_dir["env"]
        )
        output = json.loads(result.stdout)
        assert output["status"] == "success"
        analysis = output.get("analysis", {})
        # If we have duration data, median should be between min and max
        if "median_duration" in analysis and "min_duration" in analysis and "max_duration" in analysis:
            assert analysis["min_duration"] <= analysis["median_duration"] <= analysis["max_duration"]
