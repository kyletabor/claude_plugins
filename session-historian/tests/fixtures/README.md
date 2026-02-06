# Test Fixtures

This directory contains sample JSONL session files for testing.

## Available Fixture Files

| File | Purpose |
|------|---------|
| `simple_session.jsonl` | Basic session with user/assistant messages |
| `error_session.jsonl` | Session with errors for error-finding tests |

## Fixture Contents

- **simple_session.jsonl**: A standard session demonstrating typical user queries and assistant responses
- **error_session.jsonl**: A session containing error messages and edge cases for testing error detection functionality

## Usage in Tests

```python
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures"

def test_example():
    session_file = FIXTURES_DIR / "simple_session.jsonl"
    # ... test logic
```
