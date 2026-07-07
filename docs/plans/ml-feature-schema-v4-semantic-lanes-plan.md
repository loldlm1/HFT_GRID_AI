# Plan: ML Feature Schema V4 Semantic Lanes

**Generated**: 2026-07-07
**Estimated Complexity**: High
**Roadmap Phase**: Phase 3 follow-up of
`docs/plans/ml-robustness-and-signal-selection-roadmap.md`
**Risk Level**: High, EA/Python/model feature contract and Strategy Tester
research workflow

## Overview

Pattern audit playback proved that selected-pattern admission can match offline
expectations, but the schema v3 feature surface is too noisy for robust pattern
selection and XGBoost training. The current contract includes spread/range
context, redundant macro derivatives, raw Fibonacci values, chain score stacks,
and execution-context features that can make patterns look stronger than their
signal logic really is.

This follow-up replaces the active research feature contract with schema v4:
a smaller, semantic, lane-based feature surface. Each lane is deterministic,
available before entry, and has exactly one value per signal. This makes DuckDB
pattern audit and XGBoost learn from the same clear signal composition instead
of from ambiguous or duplicated feature encodings.

The key modeling decision is to split chain behavior into two independent lanes:

- `high_chain_profile`: one value describing recent high continuity.
- `low_chain_profile`: one value describing recent low continuity.

This allows a valid tree such as
`high_chain_profile=HIGH_UP_10 && low_chain_profile=LOW_UP_5`. That is not
ambiguous because each condition belongs to a different lane. A single column
named `chain_profile` must not be used for both conditions because one signal
cannot hold two values in the same categorical column.

## Prerequisites

- Existing schema v3 exporter, dataset builder, XGBoost trainer, pattern audit,
  and Strategy Tester playback flow.
- Completed strategy-scoped pattern filter work:
  `docs/plans/ml-pattern-audit-strategy-scoped-filter-plan.md`.
- Current evidence in:
  `docs/research/ml-feature-schema-v2-acceptance.md`.
- MetaEditor compile helper from `docs/environment/mt5-agentic-workflows.md`.
- Human-in-the-loop Strategy Tester for fresh S1/S2/S3 export runs after the
  schema changes compile.

Generated Strategy Tester exports, datasets, models, pattern audits, playback
files, and Common Files packages remain out of git. Commit only source, plans,
and compact evidence updates.

## Non-Goals

- No live deployment approval.
- No runtime FILTER approval unless a later validation gate explicitly passes.
- No ONNX work.
- No multi-symbol proof.
- No dynamic `1:n` target labels.
- No spread, range, or execution-cost context as ML features in schema v4.
- No weakening of license, session, spread, broker stops/freeze, volume,
  margin, protection, market-status, magic-number, or broker reconciliation
  controls.

## Schema V4 Target Contract

Schema v4 should keep the active model and pattern audit surface small:

| Lane | Column | Type | Notes |
| --- | --- | --- | --- |
| Strategy | `strategy_label` | categorical | Keep for combined S1/S2/S3 datasets; exclude when training single-strategy models if constant. |
| Direction | `direction` | categorical | `BULLISH` or `BEARISH`. |
| Structure | `structure_0` | categorical | Current source extremum structure. |
| Structure | `structure_1` | categorical | Most recent opposite extremum structure. |
| Structure | `structure_2` | categorical | Previous same-side extremum structure. |
| Macro slope | `macro_h1_slope` | categorical/int | Current H1 MA slope direction. |
| Macro slope | `macro_h4_slope` | categorical/int | Current H4 MA slope direction. |
| Macro slope | `macro_d1_slope` | categorical/int | Current D1 MA slope direction. |
| Fibonacci | `fib_sl_band` | categorical | One band for the stop anchor. |
| Fibonacci | `fib_entry_band` | categorical | One band for the entry reference. |
| Chain | `high_chain_profile` | categorical | Longest deterministic high chain profile. |
| Chain | `low_chain_profile` | categorical | Longest deterministic low chain profile. |
| Candle | `previous_candle_profile` | categorical | One profile for closed `candle_1`. |
| Session | `entry_session_bucket` | categorical | Keep current broker-time buckets. |
| Calendar | `entry_weekday` | categorical | Broker-time weekday at entry. |

