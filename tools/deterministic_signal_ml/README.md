# Extremum Engine Research Tooling

This directory validates schema v7 MQL5 exports, builds typed Parquet tables,
produces DuckDB depth/profitability audits, and prepares leak-safe XGBoost
research. It does not call MT5, place trades, or approve a runtime model.

## Setup

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
```

The dependency versions are pinned. Generated datasets, audits, models, and
exports live under `artifacts/` and remain ignored by git.

## Schema V7 Inputs

Each run contains manifest/summary files plus:

- `engine_cycles.tsv`
- `engine_revisions.tsv`
- `engine_attempts.tsv`
- `signal_admissions.tsv`
- `signal_features.tsv`
- `signal_outcomes.tsv`
- `signal_leg_outcomes.tsv`

The validator checks row counts, unique IDs, parent joins, monotonic revision
indexes, immutable Fibonacci anchors, raw numeric depth, simulated provenance,
and broker outcome evidence. Historical v4/v5/v6 contracts remain selectable
explicitly but cannot be mixed with v7 in one dataset.

## Build

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <runs_root> \
  --run-id <schema_v7_run_id> \
  --dataset-id <schema_v7_dataset_id> \
  --schema-version 7 \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite
```

Use `--validate-only` before large builds. Use
`--target-family engine_simulated_1r` for a separate simulation target lane.
Never combine simulated and broker targets.

Schema v7 outputs include typed `engine_cycles.parquet`,
`engine_revisions.parquet`, `engine_attempts.parquet`, broker tables,
`training_matrix.parquet`, and compact JSON/Markdown quality reports.

## Human Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id <schema_v7_dataset_id> \
  --audit-id <schema_v7_audit_id> \
  --overwrite
```

Outputs:

- `fibonacci_proximity.tsv`
- `attempt_profitability.tsv`
- `cycle_sequences.tsv`
- `stability.tsv`
- `audit_metadata.json`
- `audit_report.md`

The default analytics levels are `0, 23.6, 38.2, 50, 61.8, 78.6, 100,
123.6, 138.2, 161.8, 178.6, 200`. Raw depth is retained and extensions are not
clamped. Range fields are price distance in points, not volume.

## XGBoost Research

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <schema_v7_dataset_id> \
  --model-id <schema_v7_model_id> \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --overwrite
```

The feature set contains only attempt-time facts. Chronological splits group
all attempts from `symbol + engine_timeframe + extremum_cycle_id` together.
Training fails with an actionable error when row or class support is too small.

Model export remains research-only. Schema v7 exports use
`runtime_approval=RESEARCH_ONLY_NOT_APPROVED`; the MQL5 runtime rejects them.
Old multi-strategy artifacts are incompatible with `EXTREMUM_V1`.

## Validation

```bash
.venv/bin/python -m compileall tools/deterministic_signal_ml
.venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

The compact fixtures cover 39% near 38.2, 63% near 61.8, frozen-anchor and
orphan failures, separate outcome lanes, cycle sequences, cycle-group splits,
and fail-closed artifact compatibility.

The complete operator flow and human Strategy Tester matrix are in
`docs/workflows/extremum-engine-statistics-flow.md`.
