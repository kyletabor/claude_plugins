# Dummy Spec With Deps

## Goal
Add a feature that relies on external libs.

## Files to Modify / Create

| File | Action | Purpose |
|---|---|---|
| `/tmp/example/src/feature.ts` | Create | Feature impl |

## Dependency Verification

| Dependency | Assumed Capability | Verified At Source? | Source Path |
|---|---|---|---|
| `some-lib` | exports method X | YES | `node_modules/some-lib/index.js:L42` |

## Acceptance Criteria (Executable)
- When called, X works.
