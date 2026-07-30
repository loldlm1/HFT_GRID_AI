# Pivot Fractal V9 Research Tooling

This directory validates strict `PIVOT_FRACTAL_V1` exports, builds typed
Parquet tables with DuckDB, produces deterministic pivot lifecycle audits, and
prepares offline XGBoost research. It does not call MT5, place trades, export a
runtime model, or approve live inference.

## Setup

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
```

The existing dependency versions remain pinned. Generated datasets, audits,
and models belong under `artifacts/` and remain ignored by git.

## Strict V9 Inputs

Each run must contain exactly these nine tables with the frozen exporter
headers:

- `run_manifest.tsv`
- `pivot_windows.tsv`
- `pivot_levels.tsv`
- `signal_attempts.tsv`
- `signal_features.tsv`
- `execution_checks.tsv`
- `trailing_events.tsv`
- `signal_outcomes.tsv`
- `run_summary.tsv`

The validator requires schema `9`, engine `PIVOT_FRACTAL_V1`, feature set
`schema_v9_pivot_fractal_xgb`, unique window/level/signal identities, seven
ordered levels per valid window, exactly six feature contexts per attempt,
causal broker/analysis timestamp conversion, send-chain integrity, ticket-first
trailing ownership, and broker-confirmed fill plus close evidence for every
outcome. Older schema versions fail closed and require their historical code
revision.

Validate a run without writing artifacts:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV9/runs> \
  --run-id <v9_run_id> \
  --validate-only
```

## Dataset Build

Build the broker-outcome matrix used for profitability research:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV9/runs> \
  --run-id <v9_run_id> \
  --dataset-id <v9_dataset_id> \
  --target-family broker_outcome \
  --overwrite
```

Use `--target-family admission` to include denied and unfilled attempts for a
separate admission analysis. Broker-outcome training excludes those attempts.
Repeat `--run-id` to assemble multiple validated runs.

Outputs contain normalized Parquet copies of all nine tables plus
`training_matrix.parquet`, `dataset_manifest.json`, `dataset_quality.json`, and
`dataset_report.md`. Model features are trigger-time facts only. Window terminal
state, execution results, trailing, fills, closes, duration, and realized profit
remain labels or audit facts.

Every validated build also derives these offline-only tables:

- `signal_retest_context.parquet`: six immutable prior-close side contexts per
  first-touch attempt (`M1`, `M15`, `M30`, `H1`, `H4`, and `D1`).
- `confluence_members.parquet`: actual V9 first-touch members active on their
  own half-open pivot-window intervals.
- `confluence_snapshots.parquet`: one bounded causal member snapshot per anchor.

A macro retest context compares a causal previous close with the anchor's tested
price. It is not an independent macro touch. Confluence members require their
own V9 attempt. Mixed BUY/SELL members and arbitrary timeframe combinations are
valid, support/resistance roles remain dynamic, and no `retest_sequence` exists.

Enable the compact model feature contract explicitly:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV9/runs> \
  --run-id <v9_run_id> \
  --dataset-id <confluence_dataset_id> \
  --target-family broker_outcome \
  --research-feature-set-id pivot_first_touch_confluence_v1 \
  --overwrite
```

The default command remains the exact base feature lane. The opt-in contract
adds five macro retest categories and eleven bounded counts. It excludes M1
retest type (a duplicate of direction), IDs, canonical pattern tokens, targets,
outcomes, and future-only facts.

## Pivot Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <v9_dataset_id> \
  --audit-id <v9_audit_id> \
  --overwrite
```

The audit reports window validity, the complete level/direction matrix,
same-tick confluence, causal retest distributions, bounded active snapshots,
unordered pair support, admission denials, milestone progression, structural
break-even separately from realized profit, broker TP/SL/other outcomes,
duration, spread, and adverse entry slippage. Use
`--minimum-group-support <n>` to set the D1-group interpretation threshold;
atomic facts are never deleted. Exact requested token sets are queried from
member rows rather than a precomputed power set. The audit never manufactures a
simulated path label.

## Offline XGBoost

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <v9_dataset_id> \
  --model-id <v9_model_id> \
  --overwrite
```

Chronological holdout and walk-forward folds keep every
`(run_id, symbol, window_id)` group in one partition for base datasets.
Confluence datasets keep the same symbol/D1 active broker window together
across run IDs through `research_group_id`. Feature and categorical columns are
read from the fail-closed dataset manifest; fixed XGBoost settings and seeds are
unchanged. Model folders are marked `OFFLINE_RESEARCH_ONLY` and record
`runtime_artifact_emitted=false`; no MT5 runtime artifact or deployment command
exists.

The accepted natural-run evidence and matched D1-group ablation are documented
in `docs/research/pivot-retest-confluence-offline-acceptance.md`. The current
single-run result is inconclusive and does not approve a model or pattern for
runtime use.

## Validation

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
.venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

The three test modules cover exact headers and keys, six-context completeness,
duplicate and orphan rejection, future-feature exclusion, chronological window
and D1-group separation, compact base/confluence feature contracts, broker-only
outcomes, trailing semantics, unordered pattern queries, and deterministic audit
output.
