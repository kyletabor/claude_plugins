#!/usr/bin/env python3
"""
Shared pytest fixtures for session-historian tests.
"""

import json
import os
import pytest
import tempfile
import shutil
from pathlib import Path


@pytest.fixture
def fixtures_dir():
    """Return the path to test fixtures directory."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def simple_session_file(fixtures_dir):
    """Return path to simple_session.jsonl fixture."""
    return fixtures_dir / "simple_session.jsonl"


@pytest.fixture
def error_session_file(fixtures_dir):
    """Return path to error_session.jsonl fixture."""
    return fixtures_dir / "error_session.jsonl"


@pytest.fixture
def temp_home_dir(fixtures_dir):
    """
    Create a temporary HOME directory with .claude/projects/ structure.

    This fixture:
    1. Creates a temp dir to use as HOME
    2. Creates .claude/projects/-home-test-project/ inside it
    3. Copies fixture session files into the project dir
    4. Returns a dict with paths and environment
    """
    temp_base = Path(tempfile.mkdtemp())

    # Create project directory structure
    # Project name encodes as "-home-test-project" for "/home/test/project"
    projects_dir = temp_base / ".claude" / "projects"
    project_dir = projects_dir / "-home-test-project"
    project_dir.mkdir(parents=True)

    # Copy fixture files with different names to test various scenarios
    shutil.copy(fixtures_dir / "simple_session.jsonl", project_dir / "test-session-001.jsonl")
    shutil.copy(fixtures_dir / "error_session.jsonl", project_dir / "error-session-001.jsonl")

    # Also create a second simple session for multi-session tests
    shutil.copy(fixtures_dir / "simple_session.jsonl", project_dir / "test-session-002.jsonl")

    # Create environment dict for subprocess calls
    env = os.environ.copy()
    env["HOME"] = str(temp_base)

    result = {
        "home": temp_base,
        "projects_dir": projects_dir,
        "project_dir": project_dir,
        "project_name": "test-project",  # Matches "-home-test-project"
        "env": env,
        "session_ids": ["test-session-001", "error-session-001", "test-session-002"],
    }

    yield result

    # Cleanup
    shutil.rmtree(temp_base)


@pytest.fixture
def sample_session_data(fixtures_dir):
    """Return parsed data from simple_session.jsonl."""
    entries = []
    with open(fixtures_dir / "simple_session.jsonl") as f:
        for line in f:
            if line.strip():
                entries.append(json.loads(line))
    return entries
