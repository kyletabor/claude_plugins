# fable-mode — Spec (Tier M)

## Goal
Claude Code plugin encoding Fable 5's judgment habits as 4 skills + 2 hooks so Opus 4.8 approximates them. Approved design: Treehouse doc `a7cba178909bb047` (evidence: 270 Treehouse comments, 289 friction moments, 12 newsletter issues).

## Scope
- **In**: skills `precondition-check`, `executive-mode`, `last-screen`, `but-for-real` (each: SKILL.md + evals.md + memory.md); hooks `rendered-proof` + `session-exit-hygiene` (Stop hooks, bash); hook tests; plugin.json; marketplace.json entry; README.
- **Out**: friction-bench Opus±skill experiment (follow-on); deferred skills (correction-ledger, cross-model-reviewer, skills-gap-audit, overnight-agent, nightly-dreaming).

## Files
| File | Action |
|---|---|
| fable-mode/.claude-plugin/plugin.json | Create |
| fable-mode/skills/<name>/SKILL.md, evals.md, memory.md (×4) | Create |
| fable-mode/hooks/hooks.json, rendered-proof.sh, session-exit-hygiene.sh | Create |
| fable-mode/tests/test-hooks.sh (+ fixtures) | Create |
| fable-mode/README.md | Create |
| .claude-plugin/marketplace.json | Add entry v0.1.0 |

## Design
- **Skills** follow superpowers-style SKILL.md: trigger-rich frontmatter description, a hard rule, a short checklist, red-flag rationalization table. Each ships `evals.md` — binary pass/fail checks a **clean-context grader subagent** runs against a transcript/output sample — and `memory.md` (dated lessons, append-on-failure).
- **rendered-proof.sh** (Stop hook): parse transcript JSONL (path from hook stdin) for Edit/Write/MultiEdit on frontend files (`.tsx .jsx .css .html .vue .svelte`, or files under a `frontend|ui|components|pages|src/app` path) AND absence of screenshot evidence (playwright screenshot tool use, or `.png` written this session). Fire → block once with remediation message. Respect `stop_hook_active` to never loop.
- **session-exit-hygiene.sh** (Stop hook): if cwd is a git repo with uncommitted tracked changes → block once, list files, tell agent to commit or explicitly hand off. Respect `stop_hook_active`.
- Both hooks: warn-block once, never twice (Kyle-annoyance risk from pre-mortem); pure bash+jq; exit 0 with JSON decision per hooks API.

## Current State Verification
- marketplace.json read in-session (13 plugins registered; schema + version-match rule confirmed).
- verification-hooks/ read in-session: hooks/hooks.json + *.sh pattern, plugin.json with author-as-object — used as template.
- Repo CLAUDE.md workflow read: version bump both files, validate-marketplace.sh, fresh-session cache fetch.

## Dependency Verification
| Dependency | Assumed Capability | Verified | Source |
|---|---|---|---|
| jq (system) | JSON parse in hook scripts | yes — used by verification-hooks/hooks/*.sh today | /usr/bin/jq |
No node_modules / external packages.

## Acceptance Criteria (executable)
- R1–R4 (one per skill): `skills/<name>/SKILL.md` exists with description containing trigger phrases; `evals.md` has ≥4 binary checks; a clean-context grader subagent given the skill + a test scenario returns PASS on all checks.
- R5: `bash fable-mode/tests/test-hooks.sh` exits 0 — covers fire + no-fire + stop_hook_active paths for both hooks against fixture transcripts/repos.
- R6 (GATE plugin-installed): fresh tmux Claude session → `/plugin install fable-mode@kyle-plugins` → skills listed; evidence pasted in bead.

## Test Requirements
- Hook tests: ≥6 assertions (3 per hook) in test-hooks.sh, runnable standalone.
- Skill evals: 4 × ≥4 binary checks, grader-run before close.
