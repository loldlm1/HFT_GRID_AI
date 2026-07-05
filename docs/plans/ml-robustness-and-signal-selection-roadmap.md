# Roadmap: ML Robustness And Signal Selection

**Generated**: 2026-07-05
**Status**: Draft active roadmap
**Estimated Complexity**: High

## Purpose

Build the next deterministic signal ML program around robustness first:
reduce accidental overfit, make Strategy Tester results closer to the intended
single-position execution policy, and expand model features only when they
improve out-of-sample evidence.

This roadmap is a parent document. Each implementation phase below must get its
own `$planner` plan under `docs/plans/` before code changes begin. Complete,
validate, and commit one phase before starting the next phase.

## Current Baseline

- Completed deterministic signal ML roadmap is archived under
  `docs/plans/archive/deterministic-signal-ml-2026-07-05/`.
- Active workflow reference is
  `docs/workflows/deterministic-signal-ml-inference-flows.md`.
- Current accepted runtime scope keeps `ML_INFERENCE_FILTER` limited to Strategy
  Tester validation.
- Current model export flow uses Python XGBoost artifacts converted into
  MT5-readable TSV trees and feature maps.
- Current model contract has Phase 1 schema version `1` and 49 encoded features.
- Current local dataset evidence is XAUUSD-only and should not be treated as
  cross-symbol proof.
- Current FILTER runtime evidence validates Python/MQL5 parity and broker
  admission filtering, but it does not solve simultaneous strategy arbitration.

## Non-Goals

- No live deployment approval in this roadmap.
- No weakening of license, session, spread, stops/freeze, margin, protection,
  magic-number, market-status, or broker reconciliation guards.
- No ML mode may create trades, resize lots, alter SL/TP, or bypass broker/risk
  eligibility.
- No ONNX replacement of the current TSV scorer until a separate parity and
  runtime spike passes.
- No dynamic `1:n` target behavior until counterfactual path labels are exported
  and validated.
- No broad feature expansion without ablation evidence and out-of-sample gates.

## Guiding Principles

- Freeze a baseline before changing features, thresholds, or execution policy.
- Choose thresholds outside the final holdout; keep a final holdout or future
  Strategy Tester run untouched until the acceptance gate.
- Prefer chronological and walk-forward validation over random splits.
- Evaluate improvements by strategy, direction, source type, and symbol, not
  only aggregate metrics.
- Treat rare one-hot buckets and small selected-trade counts as overfit risks.
- Keep schema changes versioned and backward-compatible at the tooling boundary.
- Separate actual broker outcomes from simulated, blocked, and counterfactual
  outcomes.
- Keep generated artifacts out of git unless a future human explicitly changes
  that policy.

## Phase 1: ML Validation Hardening

**Planner plan**: `docs/plans/ml-validation-hardening-plan.md`
**Risk level**: Medium, statistical and tooling behavior

Strengthen the Python research pipeline before adding new features.

Recommended scope:

- freeze current baseline dataset, model, export ID, and metric summary
- separate threshold-selection data from final holdout data
- add ablation report support for baseline versus candidate feature sets
- report per-fold threshold behavior, selected rows, mean R, net R, and drawdown
- report metrics by `strategy_label`, `direction`, `source_type`, and symbol
- flag rare categorical buckets and high feature-importance concentration
- define pass/fail criteria for future feature additions

Acceptance gate:

- validation reports can reproduce the current baseline
- threshold recommendation no longer uses the same final holdout used for final
  approval
- a feature candidate can be rejected with clear evidence
- documentation explains how to interpret overfit warnings
- no MQL5 behavior changes

## Phase 2: ML Signal Arbitration

**Planner plan**: `docs/plans/ml-signal-arbitration-plan.md`
**Risk level**: High, Strategy Tester execution behavior

Add a deterministic policy for choosing one candidate when enabled strategies
converge at the same moment.

Recommended scope:

- define a candidate group identity, such as symbol, entry time/source extremum,
  direction, and execution context
- evaluate ML scores for all eligible candidates in the group
- select one candidate using a deterministic rank policy
- block non-selected candidates with a distinct reason such as
  `ML_ARBITRATION_BLOCKED`
- record arbitration decisions separately from classifier filter blocks
- summarize selected versus rejected candidates in Strategy Tester artifacts

Initial ranking policy:

- prefer candidate with highest classifier score
- use regressor score as a tie-breaker
- use stable strategy priority only as the final tie-breaker

Acceptance gate:

- simultaneous candidates produce at most one broker admission per group
- blocked candidates do not create broker positions
- selected candidates still pass existing broker/risk gates
- exported statistics distinguish `ML_FILTER_BLOCKED` from
  `ML_ARBITRATION_BLOCKED`
- Strategy Tester summary demonstrates the behavioral delta

## Phase 3: Feature Schema V2

**Planner plan**: `docs/plans/ml-feature-schema-v2-plan.md`
**Risk level**: High, EA/Python/model artifact contract

Expand features in a controlled schema version after validation hardening and
arbitration are in place.

Recommended scope:

- create Phase 1 feature schema version `2`
- add prior structure type features for the source, opposite, and previous
  same-type extrema used by the Fibonacci range
- add previous closed candle ratio features from `shift=1`
- keep candle pattern labels derived from numeric ratios, not as the only
  representation
- update dataset builder, trainer, exporter, MQL5 scorer, parity validator, and
  comparison tooling for schema v2
- keep schema v1 artifact loading and validation intact unless explicitly
  retired in a later plan

Candidate structure features:

