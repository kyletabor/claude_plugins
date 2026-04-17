# Adding a Verification Gate

The Verification Suite is extensible by design: each recurring AI failure class that closes a CAPA should add one entry to the registry. This is a **YAML-free, JSON-only, config-only** change — no code edits required if you stay within the v1 trigger types.

## When to add a gate

Add a gate when:

- A CAPA identified a **recurring** failure mode (same root-cause category across ≥2 CAPAs).
- Prose-in-SKILL.md is already there and has failed to prevent recurrence (pattern: `skill_not_enforced`).
- You can write an **acceptance string** precise enough that a verifier can grep or programmatically check whether the evidence exists.

**Do NOT** add a gate for one-off failures, nice-to-haves, or advisory suggestions. Every gate slows down every future close; they should pay rent.

## The recipe

### 1. Pick a trigger type (v1 set)

| Type | Fires when… | Required fields |
|---|---|---|
| `always` | Every spec / every close | (none) |
| `spec_section_present` | The spec file has a named `## Section` with populated rows or bullets | `section` (string), `require_rows` (bool) |
| `paths_touched` | The spec or git diff contains any of the listed path prefixes | `match` (array of prefixes), `also_check_git_diff` (bool) |
| `bead_type` | The closing bead's `issue_type` matches | `issue_types` (array) |

If your rule doesn't fit any of these, extend `evaluate-gates.sh` by adding one `_trigger_<name>` function and a `case` arm in `_applicable_for_spec` and `_applicable_for_close`. Bump `schema_version`. Add tests.

### 2. Pick an `evidence_marker`

Unique, short, ALL-CAPS-with-colon string that appears in the corresponding closed GATE bead's notes. Examples: `VERIFIED:`, `SMOKE:`, `PREMORTEM:`. The hook uses `grep -F` against this marker — keep it distinct from common words.

### 3. Write the `acceptance` string

Precise, testable, under 200 chars. A verifier reading the acceptance should be able to produce (or check) the required evidence without further guidance.

Good: `Fresh tmux session id + /plugin install output + skill invocation output in VERIFIED note.`
Bad: `Plugin should work.`

### 4. Append the registry entry

Edit `~/projects/claude_plugins/dev-process/config/verification-gates.json`. Example:

```json
{
  "id": "tests-real-deps",
  "title": "GATE: Tests hit real dependencies",
  "description": "Integration tests run against real DB/API, not mocks.",
  "trigger": {
    "type": "spec_section_present",
    "section": "Test Requirements",
    "require_rows": true
  },
  "evidence_marker": "REAL-TEST:",
  "acceptance": "Integration test log path cited in VERIFIED note; log shows real-dep connection strings.",
  "source_capa": "CAPA-NN",
  "enabled": true
}
```

- `id` — kebab-case, unique, stable (downstream logs reference it).
- `title` — must start with `GATE:` (hook exemption matches on that prefix).
- `enabled: false` if you want to stage without activating.
- `source_capa` — cite the closing CAPA for audit traceability.

### 5. If you added a new trigger type, bump the schema

```json
{"schema_version": 2, "gates": [ ... ]}
```

And update `SCHEMA_VERSION_EXPECTED` in `evaluate-gates.sh`. The evaluator refuses a registry whose schema_version it doesn't recognize (fail-open, logs a warning).

### 6. Add re-exec tests

Add a test fixture (synthetic spec or bead scenario) under `~/projects/claude_plugins/dev-process/tests/fixtures/` and a corresponding assertion in `tests/gates/test_evaluator.sh`. Your gate should:

- Fire when its trigger condition is met
- Not fire when the condition is not met
- Have `--check-evidence` returning 2 when no closed GATE bead exists
- Have `--check-evidence` returning 0 when a closed GATE with the `evidence_marker` exists

Run the suite: `bash ~/projects/claude_plugins/dev-process/tests/gates/test_evaluator.sh`.

### 7. Confirm via `--list`

```bash
~/projects/claude_plugins/dev-process/scripts/evaluate-gates.sh --list
```

Your gate appears. Done — no other edits required.

### 8. Close the source CAPA referencing the new gate

In the CAPA DB, cite the new gate `id` as the `process_changes` entry that closes the CAPA.

## What you are NOT allowed to do

- **Do not add evidence-checking logic that executes shell strings from the registry.** All registry values are data; never pass them through `bash -c` or `eval`. (Security invariant, mirrors `dispatch-verifiers.sh` R3.)
- **Do not make gates fire on GATE: beads themselves.** The evaluator exempts them by title prefix to prevent cycles.
- **Do not edit the cache at `~/.claude/plugins/`.** Always edit the source at `~/projects/claude_plugins/dev-process/config/`. Bump the plugin version, commit, push — Claude Code's cache refreshes on next session.

## Philosophy

The Verification Suite turns each closed CAPA into a **standing check**. A CAPA that closes without adding a gate (or confirming an existing gate covers it) is not fully closed — the failure will recur. The registry is the codified memory of "things our agents have screwed up and we've built enforcement for."

Over time, the registry grows. So does the signal-to-noise ratio of our enforcement. That's the intended trajectory.
