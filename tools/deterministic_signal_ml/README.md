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

## Pivot Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <v9_dataset_id> \
  --audit-id <v9_audit_id> \
  --overwrite
```

The audit reports window validity, the complete level/direction matrix,
same-tick confluence, admission denials, milestone progression, structural
break-even separately from realized profit, broker TP/SL/other outcomes,
duration, spread, and adverse entry slippage. It never manufactures a simulated
path label.

## Offline XGBoost

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <v9_dataset_id> \
  --model-id <v9_model_id> \
  --overwrite
```

Chronological holdout and walk-forward folds keep every
`(run_id, symbol, window_id)` group in one partition. Model folders are marked
`OFFLINE_RESEARCH_ONLY`; no MT5 runtime artifact or deployment command exists.

## Validation

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
.venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

The three test modules cover exact headers and keys, six-context completeness,
duplicate and orphan rejection, future-feature exclusion, chronological window
grouping, compact dataset assembly, broker-only outcomes, trailing semantics,
and deterministic audit output.
