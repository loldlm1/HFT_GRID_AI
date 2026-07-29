# Deterministic ML And Pattern Boundaries

The active source is the fixed M1 `EXTREMUM_V1` engine. Use
`docs/workflows/extremum-engine-statistics-flow.md` for schema v8 export,
dataset, audit, and training commands.

## Ordering

```text
intrinsic attempt
-> broker observation facts
-> breakout reached
-> PRE_FILTER broker checks
-> pattern playback denial
-> ML filter denial
-> PRE_SEND broker checks and OrderCheck
-> broker send
```

Research logic is never allowed to make an ineligible broker action eligible.

## ML Modes

- `ML_INFERENCE_DISABLED`: no artifact load or scoring.
- `ML_INFERENCE_SHADOW`: may load a compatible approved artifact and record
  scores; it cannot change execution.
- `ML_INFERENCE_FILTER`: Strategy Tester-only; it may deny an otherwise
  broker-eligible send.

No ML mode may create a trade, resize volume, change SL/TP, bypass actual
broker-session, stops/freeze, volume, margin, permission, or `OrderCheck`
failures, change symbol/magic scope, or overwrite broker reconciliation.

## Active Compatibility

The MQL5 loader requires:

- model artifact schema `1`;
- source/export schema `8`;
- feature set `schema_v8_extremum_engine_xgb`;
- engine `EXTREMUM_V1` on `PERIOD_M1`;
- `runtime_approval=APPROVED_FOR_MT5_RUNTIME`;
- valid feature map, trees, threshold policy, and parity evidence.

There is currently no approved schema v8 runtime model. Research exports use
`RESEARCH_ONLY_NOT_APPROVED` and fail closed. Active tooling rejects schema
v4-v7 artifacts rather than adapting or relabeling them.

## Pattern Playback

`Enable_Pattern_Audit_Overlay` is effective only in Strategy Tester. Playback
loads the selected local audit set, compares source/attempt identity plus
broker and analysis timestamps, and may deny unmatched or duplicate source
families after broker eligibility passes. It cannot affect live execution,
volume, SL/TP, or reconciliation.

Pattern playback is file-driven and has no chart-button dependency. Visual
lines are inspection-only.

## Historical Work

Archived multi-strategy and pre-v8 inference plans/evidence remain immutable
under `docs/plans/archive/` and `docs/research/archive/`. They explain historical
results only and are not active runbooks.