Current broker-time session buckets remain unchanged for this follow-up:

- `ASIA`: hour `00:00` through `06:59`.
- `LONDON`: hour `07:00` through `11:59`.
- `NEWYORK`: hour `12:00` through `20:59`.
- `OFFHOURS`: hour `21:00` through `23:59`.

Schema v4 should retire these active ML/pattern features:

- `source_type`, because it is currently redundant with `direction`.
- `strategy_id`, `strategy_delay_period`, `confirmation_timeframe_minutes` for
  active ML features; they may remain operational metadata if needed.
- `entry_direction_macro_alignment`, `macro_alignment_score`, because they are
  derived from `direction + macro_h1/h4/d1`.
- `prev_body_ratio`, `prev_upper_wick_ratio`, `prev_lower_wick_ratio`,
  `prev_close_location`, `prev_candle_dir` as separate model features; replace
  with `previous_candle_profile`.
- `sl_fib_raw`, `entry_fib_raw`; replace with categorical bands only.
- `low_chain_score_3`, `low_chain_score_5`, `low_chain_score_10`,
  `high_chain_score_3`, `high_chain_score_5`, `high_chain_score_10`; replace
  with the two chain profile lanes.
- `recent_m1_range_points`, `recent_m1_body_ratio_avg`,
  `recent_m1_directional_balance`, `entry_spread_points`,
  `spread_to_recent_range_ratio`.

## Sprint 1: V4 Contract And Naming

**Goal**: Freeze the schema v4 semantic-lane contract before implementation.
**Commit**: `docs: define schema v4 semantic lanes`
**Demo/Validation**:

- Evidence states the exact active schema v4 columns.
- Retired schema v3 columns are listed with the reason for removal.
- Chain and candle labels are unambiguous.

Execution must complete and validate this sprint before moving to Sprint 2.

### Task 1.1: Record V4 Contract

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Add the schema v4 contract, retired-feature rationale, and
  fresh-run policy.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - The contract lists only the schema v4 model/audit lanes.
  - `entry_session_bucket` explicitly remains broker-time with current bucket
    boundaries.
  - `structure_0/1/2` semantics are documented.
- **Validation**:
  - Manual documentation review.
  - `git diff --check`.

### Task 1.2: Define Chain Profile Semantics

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Define high and low chain profile values and precedence.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - `high_chain_profile` chooses one of:
    `HIGH_UP_10`, `HIGH_UP_5`, `HIGH_UP_3`,
    `HIGH_DOWN_10`, `HIGH_DOWN_5`, `HIGH_DOWN_3`, `HIGH_MIXED`.
  - `low_chain_profile` chooses one of:
    `LOW_UP_10`, `LOW_UP_5`, `LOW_UP_3`,
    `LOW_DOWN_10`, `LOW_DOWN_5`, `LOW_DOWN_3`, `LOW_MIXED`.
  - Longest matching chain wins within each lane: `10` before `5` before `3`.
  - `UP` means the most recent closed values are rising relative to older
    closed values, for example `high_1 > high_2 > ...`.
  - `DOWN` means the most recent closed values are falling relative to older
    closed values, for example `high_1 < high_2 < ...`.
- **Validation**:
  - Manual review against intended strategy language.

### Task 1.3: Define Previous Candle Profile Semantics

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Define one deterministic `previous_candle_profile` category
  for closed `candle_1`.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - The profile uses only `candle_1` open/high/low/close.
  - Each signal gets exactly one candle profile.
  - Direction, body tier, and wick dominance rules are deterministic.
  - Thresholds are documented before implementation.
- **Validation**:
  - Manual review of example profiles.

## Sprint 2: MQL5 Schema V4 Export

**Goal**: Update the EA feature exporter and shadow feature snapshot to emit
schema v4 semantic lanes.
**Commit**: `feat: export schema v4 semantic signal lanes`
**Demo/Validation**:

- MetaEditor real compile passes with `0 errors, 0 warnings`.
- A short Strategy Tester smoke export writes schema v4 headers.
- Removed context/spread/raw/score-stack features are absent from the active
  schema v4 feature header.

### Task 2.1: Update Feature Snapshot Struct

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Replace schema v3 feature fields with schema v4 semantic
  fields in the export and shadow-scoring snapshot.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Schema version increments to `4`.
  - Export header and shadow header are aligned.
  - Retired active ML fields are not emitted in schema v4 feature rows.
  - Operational broker/risk controls are untouched.
