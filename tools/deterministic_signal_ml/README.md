# Deterministic Pivot V10 Research

This directory validates strict schema V10 exports and builds offline research
artifacts for `PIVOT_FRACTAL_V2`. It never loads a model into MT5, authorizes a
trade, or emits a runtime-compatible model.

## Input Contract

Each run contains exactly six TSV files:

- `run_manifest.tsv`
- `pivot_windows.tsv`
- `signal_attempts.tsv`
- `execution_checks.tsv`
- `signal_outcomes.tsv`
- `run_summary.tsv`

The active feature set is `schema_v10_macro_micro_pivot_bands`. Runs must agree
on config ID, Macro/Micro timeframes, weighted-Bands policy, lot mode and size,
reference balance, account currency, and feature set. V9 runs remain historical
evidence and are rejected by active tooling.

## Validate

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV10/runs> \
  --run-id <run_id> \
  --validate-only
```

Repeat `--run-id` to validate compatible runs together.

## Build

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV10/runs> \
  --run-id <run_id> \
  --dataset-id <dataset_id>
```

The builder writes typed Parquet copies of the six source tables plus:

- `research_matrix.parquet`: one row per feature-complete consumed attempt,
  including denied and nonbinary attempts as operational/audit facts.
- `binary_outcomes.parquet`: only feature-complete, fully closed,
  broker-confirmed TP/SL rows with target `1` for TP and `0` for SL.

The model contract uses only trigger-time categories and normalized continuous
features: level/direction/time, Micro and Macro normalized widths, Micro `%B`
shifts `0..5`, Macro pivot `%B` shifts `0..5`, trigger gap/risk, spread/risk,
and Macro range/band width. Raw prices, tickets, route/send results, fill/close
facts, slippage, costs, duration, and P&L stay available for audit but are not
model inputs.

`analysis_weekday` uses `0=Sunday` through `6=Saturday`. `analysis_session`
uses neutral six-hour analysis-time buckets: `SESSION_00_05`, `SESSION_06_11`,
`SESSION_12_17`, and `SESSION_18_23`.

## Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <dataset_id> \
  --audit-id <audit_id> \
  --minimum-group-support 30
```

The audit separates operational denials and excluded outcomes from strict
binary performance. It reports level/direction, calendar/session, and
human-readable quintile groups. Bins are report-only; XGBoost receives the
underlying continuous values.

## Train

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <dataset_id> \
  --model-id <model_id>
```

Training uses only `binary_outcomes.parquet`, fixed seeds, a purged
chronological holdout, and expanding walk-forward folds. All rows sharing
`(symbol, Macro timeframe, active Macro bar open)` stay in one partition across
duplicate run IDs. A training row is retained only when its broker close time
is strictly earlier than the validation boundary.

The deterministic ablation order is:

1. level/direction/time plus normalized trigger gap and spread;
2. add normalized Micro/Macro widths and Macro range/width;
3. add Micro `%B 0..5`;
4. add Macro pivot `%B 0..5`.

Saved classifiers are offline candidates under `artifacts/models/`. Their
manifest remains `OFFLINE_RESEARCH_ONLY` with
`runtime_artifact_emitted=false`.

## Exclusions

Manual, mixed-reason, stop-out, expert, other, denied, failed-send, and censored
facts remain required for integrity and operations. They are not relabeled as
losses and never enter the binary target. Fixed-lot and reference-risk datasets,
different currencies, or different Macro/Micro configurations are not mixed in
the initial research contract.
