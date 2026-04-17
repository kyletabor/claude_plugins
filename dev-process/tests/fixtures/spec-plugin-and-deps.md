# Dummy Combined Spec

## Goal
Plugin with external deps.

## Files to Modify / Create

| File | Action | Purpose |
|---|---|---|
| `~/projects/claude_plugins/combo-plugin/scripts/run.sh` | Create | Runner |

## Dependency Verification

| Dependency | Assumed Capability | Verified At Source? | Source Path |
|---|---|---|---|
| `jq` | filter arrays | YES | `/usr/bin/jq` |

## Acceptance Criteria (Executable)
- When run, plugin loads.