- **Validation**:
  - MetaEditor compile.

### Task 2.2: Implement Structure Lane Rename

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Emit `structure_0`, `structure_1`, and `structure_2` from
  the same source/opposite/same-previous extrema currently used by schema v3.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `structure_0` equals current source extremum structure.
  - `structure_1` equals most recent opposite extremum structure.
  - `structure_2` equals previous same-side extremum structure.
  - Human labels can still render as `LH[0] | HL[1] | LH[2]`.
- **Validation**:
  - Short export header/content smoke.

### Task 2.3: Implement Chain Profile Lanes

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Replace chain scores with deterministic high/low chain
  profile categories.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - The high lane and low lane are computed independently.
  - Each lane uses only closed `DETERMINISTIC_BASE_TIMEFRAME` candles starting
    at shift `1`.
  - Longest match wins inside the lane.
  - Mixed or insufficient continuity produces the documented mixed/null value.
- **Validation**:
  - Short export smoke.
  - Manual examples for `UP_3`, `UP_5`, `UP_10`, and mixed paths.

### Task 2.4: Implement Candle, Weekday, Fib, Macro, And Session Lanes

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Emit `previous_candle_profile`, `entry_weekday`,
  `fib_sl_band`, `fib_entry_band`, macro slopes, and the current
  `entry_session_bucket`.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `previous_candle_profile` is one category per signal.
  - `entry_weekday` uses broker-time entry timestamp.
  - Fibonacci bands are categorical and raw Fibonacci values are not active
    model features.
  - Session buckets keep the current broker-time boundaries.
- **Validation**:
  - MetaEditor compile.
  - Short Strategy Tester export smoke.

## Sprint 3: Python Dataset And Trainer Contract

**Goal**: Make Python tooling accept schema v4 and train only from the semantic
lane feature set.
**Commit**: `ml: add schema v4 semantic dataset contract`
**Demo/Validation**:

- Python syntax checks pass.
- Dataset builder rejects schema/header mismatches.
- Trainer feature map contains only schema v4 active feature columns.

### Task 3.1: Update Schema Contract

- **Location**:
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Update required Phase 1 columns, model feature columns,
  numeric/categorical groups, and dataset reports for schema v4.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `SUPPORTED_SCHEMA_VERSION = 4`.
  - `MODEL_FEATURE_COLUMNS` contains only the schema v4 active lane columns.
  - Retired schema v3 features are absent from model features and quality
    reports.
  - Dataset manifests record `feature_schema_version=4`.
- **Validation**:
  - `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`
  - Build attempt on a schema v3 run fails with a clear schema mismatch.

### Task 3.2: Update Feature Encoding And Training Defaults

