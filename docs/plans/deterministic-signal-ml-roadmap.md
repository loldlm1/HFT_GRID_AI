# Roadmap: Deterministic Signal ML Pipeline

**Generated**: 2026-07-04
**Status**: Draft
**Scope**: Deterministic signal statistics, local ML training, and MT5 Strategy Tester inference.

## Purpose

Build a lightweight ML research pipeline around the deterministic MA/Stoch
strategy stack without making the first implementation phase heavy.

The EA should first produce stable, auditable signal statistics. Python tooling
can then transform those statistics into ML-ready datasets and train XGBoost
models. MT5 inference should arrive only after the exported dataset and model
contract are proven.

PostgreSQL is intentionally out of scope for this roadmap. It can be added later
as an analytics/storage layer after the local pipeline is useful.

## Guiding Principles

- Keep Phase 1 limited to statistics export. No Python, Parquet, DuckDB,
  PostgreSQL, model training, or trade filtering in the first implementation.
- Keep trading behavior unchanged until an explicit inference/filter phase.
- Keep feature columns small, deterministic, and interpretable.
- Keep new EA inputs sparse and mode-oriented. Prefer IDs, enable toggles, and
  artifact paths over exposing internal ML/scoring internals as inputs.
- Capture ML features at a clear lifecycle boundary, preferably after a
  deterministic entry is confirmed and broker execution succeeds.
- Keep result/outcome data separate from input features to prevent leakage.
- Use versioned schemas, run IDs, config IDs, and model IDs from the beginning.
- Keep all file I/O gated by explicit inputs and off by default.
- Prefer external Python for dataset conversion and model training.
- Keep MT5 inference self-contained by loading a pre-exported model artifact;
  do not call Python, DuckDB, or external services from the EA hot path.

## Phase 1: Deterministic Signal Statistics Export

**Planner plan**: `docs/plans/deterministic-signal-statistics-export-plan.md`

Create the EA-side research data foundation:

- feature schema and run manifest contract
- stable `run_id`, `config_id`, and `signal_id`
- compact deterministic feature snapshot
- terminal outcome snapshot
- TSV export under a versioned Common Files namespace
- debug-gated audit logs

Non-goals:

- no ML model
- no inference
- no Python tooling
- no Parquet conversion
- no PostgreSQL
- no behavior changes to broker admission or lifecycle decisions

## Phase 2: Local Dataset Builder

**Planner plan**: `docs/plans/deterministic-signal-local-dataset-builder-plan.md`

Create a Python-side local dataset pipeline:

- read Phase 1 TSV files
- validate schema version and required columns
- join features and outcomes by `signal_id`
- write Parquet datasets
- provide quick local queries through DuckDB or Polars
- produce basic data quality reports

Recommended outputs:

- `features.parquet`
- `outcomes.parquet`
- `training_matrix.parquet`
- `dataset_report.md`

## Phase 3: XGBoost Training And Validation

**Planner plan**: `docs/plans/deterministic-signal-xgboost-training-validation-plan.md`

Train local Python models from the Parquet dataset:

- baseline rules and simple decision tree
- XGBoost classifier/regressor
- walk-forward or time-split validation
- feature importance and SHAP-style interpretation when practical
- threshold recommendations for shadow inference

Recommended targets:

- binary target: positive/negative outcome
- regression target: `profit_r`
- optional classification target: TP, SL, expired, blocked

## Phase 4: Model Artifact Export

**Planner plan**: `docs/plans/deterministic-signal-model-artifact-export-plan.md`

Export trained models into an MT5-readable artifact:

- `model_manifest.tsv` or `model_manifest.json`
- `model_trees.tsv`
- `feature_map.tsv`
- validation summary

The first artifact format should be file-based and loaded during `OnInit`.
Generated `.mqh` models can be considered later if file loading is too slow.

## Phase 4.5: Agentic Environment Portability

**Planner plan**: `docs/plans/deterministic-signal-phase-4-5-agentic-environment-portability-plan.md`

Validate the Windows and Ubuntu/Wine workflows required before MQL5 Shadow
Inference:

- real MetaEditor compile versus syntax check
- MT5 `Common\Files` discovery
- Python ML environment setup
- local artifact inventory or regeneration
- compact readiness evidence for Phase 5

Non-goals:

- no MQL5 model loader
- no shadow inference
- no filter mode
- no trading behavior changes
- no committed generated artifacts

## Phase 5: MQL5 Shadow Inference

**Prerequisite**: Phase 4.5 readiness gate is `PASS`, or a human explicitly
accepts a partial gate.

Load the exported model in MT5 and evaluate it without changing broker behavior.

Recommended mode:

```text
ML_Inference_Mode = SHADOW
```

Shadow inference should record:

- model ID
- feature schema version
- model score
- threshold decision
- allow/block recommendation
- decision reason
- realized result after the signal closes

## Phase 6: MQL5 Filter Inference

After shadow inference proves useful, allow the model to affect Strategy Tester
broker admission.

Recommended modes:

```text
DISABLED
SHADOW
FILTER
```

Filter mode must preserve all existing safety controls:

- license
- session gates
- spread and broker constraints
- margin and volume normalization
- drawdown/protection
- magic-number and symbol scope
- broker position reconciliation

## Deferred: PostgreSQL Analytics

PostgreSQL remains deferred. It can later ingest TSV or Parquet-derived staging
tables for persistent analytics, dashboards, and cross-run comparisons.

Do not add PostgreSQL to the EA runtime path.

## Recommended File Boundary

EA-owned output:

```text
Common\Files\DeterministicSignalML\runs\<run_id>\run_manifest.tsv
Common\Files\DeterministicSignalML\runs\<run_id>\signal_features.tsv
Common\Files\DeterministicSignalML\runs\<run_id>\signal_outcomes.tsv
Common\Files\DeterministicSignalML\runs\<run_id>\run_summary.tsv
```

Python-owned output:

```text
datasets\<dataset_id>\features.parquet
datasets\<dataset_id>\outcomes.parquet
datasets\<dataset_id>\training_matrix.parquet
models\<model_id>\model_manifest.tsv
models\<model_id>\model_trees.tsv
models\<model_id>\feature_map.tsv
```

## Success Criteria

- Phase 1 can run in MT5 Strategy Tester with export enabled and no trading
  behavior changes.
- Exported TSV rows are stable, typed, and joinable.
- Python tooling can build datasets without inspecting EA internals.
- A future model artifact can be loaded by MT5 without Python or database
  dependencies.
- Any future filter mode can be tested in Strategy Tester before live use.
- The complete roadmap keeps the EA input surface small and understandable.
