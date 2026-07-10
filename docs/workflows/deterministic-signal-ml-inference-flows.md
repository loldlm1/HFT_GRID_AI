# Deterministic ML Inference Boundaries

The active deterministic source is the single M1 extremum engine. Use
`docs/workflows/extremum-engine-statistics-flow.md` for export, validation,
DuckDB audit, and research training commands.

## Runtime Modes

- `ML_INFERENCE_DISABLED`: no model load or scoring.
- `ML_INFERENCE_SHADOW`: may load a compatible approved artifact and record
  scores, but cannot affect execution.
- `ML_INFERENCE_FILTER`: Strategy Tester only; may deny an otherwise admissible
  engine entry after existing broker/risk eligibility and before broker send.

No ML mode may create trades, resize lots, change SL/TP, bypass license,
session, spread, margin, market-status or protection controls, change
symbol/magic scope, or overwrite broker reconciliation facts.

## Active Compatibility

The runtime requires all of the following:

- Export schema `7`.
- Feature set `schema_v7_extremum_engine_xgb`.
- Engine ID `1`, label `EXTREMUM_V1`, timeframe `PERIOD_M1`.
- Explicit `runtime_approval=APPROVED_FOR_MT5_RUNTIME`.
- Valid feature map, trees, threshold policy, and parity evidence.

There is currently no approved schema v7 runtime model. Research artifacts use
`RESEARCH_ONLY_NOT_APPROVED` and fail closed. Historical v4/v5/v6 S1/S2/S3
artifacts also fail closed and must not be relabeled as engine artifacts.

## Historical Work

The retired multi-strategy workflows, run IDs, pattern audits, model exports,
and acceptance evidence remain immutable under:

- `docs/plans/archive/deterministic-signal-ml-2026-07-05/`
- `docs/plans/archive/phase3-ml-2026-07-07/`
- `docs/plans/archive/ml-robustness-closeout-2026-07-09/`
- `docs/research/archive/deterministic-signal-ml-2026-07-05/`
- `docs/research/archive/ml-robustness-closeout-2026-07-09/`

Those archives explain historical results only. They are not active runbooks.
