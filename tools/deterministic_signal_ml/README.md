# Deterministic Pivot V11 Research

This directory validates strict schema V11 exports and builds policy-aware
offline research artifacts for `PIVOT_FRACTAL_V2`. It never loads a model into
MT5, authorizes a trade, or emits a runtime-compatible model.

## Input Contract

Each run contains exactly eight TSV files:

- `run_manifest.tsv`
- `pivot_windows.tsv`
- `signal_origins.tsv`
- `virtual_trials.tsv`
- `virtual_outcomes.tsv`
- `execution_checks.tsv`
- `broker_outcomes.tsv`
- `run_summary.tsv`

The active feature set is `schema_v11_pivot_trial_matrix`. Runs must agree on
config ID, Macro/Micro timeframes, weighted-Bands policy, fixed matrix
percentages/TPs, quote-side and minimum-distance rules, retry/capacity policy,
lot mode and size, reference balance, account currency, and feature set. V9/V10
runs remain historical evidence and are rejected by active tooling.

## Validate

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV11/runs> \
  --run-id <run_id> \
  --validate-only
```

Repeat `--run-id` to validate compatible runs together.

## Build

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV11/runs> \
  --run-id <run_id> \
  --dataset-id <dataset_id>
```

The builder writes typed Parquet copies of the eight source tables plus:

Every strict V11 column has one explicit frozen `VARCHAR`, `TIMESTAMP`,
`BOOLEAN`, `BIGINT`, or `DOUBLE` type. Registry overlap, missing schema columns,
and stale entries fail closed; new columns never inherit a numeric fallback.

- `origin_matrix_long.parquet`: every matrix trial, including retries,
  ineligible rows, and censored facts.
- `initial_matrix_wide.parquet`: one human/agent comparison row per origin with
  the initial sixteen cells; never used directly for model training.
- `eligible_virtual_trials.parquet`: feature-complete eligible
  `TP_FIRST`/`SL_FIRST` matrix rows with target `1/0` and per-origin weight.
- `policy_chains.parquet`: one row per policy chain with attempt count, losses,
  final state, nominal R, quote gross R, and censoring.
- `broker_virtual_calibration.parquet`: paired accepted-request parity and
  broker outcomes with terminal, timing, price, gross, R, and cost differences.

The model contract uses only entry-known policy and market features:
level/direction, SL policy, TP multiple, retry index/loss count, time, frozen
origin width, normalized Micro/Macro widths, Micro `%B 0..5`, Macro pivot `%B
0..5`, entry gap/risk, spread/risk, and Macro range/band width. Eligibility,
continuation, first touch, parity, broker checks, fills/closes, slippage, costs,
duration, and P&L stay available for audit but are not model inputs.

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

The audit separates origin/matrix support, virtual policy performance, chain
results, broker execution, and parity calibration. It reports both unique
origins and trial rows, expected nominal R, quote gross R, censoring, and
calibration exclusions. Human bins are report-only; XGBoost receives the
underlying continuous values. Parity terminal observations are session-aware;
broker-terminal-before-observed-touch shadows are explicit censored exclusions.
Any unexplained fully observed TP/SL parity mismatch fails the audit.

## Train

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <dataset_id> \
  --model-id <model_id>
```

Training uses only `eligible_virtual_trials.parquet`, fixed seeds,
origin-normalized sample weights, a purged chronological holdout, and expanding
walk-forward folds. All rows sharing `(symbol, Macro timeframe, active Macro bar
open)` stay in one partition across duplicate run IDs. A training row is
retained only when its virtual terminal time is strictly earlier than the
validation boundary.

The deterministic ablation order is:

1. policy/level/direction/time plus normalized entry gap and spread;
2. add frozen origin width, normalized Micro/Macro widths, and Macro range/width;
3. add Micro `%B 0..5`;
4. add Macro pivot `%B 0..5`.

Saved classifiers are offline candidates under `artifacts/models/`. Their
manifest remains `OFFLINE_RESEARCH_ONLY` with
`runtime_artifact_emitted=false`.

## Exclusions

Ineligible and censored virtual rows, parity shadows, manual/mixed/stop-out/
expert/other broker outcomes, denied attempts, and failed sends remain required
for integrity and operations. They are not relabeled as losses and never enter
the primary virtual target. Broker-confirmed TP/SL outcomes stay in a separate
cohort. Virtual gross is counterfactual and has no commission, swap, fee, or
net-profit claim. Fixed-lot and reference-risk datasets, different currencies,
or different Macro/Micro and matrix contracts are not mixed.
