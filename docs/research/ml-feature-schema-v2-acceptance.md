# ML Feature Schema V2 Acceptance

**Date**: 2026-07-06
**Roadmap Phase**: Phase 3 - Feature Schema V2
**Status**: Sprint 1 contract accepted; implementation pending

## Scope

This phase replaces the active deterministic signal ML feature contract with
schema version 2, then validates whether the new feature set can produce a
robust positive XAUUSD threshold without overfitting.

Accepted implementation scope:

- MQL5 feature export and shadow-scorer feature extraction.
- Python schema validation, dataset build, training, export, parity, and
  comparison tooling.
- Fresh human-in-the-loop Strategy Tester raw export for XAUUSD calendar year
  2025.
- Runtime export/parity validation only if the research acceptance gate passes.

Out of scope:

- Live deployment approval.
- ONNX work.
- Multi-symbol research.
- Dynamic `1:n` target modeling.
- Any weakening of license, session, spread, stops/freeze, margin, protection,
  magic-number, market-status, or broker reconciliation guards.

## Frozen Schema V1 Rejection Baseline

The current long XAUUSD schema v1 baseline is frozen as the rejection baseline
for Phase 3 comparison:

- Dataset ID: `xauusd_2025_dataset_1`
- Model ID: `xauusd_2025_xgb_1`
- Source run IDs: `test_run_1`
- Config IDs: `cfg_12150440574703104362`
- Feature schema version: `1`
- Dataset training matrix rows: `36862`
- Model train rows: `29490`
- Model holdout rows: `7372`
- Encoded features: `69`
- Holdout classifier ROC AUC: `0.495134`
- Holdout classifier precision/recall/F1 at default decision boundary:
  `0.000000` / `0.000000` / `0.000000`
- Holdout regressor correlation: `0.006745`
- Threshold recommendation: none
- Threshold rows selected at thresholds `>= 0.50`: `0`

Result:

- The v1 long baseline is not a promoted model.
- No v1 runtime export is approved from this baseline.
- Phase 3 must show material improvement over this frozen rejection baseline
  before creating a schema v2 runtime export.

## Schema V2 Feature Contract

Schema v2 features must be available at entry time. They must not use terminal
outcomes, post-entry bars, blocked-result information, future macro bars, or
final-holdout tuning.

Required structure features:

- `source_structure_type`: categorical token for the source extremum structure.
- `opposite_structure_type`: categorical token for the opposite extremum used
  by the execution range.
- `same_previous_structure_type`: categorical token for the previous same-type
  extremum used by the execution range.

Required previous closed candle features from `DETERMINISTIC_BASE_TIMEFRAME`
shift `1`:

- `prev_body_ratio`: absolute body divided by candle range.
- `prev_upper_wick_ratio`: upper wick divided by candle range.
- `prev_lower_wick_ratio`: lower wick divided by candle range.
- `prev_close_location`: close location within candle range, normalized `0..1`.
- `prev_candle_dir`: categorical direction token such as `BULL`, `BEAR`, or
  `DOJI`.

Required strategy-depth and directional features:

- `strategy_delay_period`: S1/S2/S3 depth delay, expected `3`, `5`, or `10`.
- `confirmation_timeframe_minutes`: macro confirmation timeframe, expected
  `3`, `5`, or `10`.
- `entry_direction_macro_alignment`: entry direction aligned/opposed/flat
  against the strategy confirmation timeframe slope.
- `macro_alignment_score`: H1/H4/D1 alignment score against entry direction.

Secondary ablation candidates:

- `source_intern_fib_raw`
- `source_extern_fib_raw`
- `source_extern_structures_broken`
- `prev_candle_shape`
- `session_bucket`

Structure type tokens must be stable and categorical, for example `HH`, `HL`,
`LH`, `LL`, and `EQ`. They must not be treated as ordinal numeric values.

S1, S2, and S3 are one signal archetype at increasing depth:

- S1: delay `3`, M3 macro confirmation.
- S2: delay `5`, M5 macro confirmation.
- S3: delay `10`, M10 macro confirmation.

The default promotion target is a global depth-aware model. Per-strategy or
per-direction thresholds/models require stronger support counts and segment
evidence than the global policy.

## XAUUSD 2025 Run Contract

Generate the schema v2 raw export with human-in-the-loop Strategy Tester:

- Symbol: XAUUSD
- Date range: full 2025 calendar year
- Start: `2025-01-01 00:00:00`
- End: exclusive `2026-01-01 00:00:00` when supported, or inclusive
  `2025-12-31 23:59:59` if Strategy Tester requires an inclusive end.
- Runtime mode: `ML_INFERENCE_DISABLED`
- Feature export: enabled
- Strategies: S1, S2, and S3 enabled
- Recommended run ID: `xauusd_2025_schema_v2_run_1`
- Recommended dataset ID: `xauusd_2025_schema_v2_dataset_1`
- Recommended model ID: `xauusd_2025_schema_v2_xgb_1`

Generated files remain outside git and should be summarized only by row counts,
paths, final status lines, and selected warnings.

## Promotion Gate

Schema v2 can advance to runtime export only when all required gates pass:

- Fresh XAUUSD schema v2 export covers the 2025 calendar-year range.
- Dataset build has no duplicate feature/outcome IDs.
- Dataset build has no unexplained missing outcomes.
- Feature invalid rows are zero or bounded and explained.
- Threshold selection uses threshold-selection rows or pre-final-holdout
  out-of-fold predictions, never final holdout rows.
- Final holdout remains approval evidence only.
- Candidate comparison shows material improvement over the frozen v1 rejection
  baseline.
- A positive threshold candidate exists on threshold-selection evidence.
- Final holdout at the selected threshold remains positive after costs.
- Threshold-selection selected rows are `>= 100`.
- Final-holdout selected rows are `>= 50`.
- Important strategy-depth segments have `>= 15` selected rows, or the result
  remains research-only with no promotion claim.
- Bullish and bearish selected rows each have `>= 20` rows, or the result
  remains research-only with no promotion claim.
- No unresolved critical regression remains for S1, S2, S3, bullish, bearish,
  source type, or strategy-direction segments.
- Rare-bucket, high-importance concentration, final-holdout reuse, leakage, and
  no-variation warnings are resolved or explicitly accepted as non-blocking.

If the research gate fails, Phase 3 must create a follow-up Phase 3 `$planner`
plan before additional feature iteration. Do not move to ONNX, multi-symbol
research, dynamic targets, or live rollout.

## Runtime Gate

Runtime export is conditional on research acceptance.

If a schema v2 runtime export is produced:

- Artifact validation must record schema version `2`.
- The export must include a positive threshold policy.
- The deployed Common Files copy must validate.
- SHADOW mode must produce scored rows and Python/MQL5 parity within accepted
  tolerance.
- FILTER mode must preserve broker/risk gate order and Phase 2 arbitration
  counters.
- Invalid feature rows must be zero or explicitly explained.
- No live deployment approval is implied.

## Sprint 1 Validation

Sprint 1 is documentation-only.

Validated inputs:

- `artifacts/datasets/xauusd_2025_dataset_1/dataset_report.md`
- `artifacts/datasets/xauusd_2025_dataset_1/dataset_manifest.json`
- `artifacts/models/xauusd_2025_xgb_1/validation_report.md`
- `artifacts/models/xauusd_2025_xgb_1/model_manifest.json`

Result:

- V1 rejection baseline is frozen for comparison.
- Schema v2 contract and gates are defined.
- MQL5 and Python implementation remains pending.
