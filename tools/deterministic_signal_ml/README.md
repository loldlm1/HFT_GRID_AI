# Deterministic Pivot V12 Research

This directory validates strict schema V12 exports and builds policy-aware
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

The active feature set is `schema_v12_pivot_signal_features`. Runs must agree
on config ID, Macro/Micro timeframes, fixed Bands/Stochastic parameters, matrix
percentages/TPs, quote-side and minimum-distance rules, retry/capacity policy,
lot mode and size, reference balance, account currency, and feature set.
V9/V10/V11 runs remain historical evidence and are rejected by active tooling.

## Validate

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV12/runs> \
  --run-id <run_id> \
  --validate-only
```

Repeat `--run-id` to validate compatible runs together.

## Build

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV12/runs> \
  --run-id <run_id> \
  --dataset-id <dataset_id>
```

The builder writes typed Parquet copies of the eight source tables plus:

Every strict V12 column has one explicit frozen `VARCHAR`, `TIMESTAMP`,
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

The model contract uses only causal policy and origin features: level/direction,
SL policy, TP multiple, retry index/loss count, trigger analysis time, normalized
entry gap/spread, Micro/Macro shift-0 width points, and separate Micro/Macro
Bands and Stochastic groups. `%B`, `MAIN_LINE`, and `SIGNAL_LINE` include raw,
SMA 5, SMA slope, and state for shifts `0..5`; Bands also include raw
`BASE_LINE` and its point slope. Eligibility, continuation, first touch,
parity, broker checks, fills/closes, slippage, costs, duration, and P&L remain
audit facts and never enter model features.

All indicator features come from one immutable `signal_origins.tsv` row joined
by origin. Retries do not create independent market snapshots or discovery
support. `initial_matrix_wide.parquet` carries the same origin vector once for
human comparison, while `eligible_virtual_trials.parquet` carries joined
features with weights summing to `1.0` per origin.

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

The audit separates origin/matrix support, per-feature availability, virtual
policy performance, chain results, broker execution, and parity calibration.
It reports both unique
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
2. add Micro/Macro shift-0 width points;
3. add Micro Bands `%B`/SMA/slope/state and `BASE_LINE`/slope;
4. add the matching Macro Bands group;
5. add Micro Stochastic `MAIN_LINE` and `SIGNAL_LINE` groups;
6. add the matching Macro Stochastic groups.

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
