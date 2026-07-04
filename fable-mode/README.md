# fable-mode

Fable 5's judgment habits, encoded as skills + hooks so weaker/cheaper models
(target: Opus 4.8) approximate them. Built 2026-07-03 from three evidence streams:
Kyle's 270 Treehouse doc comments, 289 mined friction moments, and the
Friction-Bench two-tier calibration (Haiku vs Fable 5). Design doc: Treehouse
`a7cba178909bb047`.

## Skills

| Skill | Habit it encodes | Evidence anchor |
|---|---|---|
| `precondition-check` | Verify what a suggestion rests on before saying it; check premises embedded in requests | Jun 25 stoplist incident; Friction-Bench ua-001 (weaker tier believed a false premise 2/3, Fable 3/3) |
| `executive-mode` | Classify the turn (question/jam/command), act over ask, clean handbacks | "I don't want to be a gate"; "I do not have time to babysit you" |
| `last-screen` | Answer-first, one screen, ELI5 close, jargon defined at first use + care-verdict | "I can guarantee I won't scroll up" |
| `but-for-real` | Hostile self-review + receipts before any "done" claim | "Upload broken, 118 tests pass"; Pigford's /but-for-real |

Each skill ships with:
- `evals.md` — binary pass/fail checks, graded by a **clean-context subagent**
  (never the builder), plus a canonical test scenario.
- `memory.md` — dated lessons appended whenever the skill fails in the wild.
  The evidence base for the next revision.

## Hooks (Stop)

- `rendered-proof.sh` — frontend files edited this session + zero rendered-pixel
  evidence → block once with remediation. Grepping bundles ≠ UI verification.
- `session-exit-hygiene.sh` — files edited THIS session sitting uncommitted in a
  git repo → block once: commit or write an explicit handoff. Pre-existing repo
  dirt is ignored; `/tmp`, scratchpad, and `~/.claude` are excluded.

Both hooks fail open on any error and block at most once per stop
(`stop_hook_active` respected).

## Tests

```bash
bash tests/test-hooks.sh   # 11 assertions: fire, no-fire, and fail-open paths
```

## Measuring whether it works

The flagship experiment: run Opus 4.8 ± `precondition-check` on Friction-Bench
`ua-001` (k=5). If the skill closes the tier gap, the plugin demonstrably transfers
a Fable behavior. Repeat per skill as Friction-Bench buckets get discriminating
traps.

## Deferred (logged in design doc)

correction-ledger · cross-model-reviewer · skills-gap-audit · overnight-agent ·
nightly-dreaming