- `source_structure_type`
- `opposite_structure_type`
- `same_previous_structure_type`
- optional `source_intern_fib_raw`, `source_extern_fib_raw`, and
  `source_extern_structures_broken` only after initial type features pass

Candidate candle features:

- `prev_body_ratio`
- `prev_upper_wick_ratio`
- `prev_lower_wick_ratio`
- `prev_close_location`
- `prev_candle_dir`
- optional derived `prev_candle_shape`

Acceptance gate:

- schema v2 dataset builds from a fresh Strategy Tester export
- baseline versus v2 ablation is available
- feature additions improve validation across folds or are explicitly rejected
- no feature uses future bars, terminal outcome, blocked-result information, or
  post-entry data
- Python/MQL5 scoring parity remains within accepted tolerance

## Phase 4: ONNX Shadow Spike

**Planner plan**: `docs/plans/ml-onnx-shadow-spike-plan.md`
**Risk level**: Medium, runtime compatibility and parity

Evaluate ONNX as a parallel shadow runtime, not as a replacement for the current
TSV tree scorer.

Recommended scope:

- export the accepted XGBoost classifier and regressor to ONNX
- document converter versions and operator compatibility
- load ONNX in MQL5 using the native ONNX runtime APIs
- run ONNX side-by-side with the current TSV scorer in SHADOW mode
- compare ONNX, TSV, and Python predictions
- keep the TSV scorer as the accepted fallback during the spike

Acceptance gate:

- ONNX model loads in Strategy Tester
- ONNX outputs are shape-stable and type-stable
- ONNX classifier probabilities match Python within accepted tolerance
- ONNX and TSV threshold decisions agree on the same prediction rows
- runtime diagnostics clearly fail visible without affecting trading behavior

## Phase 5: Multi-Symbol Research

**Planner plan**: `docs/plans/ml-multi-symbol-research-plan.md`
**Risk level**: Medium, statistical generalization

Research whether symbol-specific or multi-symbol models generalize better.

Recommended scope:

- collect comparable datasets for at least XAUUSD and one or two additional
  symbols
- normalize candidate features by R, point value, ATR, spread, or symbol-neutral
  ratios where practical
- compare symbol-specific models against a global model
- evaluate global models with and without symbol identity features
- report metrics per symbol and on held-out symbols
- define threshold policy per symbol if global model behavior differs by market

Acceptance gate:

- no model is promoted across symbols without symbol-level holdout evidence
- global model is rejected if it only improves aggregate metrics while degrading
  a target symbol
- documentation states which symbols each artifact is valid for
- Strategy Tester validation remains symbol-scoped

## Phase 6: Dynamic R Target Modeling

**Planner plan**: `docs/plans/ml-dynamic-r-targets-plan.md`
**Risk level**: High, labeling and future execution behavior

Prepare the model to estimate whether a signal is more likely to reach `1:n`
targets without introducing target leakage.

Recommended scope:

- export post-entry path statistics for broker-entered signals
- label counterfactual target hits before SL, such as `hit_1r_before_sl`,
  `hit_1_5r_before_sl`, `hit_2r_before_sl`, and `hit_3r_before_sl`
- export `max_favorable_r`, `max_adverse_r`, and bars-to-target fields
- train research models for target reachability and expected R
- compare fixed TP policy against model-selected target policy in research only
- keep runtime TP changes out of scope until a later explicit execution plan

Acceptance gate:

- labels are produced without using future information as input features
- path labels are reproducible from Strategy Tester history
- model target choice improves out-of-sample expected R after costs
- selected target counts are large enough to avoid bucket overfit
- no EA runtime changes TP dynamically in this phase

## Roadmap Exit Criteria

This roadmap can be considered complete when:

- validation hardening is the default way to approve models
- simultaneous deterministic strategy candidates can be reduced to one selected
  broker candidate in Strategy Tester
- schema v2 feature additions are either accepted with evidence or rejected with
  documented reasons
- ONNX is either accepted as a shadow-compatible runtime path or explicitly
  deferred
- symbol scope is explicit for every trained model artifact
- dynamic R target modeling has research-grade labels and a clear decision on
  whether runtime execution changes are justified

## Documentation And Evidence Policy

- Each phase plan must define its generated evidence files before implementation
  starts.
- Phase evidence should live under `docs/research/` while active and move under
  `docs/research/archive/` when completed.
- Completed phase plans should move under `docs/plans/archive/` with a dated
  folder.
- The compact workflow reference should be updated only after accepted behavior
  changes become the new operational process.

## Rollback Strategy

- Keep `ML_INFERENCE_DISABLED` as the default runtime mode.
- Keep existing accepted TSV scorer available until any replacement is proven.
- Preserve schema v1 parsing and artifact validation until schema v2 is fully
  accepted and migration is explicit.
- Gate any changed Strategy Tester behavior behind explicit inputs or modes
  until acceptance evidence passes.
- Revert to the last accepted model export and workflow if any phase fails its
  parity, validation, or Strategy Tester gate.

## Potential Risks And Gotchas

- A stronger holdout policy may make the current model look weaker; this is a
  useful finding, not a failure.
- Candidate arbitration changes backtest exposure, so historical performance
  will not be directly comparable to pre-arbitration FILTER runs.
- Candle pattern buckets can look predictive because of small sample effects;
  prefer numeric ratios and ablation checks.
- Structure type features are categorical; treating them as ordinal numeric
  values can create misleading splits.
- Multi-symbol data can improve aggregate metrics while hurting the deployment
  symbol.
- Dynamic target labels are not available from the current closed-trade outcome
  contract; they require path-aware export.
- ONNX may be operationally simpler later, but it must prove parity and
  Strategy Tester stability before replacing the current scorer.