- **Location**:
  - `tools/deterministic_signal_ml/feature_encoder.py`
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/training_report.py`
  - `tools/deterministic_signal_ml/model_validation_config.py`
- **Description**: Make schema v4 semantic lanes the active training feature
  set and remove schema v3 context feature-set assumptions from active training
  paths.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Categorical encoding handles all schema v4 lanes.
  - Single-strategy training can exclude constant `strategy_label` when
    explicitly requested.
  - Default model ID/report labels identify schema v4.
  - No spread/range/context/raw Fibonacci features appear in model feature maps.
- **Validation**:
  - Python syntax check.
  - Feature-map inspection on a small fixture or fresh smoke dataset.

### Task 3.3: Update Model Export And Runtime Feature Map Validation

- **Location**:
  - `tools/deterministic_signal_ml/export_model.py`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - Any local model artifact validators under `tools/deterministic_signal_ml/`
- **Description**: Ensure exported feature maps and MQL5 runtime feature lookup
  expect schema v4 columns only.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Exported feature maps reference schema v4 source columns.
  - MQL5 scorer fails closed on unsupported schema versions.
  - SHADOW/FILTER behavior still cannot bypass broker/risk gates.
- **Validation**:
  - Python syntax check.
  - MetaEditor compile after MQL5 updates.

## Sprint 4: Lane-Safe Pattern Audit

**Goal**: Update DuckDB pattern mining so automatic patterns are built only from
schema v4 semantic lanes and cannot combine redundant versions of the same
concept.
**Commit**: `ml: audit schema v4 semantic patterns`
**Demo/Validation**:

- Pattern audit runs against a schema v4 dataset.
- Human labels are clear and lane-based.
- No automatic pattern uses spread/range, raw Fibonacci, macro derivatives, or
  chain score stacks.

### Task 4.1: Update Pattern Templates

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
- **Description**: Replace schema v3 templates with lane-safe schema v4
  templates.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Structure templates use `structure_0/1/2`.
  - Chain templates can combine `high_chain_profile` and
    `low_chain_profile`.
  - Fibonacci templates use `fib_sl_band` and `fib_entry_band`.
  - Session and weekday templates are separate lanes.
  - No template references spread/range/context/raw columns.
- **Validation**:
  - Python syntax check.
  - Smoke audit on schema v4 fixture or fresh smoke dataset.

### Task 4.2: Update Human Labels And Match Output

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Description**: Render schema v4 pattern labels in human terms for reports
  and Strategy Tester panel display.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Structure labels render like `LH[0] | HL[1] | LH[2]`.
  - Chain labels render like `Highs up 10` and `Lows up 5`.
  - Session labels include current broker-time bucket names.
  - Pattern matches remain keyed for selected-pattern playback.
- **Validation**:
  - Smoke pattern audit.
  - MetaEditor compile if panel parsing changes.

### Task 4.3: Update Playback Parity Normalization

- **Location**:
  - `tools/deterministic_signal_ml/pattern_playback_compare.py`
- **Description**: Normalize MT5 time formatting and handle missing tester
  `signal_id` when source key identity is sufficient.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Comparison passes when expected and observed keys match by
    `pattern_id + source_key + source_attempt_index`.
  - Entry time comparison normalizes `YYYY.MM.DD` and `YYYY-MM-DD` formats.
  - Signal ID mismatch remains reported as metadata warning, not data ambiguity,
    when source-key parity is exact.
- **Validation**:
  - Re-run comparison against the existing S1/S2/S3 playback observations.

## Sprint 5: Fresh S1/S2/S3 V4 Export And Dataset Handoff

**Goal**: Generate fresh schema v4 data per strategy, then build datasets and
audits from the cleaned feature contract.
**Commit**: `docs: record schema v4 strategy data handoff`
**Demo/Validation**:

- Human-in-the-loop Strategy Tester produces fresh S1, S2, and S3 schema v4
  exports.
- Dataset builder validates all three runs.
- Pattern audit packages are generated and copied to Common Files.

### Task 5.1: Compile And Prepare Fresh Run Instructions

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
- **Description**: Record exact Strategy Tester inputs for fresh S1/S2/S3
  schema v4 export runs.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - MQL5 compile command and result are recorded.
  - Run IDs are explicit, for example
    `xauusd_2025_schema_v4_run_S1`, `_S2`, `_S3`.
  - Old schema v3 generated artifacts are not reused for schema v4 validation.
- **Validation**:
  - MetaEditor compile.
  - Manual Strategy Tester setup review.

### Task 5.2: Build Per-Strategy V4 Datasets

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - Generated artifacts under `artifacts/datasets/`
- **Description**: Build S1/S2/S3 datasets from fresh schema v4 runs.
- **Dependencies**: Human Strategy Tester export from Task 5.1.
- **Acceptance Criteria**:
  - Dataset summaries show schema version `4`.
  - Duplicate feature/outcome IDs are zero.
  - Invalid feature rows are zero or explicitly explained.
  - Training matrices contain only schema v4 active model columns.
- **Validation**:
  - Dataset build command for each strategy.
  - Dataset manifest and quality report inspection.

### Task 5.3: Build Per-Strategy V4 Pattern Audits

- **Location**:
  - `tools/deterministic_signal_ml/pattern_audit.py`
  - Generated artifacts under `artifacts/pattern_audits/`
  - MT5 Common Files pattern audit folders
- **Description**: Generate S1/S2/S3 pattern audits with schema v4 labels and
  selected-pattern packages.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Each audit is strategy-scoped with `--strategy-label`.
  - Top patterns are lane-safe and human-readable.
  - Pattern packages are copied to Common Files for tester playback.
- **Validation**:
  - Pattern audit command for each strategy.
  - Pending playback comparison before Strategy Tester pattern-filter runs.

## Sprint 6: V4 XGBoost Research Gate

**Goal**: Train and validate schema v4 XGBoost candidates without using final
holdout to choose thresholds.
**Commit**: `ml: validate schema v4 semantic xgboost`
**Demo/Validation**:

- Global and per-strategy schema v4 candidates are trained.
- Reports compare v4 semantic lanes against rejected v3 evidence.
- No runtime export is approved unless the research gate passes.

### Task 6.1: Train Candidate Models

- **Location**:
  - `tools/deterministic_signal_ml/train_model.py`
  - Generated artifacts under `artifacts/models/`
- **Description**: Train global S1/S2/S3 and per-strategy schema v4 candidates.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Model manifests identify schema v4 and feature set.
  - Feature maps contain only semantic lane features.
  - Constant per-strategy columns are excluded or flagged.
- **Validation**:
  - Training commands complete.
  - Model manifests and feature diagnostics inspected.

### Task 6.2: Run Robustness Validation

- **Location**:
  - `tools/deterministic_signal_ml/validate_model_robustness.py`
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Validate candidates using chronological splits,
  pre-final threshold selection, final holdout approval, and per-segment
  summaries.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Reports include strategy, direction, session, weekday, and pattern-support
    diagnostics.
  - Rare-bucket and feature-importance concentration warnings are recorded.
  - Final holdout remains approval-only.
  - Decision is one of:
    `REJECT_SCHEMA_V4`, `NEEDS_SCHEMA_V4_FOLLOW_UP`, or
    `READY_FOR_TESTER_FILTER_VALIDATION`.
- **Validation**:
  - Robustness command output.
  - Compact evidence update.

### Task 6.3: Decide Next Workflow

- **Location**:
  - `docs/research/ml-feature-schema-v2-acceptance.md`
- **Description**: Decide whether to run pattern-filter Strategy Tester
  playback, prepare a combined audit, continue feature iteration, or reject the
  candidate.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Decision is explicit and dated.
  - If rejected, follow-up work remains in Phase 3.
  - If accepted for tester validation, exact S1/S2/S3 or combined run inputs
    are documented.
- **Validation**:
  - Manual gate review.

## Testing Strategy

- Documentation-only sprint: `git diff --check`.
- MQL5 implementation sprints: MetaEditor real compile, treating warnings as
  failures.
- Python tooling sprints:
  `.venv/bin/python -m py_compile tools/deterministic_signal_ml/*.py`.
- Dataset validation:
  `build_dataset.py` must validate schema version, joins, row counts, and
  quality reports.
- Pattern audit validation:
  smoke audit first, then per-strategy audits, then pending playback comparison.
- Strategy Tester validation:
  human-in-the-loop fresh S1/S2/S3 schema v4 exports before any long combined
  run.
- Research validation:
  chronological threshold selection and untouched final holdout gate.

## Potential Risks And Gotchas

- Chain naming can be misunderstood if `UP`/`DOWN` is tied to bullish/bearish
  language. The implementation should define `UP` and `DOWN` only by price
  ordering, while `direction` remains a separate feature.
- Removing context/spread features may lower apparent pattern performance. That
  is acceptable if it removes non-signal ambiguity.
- `entry_weekday` can overfit one calendar year quickly. It should be retained
  only when support is broad and final-holdout behavior is positive.
- Current session buckets are broker-time buckets, not exchange-session truth.
  This is intentional for now and must be documented in reports.
- If schema v4 removes active columns used by existing model artifacts, old
  generated artifacts should be treated as superseded research outputs, not
  runtime candidates.
- Pattern audit and XGBoost must use the same active feature contract. If one
  includes retired columns and the other does not, evidence becomes ambiguous
  again.
- Fresh Strategy Tester exports are required. Schema v3 runs cannot validate
  schema v4.

## Rollback Plan

- Revert schema v4 source commits if compile or dataset validation fails.
- Keep generated schema v4 artifacts out of git and delete them from
  `artifacts/` and MT5 Common Files if invalid.
- Return to the last committed schema v3 code for research-only playback while
  planning a smaller schema v4 correction.
- Do not approve runtime FILTER export from any failed or partially validated
  schema v4 candidate.
