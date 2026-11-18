#!/usr/bin/env bash
# Does the dev-process skill still help on this model? Runs every case in evals/ twice per run:
# once WITH the plugin, once WITHOUT it (a no-plugin baseline), on one pinned model, and prints the gap.
# A case whose with-plugin score is not above the baseline means those instructions no longer add
# anything on that model: candidates to trim or rewrite. Rerun on every new model release.
#
# Usage: scripts/eval-vs-baseline.sh [model] [runs-per-case]
#   MAX_COST_USD=5 (default) is a hard spending stop for the whole run.
set -euo pipefail
MODEL="${1:-claude-opus-5-5}"
RUNS="${2:-1}"
COST="${MAX_COST_USD:-5}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/evals/results/$(date -u +%Y%m%dT%H%M%SZ)-$MODEL"
mkdir -p "$OUT"
echo "dev-process eval: model=$MODEL runs=$RUNS cost cap=\$$COST -> $OUT"
# --threshold 0: low scores are the finding here, not a failure of the script.
claude plugin eval "$ROOT" \
  --model "$MODEL" --runs "$RUNS" --ablation with-without \
  --max-cost-usd "$COST" --threshold 0 \
  --no-publish --trust-plugin \
  --output-dir "$OUT" --report "$OUT/report.html"
echo "Report: $OUT/report.html  (cases with no gap over the baseline are candidates to trim)"
