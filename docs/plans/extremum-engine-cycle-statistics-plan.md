# Plan: Single Extremum Engine And Cycle Statistics

**Generated**: 2026-07-10
**Status**: Sprints 1-7 implementation complete; human Strategy Tester and
performance acceptance pending
**Estimated Complexity**: Critical
**Risk Class**: Critical, because removing the M1 and macro MA gates changes which candidates can reach broker admission and can materially increase trade frequency even though broker, license, session, margin, spread, protection, and reconciliation controls remain mandatory.

## Overview

Replace the active S1/S2/S3 deterministic strategy stack with one always-on M1
extremum engine. The engine uses the current/provisional Stoch Structure extremum
at slot `0` as its intrinsic source, maps `BOTTOM` to bullish and `PEAK` to
bearish, preserves the existing live `high_1`/`low_1` breakout entry contract,
and removes M1-delay and macro-MA confirmation from both candidate creation and
entry activation.

Add a simple event genealogy around every provisional extremum:

```text
extremum cycle
  -> extremum revision
    -> intrinsic attempt
      -> broker admission events
      -> optional broker execution
      -> simulated path outcome
      -> broker-confirmed outcome
```

Each cycle freezes its Fibonacci reference anchors when the cycle begins. Every
revision and attempt records raw Fibonacci depth, range size in points, and
distance from prior revisions/attempts. MQL5 exports stable raw facts; Python and
DuckDB derive human-readable Fibonacci proximity, range buckets, profitability
by attempt depth, and cycle-sequence profitability. XGBoost tooling consumes a
new schema without mixing legacy S1/S2/S3 data or leaking final-cycle facts into
point-in-time features.

The implementation must remain deliberately narrow: one M1 engine now, with a
timeframe field in the data contract so a later plan can instantiate the same
engine on M3/M5/M10 without redesigning identity or storage.

## Lifecycle Impact And Verification Position

- **Affected lifecycle stages**: input/configuration, indicator hydration,
  intrinsic signal detection, pending candidate identity, entry activation,
  statistics export, ML/pattern compatibility, dataset assembly, and research
  reporting.
- **Unchanged hard controls**: license, symbol/magic scope, hedging guard,
  direction mode, session gates, daily limits, concurrency, spread, market
  status, stops/freeze, volume normalization, margin/precheck, protection,
  broker reconciliation, EA-managed exits, partial TP, and broker-confirmed
  outcome requirements.
- **Primary verification**: one real MetaEditor compile at the end of every MQL5
  sprint, followed by human-in-the-loop Strategy Tester scenarios. No custom
  MQL5 tests or CI are introduced.
- **Research verification**: schema fixtures and Python `unittest`, strict TSV
  validation, DuckDB dataset assembly, human audit reports, chronological and
  cycle-group leakage checks, and a bounded Strategy Tester performance
  comparison.

## Implementation Record

The ordered implementation batch completed on 2026-07-10. Automated evidence
is recorded in `docs/research/extremum-engine-statistics-implementation-evidence.md`.
The plan remains active because the required human Strategy Tester matrix and a
real export-disabled versus schema-v7 performance/storage comparison have not
yet been executed or accepted.

| Sprint | Commit | Automated status |
| --- | --- | --- |
| 1 | `c50aa57` | Implemented; MetaEditor PASS |
| 2 | `b6ffd3c` | Implemented; MetaEditor PASS |
| 3 | `9797151` | Implemented; MetaEditor PASS |
| 4 | `203478a` | Implemented; Python/schema fixtures PASS |
| 5 | `2b23cd4` | Implemented; DuckDB audit fixture PASS |
| 6 | `521e038` | Implemented; MetaEditor and Python PASS |
| 7 | `docs: close extremum engine statistics workflow` | Documentation and final automated validation complete |

Human acceptance is deliberately not inferred from compilation or synthetic
fixtures. The unchecked human/performance gates in this plan remain binding.

## Scope

### In Scope

- Remove public `Enable_Strategy_1`, `Enable_Strategy_2`, and
  `Enable_Strategy_3` inputs.
- Replace active S1/S2/S3 identity with one stable non-zero engine identity,
  suggested label `EXTREMUM_V1`.
- Remove S1/S2/S3 base-delay and macro-timeframe decision logic, shifted MA
  visual overlays, macro visual chart ownership, and multi-strategy ML
  arbitration.
- Generate only the structurally valid direction:
  - current `BOTTOM` -> bullish intrinsic candidate;
  - current `PEAK` -> bearish intrinsic candidate.
- Remove MA confirmation from:
  - initial deterministic candidate creation;
  - final pre-send entry activation.
- Preserve live M1 breakout entry, dynamic pending anchor refresh, captured
  extremum SL anchor, TP/risk geometry, partial TP, and broker-first execution.
- Add M1 extremum cycle, revision, and cycle-attempt identity.
- Freeze Fibonacci anchors at cycle start from the stable slot `1`/slot `2`
  completed structural range.
- Record raw depth percentages without clamping, including values below `0` or
  above `100`.
- Record range and revision/attempt distances in symbol points.
- Capture intrinsic attempts before operational attempt gates so session,
  concurrency, direction, daily limit, Algo Trading, and protection denials do
  not erase the engine census.
- Track a bounded simulated path for every intrinsic attempt, clearly separated
  from broker-confirmed outcomes.
- Add schema v7 run files for cycles, revisions, and attempts while preserving
  existing broker admission and broker outcome files.
- Add Python validation, Parquet assembly, DuckDB human audit, schema v7 feature
  selection, cycle-group chronological splits, and stale-artifact rejection.
- Update active workflow, environment, README, and project instruction text that
  still describes S1/S2/S3 or shifted MA validation as active behavior.

### Out Of Scope

- Running active M3/M5/M10 engine instances or opening trades from those
  timeframes.
- Using M3/M5/M10 levels as execution anchors for M1 signals.
- Entering immediately at the extremum instead of waiting for the existing
  `high_1`/`low_1` breakout.
- Changing lot sizing, TP percentages, partial TP levels/fractions, SL close
  semantics, broker admission, or protection rules.
- Enabling ML FILTER outside its existing Strategy Tester-only boundary.
- Training, approving, exporting, deploying, or promoting a new live model as
  part of this plan. Training commands validate readiness only.
- Reusing or relabeling legacy S1/S2/S3 datasets as schema v7 evidence.
- Adding an external database, service, queue, network dependency, or MQL5 test
  harness.
- Adding chart-heavy revision visualization in the first implementation.
- Treating price range in points as real traded volume. Tick/real volume can be
  a later contextual extension.

### Fixed Decisions

- The engine is always active; do not replace the three strategy toggles with a
  new `Enable_Engine` input.
- The initial engine timeframe is fixed to `PERIOD_M1`.
- Detection remains gated on a new closed M1 bar; tick processing continues to
  manage pending and active execution.
- Slot `0` remains the provisional source of truth. Slot `1` is confirmation and
  context, not the entry source.
- `BOTTOM` can create only bullish attempts and `PEAK` only bearish attempts.
- M1 and macro MA values may remain passive research context only; they cannot
  block candidate creation, entry, exit, lot size, SL/TP, or broker admission.
- A cycle remains the same while the provisional extremum type remains the same,
  even when extremum time and price move deeper. A type transition finalizes the
  prior cycle.
- A cycle open at tester/deinit end is written as censored/unfinalized, not
  confirmed.
- Fibonacci reference anchors are immutable after cycle creation.
- MQL5 exports raw depth and distance values. DuckDB derives nearest Fibonacci
  level, Fibonacci delta, and configurable range/depth buckets.
- Simulated attempt outcomes and broker-confirmed outcomes use separate columns,
  files, and explicit source labels. Simulated facts must never satisfy broker
  outcome predicates.
- Existing schema v4/v5/v6 readers remain available for historical artifacts,
  but schema v7 runs cannot be mixed with old schemas in one dataset.
- Old model exports, pattern selections, and arbitration artifacts must fail
  closed against `EXTREMUM_V1`/schema v7.

### Assumptions

- The stable cycle reference for a developing `BOTTOM` is the completed prior
  `PEAK` at slot `1` and comparable prior `BOTTOM` at slot `2`; for a developing
  `PEAK`, the orientation is reversed. The implementation validates alternating
  types and positive range before creating the cycle.
- Existing Fibonacci percent orientation remains desirable:
  - developing `PEAK`: `(current_peak - reference_bottom) / reference_range`;
  - developing `BOTTOM`: `(reference_peak - current_bottom) / reference_range`.
- The exact-price source identity used by execution becomes a revision identity,
  while the new parent `extremum_cycle_id` remains stable across deeper prices.
- `cycle_attempt_index` increments across all attempts in the cycle. A separate
  revision identity makes it possible to distinguish multiple attempts on one
  revision from attempts after a deeper revision.
- A TP consumes the exact revision/source as it does today. A later deeper
  revision in the same cycle may create a new intrinsic attempt unless a later
  product decision changes that policy.
- Active broker positions preserve their captured source and risk geometry when
  the provisional cycle revises; only no-exposure pending execution is expired
  and replaced.
- Human reports use both `attempt_count` and `distinct_cycle_count` so repeated
  attempts from a few cycles do not appear statistically independent.
- No clarification is blocking plan creation. These assumptions should be
  reviewed at the Sprint 1 execution kickoff; changing any fixed decision
  requires updating this plan before implementation continues.

## Target Data Contract

Schema v7 adds three append-only logical datasets while retaining existing
broker-first files:

| File | Grain | Purpose |
| --- | --- | --- |
| `engine_cycles.tsv` | One final/censored row per cycle | Frozen anchors, first/final extremum, total revisions/attempts, final depth, lifecycle status |
| `engine_revisions.tsv` | One row per observable slot `0` revision | Point-in-time extremum, raw Fibonacci depth, point distances, structure/context snapshot |
| `engine_attempts.tsv` | One final/censored row per intrinsic attempt | Revision linkage, attempt depth, trigger status, operational admission, simulated path result, broker signal linkage |
| `signal_admissions.tsv` | Existing broker admission events | Real execution admission facts, enriched with engine/cycle/revision/attempt IDs |
| `signal_features.tsv` | Existing broker-entered feature snapshot | Broker-entered feature facts, renamed to engine identity in schema v7 |
| `signal_outcomes.tsv` | Existing broker-confirmed signal outcome | Real broker outcome only, enriched with engine/cycle/revision/attempt IDs |
| `signal_leg_outcomes.tsv` | Existing broker-confirmed leg outcome | Ticket/leg facts only, enriched with engine/cycle/revision/attempt IDs |

Minimum cycle fields:

```text
schema_version, run_id, config_id, symbol, engine_id, engine_label,
engine_timeframe, extremum_cycle_id, extremum_type, cycle_first_seen_time,
cycle_finalized_time, cycle_status, reference_peak_time, reference_peak_price,
reference_bottom_time, reference_bottom_price, reference_range_points,
first_extremum_time, first_extremum_price, final_extremum_time,
final_extremum_price, final_depth_percent, revision_count, attempt_count
```

Minimum revision fields:

```text
extremum_cycle_id, revision_id, revision_index, snapshot_time,
extremum_time, extremum_price, extremum_type, depth_percent_raw,
distance_from_first_revision_points, distance_from_previous_revision_points,
depth_delta_from_previous_percent, bars_since_cycle_start,
structure_0, structure_1, structure_2, session_id, time_sin, time_cos
```

Minimum attempt fields:

```text
extremum_cycle_id, revision_id, attempt_id, cycle_attempt_index,
revision_attempt_index, attempt_created_time, candidate_depth_percent,
trigger_price, stop_anchor_price, trigger_reached, trigger_time,
attempt_status, operational_block_source, operational_block_reason,
simulated_terminal_reason, simulated_profit_r, simulated_max_favorable_r,
simulated_max_adverse_r, simulated_path_status, simulated_outcome_source,
broker_signal_id, broker_entry_confirmed, broker_close_confirmed
```

Derived-only DuckDB fields must not be written as MQL5 source facts unless a
later plan requires runtime use:

```text
nearest_fib_level, fib_distance_percent, fib_zone, range_bucket,
attempt_win_rate, attempt_avg_profit_r, cycle_total_profit_r,
cycle_sequence_status, profitable_month_count, distinct_cycle_count
```

## Named Resources

### Project Instructions And Architecture

- `AGENTS.md`
- `HFT_Grid_AI.mq5`
- `services/trading_management.mqh`
- `services/trading_signals.mqh`
- `docs/architecture/execution-foundation.md`
- `docs/environment/mt5-agentic-workflows.md`
- `docs/workflows/deterministic-signal-ml-inference-flows.md`
- `docs/plans/README.md`

### MQL5 Implementation Files

- `services/core/enums.mqh`
- `services/trading_management/ea_inputs.mqh`
- `services/trading_management/deterministic_strategy_config.mqh` (replace/remove)
- `services/trading_management/extremum_engine_config.mqh` (new)
- `services/trading_management/indicator_definitions_loader.mqh`
- `services/indicators/extrema_detector.mqh`
- `services/indicators/stochastic_market_indicator.mqh`
- `services/indicators/fibonacci_calculator.mqh`
- `services/trading_signals/signal_params_struct.mqh`
- `services/trading_signals/extremum_engine_state.mqh` (new)
- `services/trading_signals/market_signal_state.mqh`
- `services/trading_signals/market_signal_indicators.mqh`
- `services/trading_signals/market_signal_filters.mqh`
- `services/trading_signals/market_signal_detection.mqh`
- `services/trading_signals/execution_leg_helpers.mqh`
- `services/trading_signals/execution_controller.mqh`
- `services/trading_signals/execution_lifecycle.mqh`
- `services/trading_signals/execution_logging.mqh`
- `services/trading_signals/tick_signals_manager.mqh`
- `services/trading_signals/deterministic_signal_statistics_export.mqh`
- `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- `services/trading_signals/deterministic_signal_ml_arbitration.mqh` (remove from active code and delete if no historical runtime consumer remains)
- `services/frontend/lightweight_status_ui.mqh`

### Python And DuckDB Files

- `tools/deterministic_signal_ml/schema_contract.py`
- `tools/deterministic_signal_ml/validate_phase1_run.py`
- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/segment_metrics.py`
- `tools/deterministic_signal_ml/pattern_audit.py`
- `tools/deterministic_signal_ml/extremum_engine_audit.py` (new)
- `tools/deterministic_signal_ml/validation_splits.py`
- `tools/deterministic_signal_ml/feature_encoder.py`
- `tools/deterministic_signal_ml/model_config.py`
- `tools/deterministic_signal_ml/train_model.py`
- `tools/deterministic_signal_ml/model_artifact_contract.py`
- `tools/deterministic_signal_ml/export_model_artifact.py`
- `tools/deterministic_signal_ml/model_artifact_validator.py`
- `tools/deterministic_signal_ml/tests/test_extremum_engine_schema.py` (new)
- `tools/deterministic_signal_ml/tests/test_extremum_engine_audit.py` (new)
- `tools/deterministic_signal_ml/tests/fixtures/schema_v7_extremum_engine/` (new, compact synthetic TSV fixture only)
- `tools/deterministic_signal_ml/README.md`

### Documentation Files

- `README.md`
- `AGENTS.md`
- `docs/architecture/execution-foundation.md`
- `docs/workflows/deterministic-signal-ml-inference-flows.md`
- `docs/workflows/extremum-engine-statistics-flow.md` (new)
- `docs/environment/mt5-agentic-workflows.md`

### External Documentation

- MQL5 `CopyBuffer`: https://www.mql5.com/en/docs/series/copybuffer
- MQL5 `iBarShift`: https://www.mql5.com/en/docs/series/ibarshift
- MQL5 `FileOpen` and `FILE_COMMON`: https://www.mql5.com/en/docs/files/fileopen
- DuckDB CSV import: https://duckdb.org/docs/stable/data/csv/overview
- DuckDB window functions: https://duckdb.org/docs/stable/sql/functions/window_functions
- XGBoost Python API: https://xgboost.readthedocs.io/en/stable/python/python_api.html

### Validation And Operational Resources

- MetaEditor helper: `tools/mt5/compile_mt5.py`
- Canonical MT5 root: `C:\Program Files\MetaTrader 5-1`
- Ubuntu/Wine observed root:
  `/home/loldlm/mql5_projects/metatrader_5_market_data_framework`
- MT5 Common Files root from `docs/environment/mt5-agentic-workflows.md`
- Python environment: `.venv/bin/python` or Windows `.\.venv\Scripts\python.exe`
- Existing pinned dependencies in `tools/deterministic_signal_ml/requirements.txt`;
  do not add a dependency for schema/audit tests.

## Prerequisites

- Confirm the implementation starts from a clean or intentionally understood
  worktree and does not revert user-owned changes.
- Mark this document as the active implementation plan in
  `docs/plans/README.md` only when implementation is separately authorized.
- Record a baseline real MetaEditor compile with zero errors and zero warnings.
- Record one short baseline Strategy Tester run with all three current strategy
  toggles enabled, ML disabled, feature export enabled, and artifact counts
  summarized without pasting full TSV/log contents.
- Preserve a copy or immutable identifier for the baseline schema v6 run so
  regression comparisons do not overwrite historical evidence.
- Verify `.venv` dependencies match `requirements.txt` and DuckDB can read the
  existing schema v6 fixture/run before adding v7 support.
- Keep `ML_Inference_Mode=ML_INFERENCE_DISABLED` for the first schema v7 tester
  evidence. Old model exports are not valid acceptance evidence.

## Sprint 1: Replace S1/S2/S3 With One Extremum Engine

**Goal**: Deliver a runnable EA with one stable `EXTREMUM_V1` engine, no public
strategy toggles, no MA decision gates, and unchanged breakout/risk/broker
behavior outside the requested signal expansion.

**Dependencies**: Prerequisites complete.

**Tracked scope**: `services/core/enums.mqh`,
`services/trading_management/ea_inputs.mqh`,
`services/trading_management/deterministic_strategy_config.mqh`,
`services/trading_management/extremum_engine_config.mqh`,
`services/trading_management/indicator_definitions_loader.mqh`,
`services/trading_management.mqh`, `services/trading_signals.mqh`,
`services/trading_signals/signal_params_struct.mqh`,
`services/trading_signals/market_signal_filters.mqh`,
`services/trading_signals/market_signal_detection.mqh`,
`services/trading_signals/execution_controller.mqh`,
`services/trading_signals/execution_leg_helpers.mqh`,
`services/trading_signals/execution_logging.mqh`,
`services/trading_signals/deterministic_signal_ml_arbitration.mqh`,
`services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`,
`services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`,
`services/frontend/lightweight_status_ui.mqh`, `HFT_Grid_AI.mq5`.

**Commit**: `refactor: replace deterministic strategies with extremum engine`

**Demo/Validation**:

- `python3 tools/mt5/compile_mt5.py` using the documented Wine/Windows arguments.
- Inspect EA inputs and confirm the three `Enable_Strategy_*` inputs are gone.
- Strategy Tester visual/manual scenario confirms:
  - a slot `0` BOTTOM creates only a bullish candidate;
  - a slot `0` PEAK creates only a bearish candidate;
  - no M1-delay or macro-MA condition blocks candidate creation;
  - entry still waits for the existing live `high_1`/`low_1` breakout;
  - spread/session/margin/protection/license and magic/symbol scope remain active.
- Static search confirms no active S1/S2/S3 input/config/arbitration paths remain.

**Rollback point**: The pre-sprint baseline commit and schema v6 tester run.
Reverting the single Sprint 1 commit restores the three-strategy behavior and
its existing artifact compatibility.

### Task 1.1: Define The Single Engine Identity And Input Surface

- **Location**: `services/core/enums.mqh`,
  `services/trading_management/ea_inputs.mqh`,
  `services/trading_management/extremum_engine_config.mqh`,
  `services/trading_management/deterministic_strategy_config.mqh`,
  `services/trading_management.mqh`.
- **Description**: Replace the three strategy enum values and config helpers
  with one non-zero engine ID, label, and fixed M1 timeframe. Remove the three
  public toggles and fixed 3/5/10 base delays plus M3/M5/M10 macro mappings. Do
  not retain compatibility aliases or deprecated inputs.
- **Dependencies**: None.
- **Acceptance criteria**:
  - One stable engine identity is available to comments, state, statistics, and
    ML compatibility checks.
  - No active function needs a strategy index loop.
  - Existing enum ordinals unrelated to removed strategies remain unchanged.
- **Validation**:
  - `rg -n 'Enable_Strategy_|DETERMINISTIC_STRATEGY_[123]|DETERMINISTIC_S[123]_BASE_DELAY' services HFT_Grid_AI.mq5`
  - MetaEditor compile at sprint end.
- **Rollback**: Restore the removed config/input definitions through Sprint 1
  commit reversion only; do not add shims.

### Task 1.2: Replace Strategy Identity In Signal And Broker Metadata

- **Location**: `services/trading_signals/signal_params_struct.mqh`,
  `services/trading_signals/execution_leg_helpers.mqh`,
  `services/trading_signals/execution_logging.mqh`, broker comment/key helpers.
- **Description**: Rename active identity fields and helpers from strategy to
  engine vocabulary, remove delay/macro fields, and generate stable engine
  source keys/comments without changing magic-number or symbol scope.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - Constructors/copy constructors preserve all engine fields.
  - Source keys remain non-empty and deterministic.
  - Broker comments remain bounded and reconcile to the same engine signal.
  - No broker ticket, volume, entry, close, or realized profit ownership rule
    changes.
- **Validation**:
  - Static constructor/copy review.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 1 as one unit because identity and comment changes
  are cross-module.

### Task 1.3: Simplify Candidate Detection To Structural Direction

- **Location**: `services/trading_signals/market_signal_detection.mqh`,
  `services/trading_signals/market_signal_filters.mqh`,
  `services/trading_signals/market_signal_indicators.mqh`.
- **Description**: Replace the strategy/direction nested loop with one direction
  derived from slot `0`. Remove `EvaluateDeterministicBaseSetup()` and macro
  confirmation from candidate creation while preserving extremum validation,
  source capture, raw breakout/stop geometry, dedupe, daily/concurrency policy,
  and execution planning.
- **Dependencies**: Tasks 1.1 and 1.2.
- **Acceptance criteria**:
  - A valid BOTTOM cannot create a bearish candidate.
  - A valid PEAK cannot create a bullish candidate.
  - MA data availability cannot suppress an otherwise valid intrinsic candidate.
  - Invalid extremum/range/entry geometry still fails closed.
- **Validation**:
  - Static call-graph review.
  - Strategy Tester PEAK/BOTTOM candidate review.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 1.

### Task 1.4: Remove Entry-Time MA Reconfirmation

- **Location**: `services/trading_signals/execution_controller.mqh`,
  `services/trading_signals/execution_logging.mqh`.
- **Description**: Remove M1-delay and macro-MA expiry/reconfirmation from
  `PrepareDeterministicPendingEntryAdmission()`. Preserve both breakout checks,
  pending anchor refresh, broker admission ordering, ML/pattern gates where
  schema-compatible, and all execution risk controls.
- **Dependencies**: Task 1.3.
- **Acceptance criteria**:
  - Entry activation depends on breakout plus existing operational/broker gates,
    not MA slope.
  - No removed confirmation log reason remains active.
  - Broker admission still occurs after trigger validation and before send.
- **Validation**:
  - Static ordering review around trigger, admission, ML/pattern, and send.
  - Strategy Tester scenario where old MA logic would have expired the candidate
    but the new engine reaches broker admission.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 1.

### Task 1.5: Remove Obsolete Visual And Multi-Strategy Runtime Paths

- **Location**: `services/trading_management/indicator_definitions_loader.mqh`,
  `services/trading_signals/deterministic_signal_ml_arbitration.mqh`,
  `services/trading_signals.mqh`,
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`,
  `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`,
  `services/frontend/lightweight_status_ui.mqh`.
- **Description**: Remove shifted M1 MA overlays, macro chart creation, and
  S1/S2/S3 arbitration. Keep only indicator handles required by the M1 engine
  and passive export context. Reject old strategy-scoped model/pattern artifacts
  rather than silently applying them to the new engine.
- **Dependencies**: Tasks 1.1 through 1.4.
- **Acceptance criteria**:
  - No per-strategy visual chart or arbitration state is created.
  - Logic handles are cached and released normally.
  - Old artifacts produce an explicit unavailable/schema mismatch reason.
  - SHADOW remains non-invasive and FILTER remains Strategy Tester only.
- **Validation**:
  - MetaEditor compile at sprint end.
  - OnInit/OnDeinit handle and chart cleanup review.
  - Tester startup with an old export confirms fail-closed incompatibility.
- **Rollback**: Revert Sprint 1.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] One real MetaEditor compile reports 0 errors and 0 warnings.
- [ ] Human Strategy Tester evidence covers PEAK, BOTTOM, breakout, and at least
  one operational/broker denial.
- [ ] No license, protection, spread, margin, volume, session, magic, symbol, or
  reconciliation control was weakened.
- [ ] Residual behavior differences are documented.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] The rollback commit/hash and baseline artifact ID are recorded.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Add Cycle, Revision, Attempt, And Fibonacci Depth State

**Goal**: Make repaint/deepening behavior explicit and deterministic without yet
changing the external schema files.

**Dependencies**: Sprint 1 gate complete.

**Tracked scope**: `services/trading_signals/extremum_engine_state.mqh`,
`services/trading_signals.mqh`,
`services/trading_signals/signal_params_struct.mqh`,
`services/trading_signals/market_signal_indicators.mqh`,
`services/trading_signals/market_signal_state.mqh`,
`services/trading_signals/market_signal_detection.mqh`,
`services/trading_signals/tick_signals_manager.mqh`,
`services/trading_signals/execution_logging.mqh`.

**Commit**: `feat: track extremum cycles revisions and depth`

**Demo/Validation**:

- `python3 tools/mt5/compile_mt5.py` using documented arguments.
- Human Strategy Tester visual sequence where one BOTTOM or PEAK deepens across
  at least two closed M1 bars.
- Compact logs show one stable `extremum_cycle_id`, increasing revision indexes,
  increasing cycle attempt indexes, frozen reference anchors, raw depth, and
  point distance.
- When the opposite extremum appears, the prior cycle finalizes once.
- A run ending with an open cycle marks it censored rather than confirmed.

**Rollback point**: Sprint 1 commit. Reverting Sprint 2 removes additive cycle
state while retaining the one-engine behavior.

### Task 2.1: Define Copy-Safe Engine Cycle State

- **Location**: new `services/trading_signals/extremum_engine_state.mqh`,
  `services/trading_signals.mqh`.
- **Description**: Add focused structs for active cycle, revision snapshot, and
  attempt linkage with explicit default/copy constructors and bounded arrays or
  scalar runtime state. Avoid per-tick allocation; update only on new M1 bars or
  attempt transitions.
- **Dependencies**: Sprint 1.
- **Acceptance criteria**:
  - State distinguishes cycle, revision, and attempt identities.
  - State resets deterministically in OnInit/OnDeinit and tester reruns.
  - No sibling include cycle is introduced.
  - Arrays use reserves/bounds consistent with repository style.
- **Validation**:
  - Static constructor/include review.
  - MetaEditor compile at sprint end.
- **Rollback**: Remove the additive include/state through Sprint 2 reversion.

### Task 2.2: Freeze And Validate Fibonacci Reference Anchors

- **Location**: `services/trading_signals/extremum_engine_state.mqh`,
  `services/trading_signals/market_signal_indicators.mqh`, existing Fibonacci
  helpers under `services/indicators/`.
- **Description**: On cycle creation, capture slot `1` and slot `2` time/price
  anchors, validate alternating types and positive price range, calculate
  `reference_range_points`, and keep the anchors immutable until finalization.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Later revisions cannot rewrite cycle anchors.
  - Invalid or degenerate reference ranges produce an explicit invalid-depth
    state without crashing or inventing a percentage.
  - Raw depth is not clamped at cycle boundaries.
- **Validation**:
  - Manual calculations for one BOTTOM and one PEAK sample agree with logged
    depth within symbol precision.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 2.

### Task 2.3: Detect Cycle Transitions And Revisions

- **Location**: `services/trading_signals/market_signal_detection.mqh`,
  `services/trading_signals/extremum_engine_state.mqh`.
- **Description**: Treat same-type slot `0` time/price movement as a new revision
  of the same cycle. Treat a type transition as prior-cycle finalization plus a
  new cycle. Generate deterministic IDs from run/symbol/timeframe/type/first
  observation and revision identity, not from mutable final-cycle facts.
- **Dependencies**: Tasks 2.1 and 2.2.
- **Acceptance criteria**:
  - A deeper same-type extremum does not create a new cycle ID.
  - A repeated identical snapshot does not create a duplicate revision.
  - An opposite type transition finalizes exactly one prior cycle.
  - IDs are stable within one deterministic tester replay.
- **Validation**:
  - Changed-log review over a multi-revision tester sample.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 2.

### Task 2.4: Link Intrinsic Attempts To Revisions

- **Location**: `services/trading_signals/signal_params_struct.mqh`,
  `services/trading_signals/market_signal_state.mqh`,
  `services/trading_signals/market_signal_detection.mqh`.
- **Description**: Add engine/cycle/revision/attempt fields to signal state.
  Increment `cycle_attempt_index` across the cycle and
  `revision_attempt_index` within a revision. Preserve exact-revision dedupe and
  TP consumption while allowing a later deeper revision to become a new source.
- **Dependencies**: Task 2.3.
- **Acceptance criteria**:
  - Attempt 1 at about 39 percent and attempt 2 at about 63 percent share the
    same cycle ID but have different revision/attempt IDs.
  - Multiple attempts on one unchanged revision remain distinguishable.
  - Active broker exposure is not expired or rewritten by a later revision.
  - No-exposure pending execution still expires on source revision change.
- **Validation**:
  - Tester log review across pending expiration, real entry, close, and deeper
    revision.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 2.

### Task 2.5: Calculate Human Raw Distance Facts

- **Location**: `services/trading_signals/extremum_engine_state.mqh`,
  `services/trading_signals/execution_logging.mqh`.
- **Description**: Calculate and expose raw depth percent, distance from first
  revision in points, distance from previous revision in points, depth delta,
  and bars since cycle start. Do not calculate profitability buckets or nearest
  Fibonacci labels in MQL5.
- **Dependencies**: Tasks 2.2 through 2.4.
- **Acceptance criteria**:
  - Point conversion uses the symbol point size and valid prices.
  - PEAK and BOTTOM orientations both increase in the intuitive deeper
    direction.
  - Logs are changed/throttled, not emitted unbounded per tick.
- **Validation**:
  - Manual numeric spot check.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 2.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] One real MetaEditor compile reports 0 errors and 0 warnings.
- [ ] A human tester sample demonstrates stable cycle identity across at least
  two revisions and correct finalization on the opposite extremum.
- [ ] Fibonacci anchors remain frozen and raw depths match manual calculations.
- [ ] Active broker facts remain untouched by provisional revisions.
- [ ] Exactly one Sprint 2 commit is created with the proposed message.
- [ ] The Sprint 1 commit is recorded as the rollback point.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Export Schema V7 Intrinsic Engine Census

**Goal**: Produce a strict, append-only schema v7 run containing cycles,
revisions, intrinsic attempts, broker admission, and broker outcomes with
unambiguous simulated-versus-broker provenance.

**Dependencies**: Sprint 2 gate complete.

**Tracked scope**:
`services/trading_signals/deterministic_signal_statistics_export.mqh`,
`services/trading_signals/extremum_engine_state.mqh`,
`services/trading_signals/market_signal_detection.mqh`,
`services/trading_signals/execution_controller.mqh`,
`services/trading_signals/execution_lifecycle.mqh`,
`services/trading_signals/execution_broker_reconciliation.mqh`,
`services/trading_signals/tick_signals_manager.mqh`, `HFT_Grid_AI.mq5`.

**Commit**: `feat: export extremum engine census schema v7`

**Demo/Validation**:

- `python3 tools/mt5/compile_mt5.py` using documented arguments.
- Run a short Strategy Tester export with
  `ML_Inference_Mode=ML_INFERENCE_DISABLED` and a unique run ID.
- Summarize file presence, sizes, row counts, schema version, final status, and
  selected cycle/revision/attempt rows without pasting full TSV content.
- Confirm blocked/canceled intrinsic attempts remain present without invented
  broker outcomes.
- Confirm a broker-entered attempt links to the existing admissions, feature,
  signal outcome, and leg outcome files.

**Rollback point**: Sprint 2 commit plus the immutable schema v6 baseline run.
Reverting Sprint 3 restores the schema v6 exporter; schema v7 run folders remain
historical artifacts and must not be reinterpreted as v6.

### Task 3.1: Define Schema V7 Headers, Manifest, And Summary Counts

- **Location**:
  `services/trading_signals/deterministic_signal_statistics_export.mqh`.
- **Description**: Bump the active schema to v7, add file/header constants and
  buffers for `engine_cycles.tsv`, `engine_revisions.tsv`, and
  `engine_attempts.tsv`, add their counts to manifest/summary, and replace
  strategy configuration keys with engine contract keys.
- **Dependencies**: Sprint 2.
- **Acceptance criteria**:
  - Every schema v7 file has a deterministic header and row count.
  - Manifest includes engine ID/label/timeframe, cycle rules, Fibonacci anchor
    policy, path horizon, and outcome-source policy.
  - Old strategy enable keys are absent from v7 manifests.
  - Existing flush/failure behavior covers the new buffers.
- **Validation**:
  - Header/static review.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 3.

### Task 3.2: Write Revision Rows At Observation Time

- **Location**:
  `services/trading_signals/deterministic_signal_statistics_export.mqh`,
  `services/trading_signals/market_signal_detection.mqh`.
- **Description**: Write one revision row only when a new revision is observed.
  Include frozen anchors, raw depth/distance facts, point-in-time structural
  context, session/time context, and optional passive M1 context that does not
  gate trading.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Duplicate unchanged snapshots do not produce duplicate rows.
  - Final cycle depth is not backfilled into earlier revision feature columns.
  - Every row references a valid cycle ID and increasing revision index.
- **Validation**:
  - Short tester row/key inspection.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 3.

### Task 3.3: Capture Intrinsic Attempts Before Operational Gates

- **Location**: `services/trading_signals/market_signal_detection.mqh`,
  `services/trading_signals/market_signal_state.mqh`,
  `services/trading_signals/deterministic_signal_statistics_export.mqh`.
- **Description**: Create the intrinsic attempt record after structural/geometry
  validation but before `CanAttemptSignal()` and broker admission. Record later
  operational denial reasons without treating denial as broker outcome.
- **Dependencies**: Tasks 3.1 and 3.2.
- **Acceptance criteria**:
  - Direction/session/daily/concurrency/protection/Algo Trading denials do not
    erase the intrinsic attempt.
  - Denied attempts do not enter running execution arrays unless existing
    execution policy permits them.
  - Daily and concurrency counters are not incremented by census-only rows.
  - Broker send remains impossible after an operational denial.
- **Validation**:
  - Tester scenarios for at least session and concurrency/daily denial.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 3.

### Task 3.4: Track Bounded Simulated Attempt Paths

- **Location**:
  `services/trading_signals/deterministic_signal_statistics_export.mqh`,
  `services/trading_signals/tick_signals_manager.mqh`, reuse existing bounded
  path helpers where behavior matches.
- **Description**: Track whether each intrinsic attempt reaches its breakout,
  then observe simulated TP/SL/MAE/MFE through a bounded horizon or cycle/run
  finalization. Label rows `ENGINE_SIMULATION`; never update broker-confirmed
  profit, tickets, volumes, or close flags.
- **Dependencies**: Task 3.3.
- **Acceptance criteria**:
  - Never-triggered attempts finish as `NOT_TRIGGERED`, `REVISION_EXPIRED`, or
    censored, not wins/losses.
  - Triggered simulated paths use the attempt's frozen trigger/stop/target
    geometry and broker-side bid/ask convention where available.
  - Simulated rows cannot satisfy `SignalHasBrokerConfirmedOutcome()`.
  - Tracking cost is bounded by active attempts and a fixed horizon.
- **Validation**:
  - Tester scenarios for no trigger, simulated SL, simulated target, broker
    denial after trigger, and run-ended censoring.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 3.

### Task 3.5: Finalize Cycle And Attempt Rows Exactly Once

- **Location**:
  `services/trading_signals/deterministic_signal_statistics_export.mqh`,
  `services/trading_signals/extremum_engine_state.mqh`, `HFT_Grid_AI.mq5`.
- **Description**: Write one cycle summary on opposite-type finalization and one
  censored summary for the open cycle on deinit/run end. Finalize all attempts
  exactly once and flush new buffers before run summary.
- **Dependencies**: Tasks 3.1 through 3.4.
- **Acceptance criteria**:
  - Cycle count equals unique cycle IDs.
  - Revision and attempt counts agree with cycle summaries.
  - Deinit is idempotent for already-finalized rows.
  - Run summary status fails if any required write/flush fails.
- **Validation**:
  - Short tester run plus deinit artifact consistency review.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 3.

### Task 3.6: Enrich Broker Files With Engine Genealogy

- **Location**:
  `services/trading_signals/deterministic_signal_statistics_export.mqh`,
  `services/trading_signals/execution_controller.mqh`,
  `services/trading_signals/execution_broker_reconciliation.mqh`.
- **Description**: Add engine/cycle/revision/attempt identifiers to schema v7
  admissions, features, signal outcomes, and leg outcomes. Preserve strict
  broker evidence gates and existing partial TP facts.
- **Dependencies**: Tasks 3.1 through 3.5.
- **Acceptance criteria**:
  - A broker outcome joins to exactly one intrinsic attempt.
  - No broker outcome exists for a no-exposure attempt.
  - Existing broker `net_profit`, expected SL loss, and partial TP facts remain
    the broker target source of truth.
- **Validation**:
  - Join/key inspection on the tester run.
  - MetaEditor compile at sprint end.
- **Rollback**: Revert Sprint 3.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] One real MetaEditor compile reports 0 errors and 0 warnings.
- [ ] One schema v7 Strategy Tester run exports all required files with `OK`
  status and consistent counts.
- [ ] Simulated and broker outcomes are demonstrably separate.
- [ ] Intrinsic attempts survive operational denials without bypassing them.
- [ ] Hot-path work remains bounded and logging remains throttled.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] The Sprint 2 commit and schema v6 run are recorded as rollback/reference
  points.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Validate And Assemble Schema V7 With Python And DuckDB

**Goal**: Strictly validate schema v7 artifacts and build normalized Parquet
tables without breaking historical v4/v5/v6 workflows.

**Dependencies**: Sprint 3 gate and one compact schema v7 run artifact.

**Tracked scope**: `tools/deterministic_signal_ml/schema_contract.py`,
`tools/deterministic_signal_ml/validate_phase1_run.py`,
`tools/deterministic_signal_ml/build_dataset.py`,
`tools/deterministic_signal_ml/report_writer.py`,
`tools/deterministic_signal_ml/tests/test_extremum_engine_schema.py`,
`tools/deterministic_signal_ml/tests/fixtures/schema_v7_extremum_engine/`.

**Commit**: `feat: validate and assemble extremum engine schema v7`

**Demo/Validation**:

- `.venv/bin/python -m compileall tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root <runs_root> --run-id <schema_v7_run_id> --dataset-id <schema_v7_dataset_id> --schema-version 7 --feature-set-id schema_v7_extremum_engine --target-family broker_1r --validate-only`
- Repeat validation against one known schema v6 run to prove backward
  compatibility.
- Build schema v7 Parquet outputs and verify readback counts.

**Rollback point**: Sprint 3 commit. Reverting Sprint 4 restores v6-only Python
support without changing already-exported v7 raw artifacts.

### Task 4.1: Add Schema V7 Contracts And Backward Compatibility

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`.
- **Description**: Define v7 headers/files/identity columns, add v7 to supported
  versions, replace active strategy fields with engine genealogy, and retain
  exact v4/v5/v6 variants for historical readers.
- **Dependencies**: Sprint 3 artifact contract.
- **Acceptance criteria**:
  - Schema v7 is the active default.
  - Historical schemas still resolve their original columns.
  - Mixed-schema dataset assembly is rejected.
  - New target/feature IDs map to schema 7 only.
- **Validation**:
  - Unit tests for expected columns and version/feature-set mapping.
- **Rollback**: Revert Sprint 4.

### Task 4.2: Validate Cycle, Revision, Attempt, And Broker Invariants

- **Location**: `tools/deterministic_signal_ml/validate_phase1_run.py`.
- **Description**: Validate file presence, schema/count consistency, unique IDs,
  monotonic revision/attempt indexes, valid parent joins, frozen anchor equality,
  positive reference range, raw depth parseability, exactly-once cycle rows,
  allowed censoring, simulated provenance, and broker-outcome evidence.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Orphan revisions/attempts and duplicate IDs fail validation.
  - Changed anchors inside one cycle fail validation.
  - Simulated rows with broker-confirmed fields fail validation.
  - Broker outcomes without a matching broker-entered attempt fail validation.
  - Open/censored cycles produce warnings or accepted statuses, not invented
    final extrema.
- **Validation**:
  - Positive and intentionally broken compact fixtures.
- **Rollback**: Revert Sprint 4.

### Task 4.3: Build Normalized Engine Parquet Tables

- **Location**: `tools/deterministic_signal_ml/build_dataset.py`.
- **Description**: Load new TSVs with explicit DuckDB column types and write
  `engine_cycles.parquet`, `engine_revisions.parquet`,
  `engine_attempts.parquet`, existing broker tables, and a joined research
  matrix. Preserve raw tables so audits can choose simulated or broker targets.
- **Dependencies**: Tasks 4.1 and 4.2.
- **Acceptance criteria**:
  - Readback counts match validated TSV counts.
  - Raw depth remains numeric and unclamped.
  - Point-in-time revision fields do not include final-cycle labels as features.
  - Broker and simulated target columns remain distinct.
- **Validation**:
  - Fixture build/readback test.
  - Real schema v7 short-run build.
- **Rollback**: Revert Sprint 4 and delete only ignored generated dataset
  artifacts created for validation.

### Task 4.4: Report Dataset Quality By Genealogy

- **Location**: `tools/deterministic_signal_ml/report_writer.py`.
- **Description**: Add cycle/revision/attempt counts, distinct-cycle support,
  censored counts, orphan/duplicate status, simulated/broker coverage, depth
  range, and join coverage to JSON/Markdown quality outputs.
- **Dependencies**: Task 4.3.
- **Acceptance criteria**:
  - Reports show attempts and distinct cycles separately.
  - A dataset with zero trainable broker rows fails broker training assembly but
    can still validate the raw engine census.
  - No report labels simulated profit as realized broker profit.
- **Validation**:
  - Unit test expected report fields.
  - Inspect compact generated report.
- **Rollback**: Revert Sprint 4.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Python compileall and all new unit tests pass.
- [ ] One real schema v7 run validates and builds with consistent readback.
- [ ] One schema v6 run still validates with its historical contract.
- [ ] Broken fixtures fail for the intended invariant.
- [ ] Exactly one Sprint 4 commit is created with the proposed message.
- [ ] The Sprint 3 commit is recorded as rollback point.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Add Human-Readable DuckDB Depth And Profitability Audit

**Goal**: Produce compact reports that answer which Fibonacci depths, attempt
indexes, and range sizes are most profitable without hiding sample size or cycle
dependence.

**Dependencies**: Sprint 4 gate and a built schema v7 dataset.

**Tracked scope**:
`tools/deterministic_signal_ml/extremum_engine_audit.py`,
`tools/deterministic_signal_ml/segment_metrics.py`,
`tools/deterministic_signal_ml/pattern_audit.py`,
`tools/deterministic_signal_ml/tests/test_extremum_engine_audit.py`,
`tools/deterministic_signal_ml/README.md`.

**Commit**: `feat: add extremum depth profitability audit`

**Demo/Validation**:

- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- `.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py --dataset-id <schema_v7_dataset_id> --audit-id <schema_v7_audit_id> --overwrite`
- Inspect generated Markdown/TSV/JSON for:
  - attempt 1 versus attempt 2 depth performance;
  - raw 39 percent near 38.2 and raw 63 percent near 61.8;
  - point-range buckets;
  - attempt-level and cycle-total R;
  - attempt count and distinct-cycle count;
  - simulated and broker lanes kept separate.

**Rollback point**: Sprint 4 commit. Audit outputs are ignored generated
artifacts and may be deleted independently.

### Task 5.1: Derive Human Fibonacci Proximity In DuckDB

- **Location**: new
  `tools/deterministic_signal_ml/extremum_engine_audit.py`.
- **Description**: Derive nearest configurable Fibonacci level and absolute
  percentage delta from `depth_percent_raw`. Start with a documented analytics
  list such as `0, 23.6, 38.2, 50, 61.8, 78.6, 100, 123.6, 138.2, 161.8,
  178.6, 200` and allow repeated cycles/extensions without changing MQL5 data.
- **Dependencies**: Sprint 4 tables.
- **Acceptance criteria**:
  - Raw 39 percent maps near 38.2 with its delta retained.
  - Raw 63 percent maps near 61.8 with its delta retained.
  - Values above 100 are not clamped or discarded.
  - Analytics level choices are recorded in audit metadata.
- **Validation**:
  - Unit tests for positive, negative, boundary, and extension depths.
- **Rollback**: Revert Sprint 5.

### Task 5.2: Report Attempt-Level Profitability

- **Location**: `tools/deterministic_signal_ml/extremum_engine_audit.py`,
  `tools/deterministic_signal_ml/segment_metrics.py`.
- **Description**: Group by timeframe, direction/type, cycle attempt index,
  nearest Fibonacci, configurable range bucket, and outcome source. Report
  support, distinct cycles, trigger rate, broker entry rate, win rate, average
  and median R, total R, profit factor where defined, MAE/MFE, and censored rows.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - Reports never combine simulated and broker R by default.
  - Support shows both rows and distinct cycles.
  - Sparse groups are marked rather than promoted as strong findings.
- **Validation**:
  - Fixture expectations and manual report review.
- **Rollback**: Revert Sprint 5.

### Task 5.3: Report Cycle Sequence Profitability

- **Location**: `tools/deterministic_signal_ml/extremum_engine_audit.py`.
- **Description**: Aggregate ordered attempts within each cycle to show first
  attempt result, later recovery, cumulative cycle R, total broker R, total
  simulated R, revision count, and final/censored status. Support questions such
  as `attempt 1 near 38.2 failed; attempt 2 near 61.8 recovered`.
- **Dependencies**: Task 5.2.
- **Acceptance criteria**:
  - An attempt 2 win does not hide the attempt 1 loss.
  - Cycle totals use one outcome source at a time.
  - Censored/open cycles remain explicit.
- **Validation**:
  - Unit fixture with losing attempt 1 and winning attempt 2.
- **Rollback**: Revert Sprint 5.

### Task 5.4: Add Range-Size And Stability Views

- **Location**: `tools/deterministic_signal_ml/extremum_engine_audit.py`,
  `tools/deterministic_signal_ml/pattern_audit.py` where reusable.
- **Description**: Add raw point range, configurable point buckets, and monthly
  or quarterly stability views. Do not call point range `volume`; reserve volume
  terminology for future tick/real-volume fields.
- **Dependencies**: Tasks 5.2 and 5.3.
- **Acceptance criteria**:
  - Same Fibonacci depth can be compared across small and large price ranges.
  - Reports retain raw range statistics alongside buckets.
  - Stability views are chronological and show support per period.
- **Validation**:
  - Fixture and real-dataset report review.
- **Rollback**: Revert Sprint 5.

### Task 5.5: Produce Compact Human Audit Artifacts

- **Location**: `tools/deterministic_signal_ml/extremum_engine_audit.py`,
  `tools/deterministic_signal_ml/README.md`.
- **Description**: Write deterministic TSV/JSON/Markdown outputs and document a
  single command. Keep reports compact, sorted by support/expectancy, and free of
  full raw dataset dumps.
- **Dependencies**: Tasks 5.1 through 5.4.
- **Acceptance criteria**:
  - Output includes an executive table understandable without reading SQL.
  - Metadata records dataset, schema, target lane, Fibonacci levels, and range
    bucket policy.
  - Generated artifacts remain ignored by git.
- **Validation**:
  - Run the documented command and inspect artifact names/counts.
- **Rollback**: Revert Sprint 5; remove ignored audit output if desired.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] All Python tests pass.
- [ ] Audit output answers attempt depth, range, cycle sequence, and support
  questions in separate simulated and broker lanes.
- [ ] Reports use distinct cycles as a support measure.
- [ ] Exactly one Sprint 5 commit is created with the proposed message.
- [ ] The Sprint 4 commit is recorded as rollback point.
- [ ] Sprint 6 has not started before this gate completes.

## Sprint 6: Prepare XGBoost Research Without Cycle Leakage

**Goal**: Make schema v7 trainable for research while preventing revision/cycle
leakage and preventing old S1/S2/S3 artifacts from running against the engine.

**Dependencies**: Sprint 5 gate and a schema v7 dataset with sufficient rows.

**Tracked scope**: `tools/deterministic_signal_ml/schema_contract.py`,
`tools/deterministic_signal_ml/validation_splits.py`,
`tools/deterministic_signal_ml/feature_encoder.py`,
`tools/deterministic_signal_ml/model_config.py`,
`tools/deterministic_signal_ml/train_model.py`,
`tools/deterministic_signal_ml/report_writer.py`,
`tools/deterministic_signal_ml/model_artifact_contract.py`,
`tools/deterministic_signal_ml/export_model_artifact.py`,
`tools/deterministic_signal_ml/model_artifact_validator.py`,
`services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`,
`services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`,
`tools/deterministic_signal_ml/tests/`.

**Commit**: `feat: add leak-safe extremum engine research contract`

**Demo/Validation**:

- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- `.venv/bin/python tools/deterministic_signal_ml/train_model.py --dataset-id <schema_v7_dataset_id> --model-id <schema_v7_model_id> --feature-set-id schema_v7_extremum_engine_xgb --overwrite`
- Inspect split metadata and prove no `extremum_cycle_id` appears in more than
  one train/test/holdout partition.
- Run artifact validation against an old v6 export and a deliberately labeled
  v7 research artifact; old export must be incompatible with the engine.
- If MQL5 compatibility code changes, run one real MetaEditor compile at sprint
  end with 0 errors and 0 warnings.

**Rollback point**: Sprint 5 commit. Reverting Sprint 6 keeps schema v7 raw data
and DuckDB audit usable while disabling v7 model training/runtime compatibility.

### Task 6.1: Define Point-In-Time V7 Feature Sets And Targets

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`,
  `tools/deterministic_signal_ml/model_config.py`.
- **Description**: Define a compact engine feature set containing only facts
  known at attempt time, such as direction, attempt/revision index, raw depth,
  reference range points, revision distances, bars since cycle start,
  structural categories, session, and cyclical time. Exclude final depth,
  finalization time, cycle total result, and later revision facts.
- **Dependencies**: Sprint 5.
- **Acceptance criteria**:
  - Feature contract explicitly separates point-in-time features from labels.
  - `engine_simulated_1r` and `broker_1r` targets are distinct.
  - No strategy label or strategy-aligned delay/macro feature is required.
- **Validation**:
  - Unit tests for feature/label exclusion.
- **Rollback**: Revert Sprint 6.

### Task 6.2: Make Chronological Splits Cycle-Group Safe

- **Location**: `tools/deterministic_signal_ml/validation_splits.py`,
  `tools/deterministic_signal_ml/train_model.py`.
- **Description**: Keep chronological holdout/walk-forward behavior but assign
  all rows from one `symbol + engine_timeframe + extremum_cycle_id` group to one
  partition. Apply gaps at group boundaries and report group counts.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - No cycle group crosses train, fold test, or final holdout.
  - Splits remain chronological by first cycle observation.
  - Insufficient group counts fail with an actionable error.
- **Validation**:
  - Unit tests with multiple revisions/attempts per cycle near split boundaries.
- **Rollback**: Revert Sprint 6.

### Task 6.3: Update Training And Prediction Outputs To Engine Identity

- **Location**: `tools/deterministic_signal_ml/feature_encoder.py`,
  `tools/deterministic_signal_ml/train_model.py`,
  `tools/deterministic_signal_ml/report_writer.py`.
- **Description**: Replace active strategy columns in v7 prediction/report
  output with engine/cycle/revision/attempt identity and include split group
  metadata. Preserve historical readers for older model folders.
- **Dependencies**: Tasks 6.1 and 6.2.
- **Acceptance criteria**:
  - Training accepts v7 engine matrices and rejects schema mismatch.
  - Reports state target source and distinct cycle support.
  - Legacy schema training still uses its original feature set when explicitly
    requested.
- **Validation**:
  - Short fixture training plus one real research training command when support
    is sufficient.
- **Rollback**: Revert Sprint 6.

### Task 6.4: Harden Artifact Compatibility And Runtime Fail-Closed Behavior

- **Location**: `tools/deterministic_signal_ml/model_artifact_contract.py`,
  `tools/deterministic_signal_ml/export_model_artifact.py`,
  `tools/deterministic_signal_ml/model_artifact_validator.py`,
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`,
  `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`.
- **Description**: Add engine ID/timeframe/schema/feature-set metadata and reject
  old S1/S2/S3 artifacts. Do not approve a v7 runtime model; readiness only means
  compatibility checks and research training can run.
- **Dependencies**: Tasks 6.1 through 6.3.
- **Acceptance criteria**:
  - Old artifacts cannot score or filter `EXTREMUM_V1`.
  - SHADOW reports unavailable without affecting execution.
  - FILTER remains Strategy Tester only and fails closed on incompatible
    artifacts according to the existing filter safety contract.
  - Pattern playback selections include schema/engine identity.
- **Validation**:
  - Python artifact validator cases.
  - MetaEditor compile if MQL5 code changes.
  - Short tester startup with incompatible artifact.
- **Rollback**: Revert Sprint 6.

### Sprint 6 Gate

- [ ] All Sprint 6 tasks complete.
- [ ] All Python tests pass.
- [ ] Cycle groups do not cross chronological partitions.
- [ ] A schema v7 research training run completes or an insufficient-support
  blocker is explicitly recorded without weakening validation.
- [ ] Old S1/S2/S3 artifacts fail closed.
- [ ] Any changed MQL5 files compile with 0 errors and 0 warnings.
- [ ] Exactly one Sprint 6 commit is created with the proposed message.
- [ ] The Sprint 5 commit is recorded as rollback point.
- [ ] Sprint 7 has not started before this gate completes.

## Sprint 7: End-To-End Evidence, Performance, And Active Documentation

**Goal**: Close the change with a reproducible Strategy Tester/export/DuckDB
workflow, current documentation, and explicit residual risk/rollback evidence.

**Dependencies**: Sprints 1 through 6 complete.

**Tracked scope**: `README.md`, `AGENTS.md`,
`docs/architecture/execution-foundation.md`,
`docs/environment/mt5-agentic-workflows.md`,
`docs/workflows/deterministic-signal-ml-inference-flows.md`,
`docs/workflows/extremum-engine-statistics-flow.md`,
`tools/deterministic_signal_ml/README.md`, plus narrow fixes required by final
validation.

**Commit**: `docs: close extremum engine statistics workflow`

**Demo/Validation**:

- Final real MetaEditor compile with 0 errors and 0 warnings if any MQL5 fix is
  included; otherwise reference the most recent valid compile and do not run a
  redundant docs-only compile.
- Human-in-the-loop Strategy Tester matrix:
  - one PEAK and one BOTTOM cycle;
  - a same-cycle deeper revision;
  - attempt 1 and attempt 2 with different raw Fibonacci depths;
  - no-trigger expiration;
  - high-spread or session admission block;
  - one broker entry and broker-confirmed close;
  - one open cycle censored at run end;
  - ML disabled and old artifact incompatibility.
- Build the v7 dataset, run the extremum engine audit, and optionally run
  research training using documented commands.
- Compare baseline and v7 tester elapsed time, cycle/revision/attempt row counts,
  max active simulated path states, output sizes, and final status. Do not paste
  full logs/TSVs.

**Rollback point**: Sprint 6 commit for documentation-only rollback; Sprint 2 or
Sprint 1 commits remain the behavior rollback points. Schema v7 artifacts are
immutable evidence and are not converted backward.

### Task 7.1: Write The Active Extremum Engine Workflow

- **Location**: new `docs/workflows/extremum-engine-statistics-flow.md`,
  `README.md`, `tools/deterministic_signal_ml/README.md`.
- **Description**: Document engine semantics, cycle/revision/attempt genealogy,
  frozen Fibonacci anchors, simulated/broker outcome separation, schema v7
  files, validation/build/audit commands, and XGBoost leakage rules.
- **Dependencies**: Sprints 1 through 6.
- **Acceptance criteria**:
  - A human can run export -> validation -> dataset -> audit from one compact
    workflow.
  - Documentation clearly states that final cycle depth is a label, not a
    point-in-time feature.
  - No active instructions recommend S1/S2/S3 run IDs.
- **Validation**:
  - Execute documented commands against the final evidence run.
- **Rollback**: Revert Sprint 7.

### Task 7.2: Align Architecture And Project Instructions

- **Location**: `AGENTS.md`, `docs/architecture/execution-foundation.md`,
  `docs/workflows/deterministic-signal-ml-inference-flows.md`,
  `docs/environment/mt5-agentic-workflows.md`.
- **Description**: Replace active references to three deterministic strategies,
  shifted M1/macro visual validation, and strategy-scoped ML runs with the one
  engine/schema v7 contract. Keep historical references only inside archives.
- **Dependencies**: Task 7.1.
- **Acceptance criteria**:
  - Project instructions match implemented behavior.
  - Historical plans/evidence remain archived and unchanged.
  - Validation policy still forbids custom MQL5 tests and requires MetaEditor
    plus human Strategy Tester verification.
- **Validation**:
  - Static search outside archive directories for stale active vocabulary.
- **Rollback**: Revert Sprint 7.

### Task 7.3: Run And Record The Final Verification Matrix

- **Location**: generated artifacts outside git plus a concise acceptance note
  under `docs/research/` only if implementation execution explicitly authorizes
  that evidence file.
- **Description**: Execute the final tester matrix and Python workflow. Record
  run IDs, paths, sizes, counts, final status, first useful failure lines if any,
  and PASS/FAIL by scenario.
- **Dependencies**: Tasks 7.1 and 7.2.
- **Acceptance criteria**:
  - Required scenarios have evidence.
  - Broker outcomes require broker evidence.
  - Simulated outcomes are clearly labeled.
  - Dataset and audit commands reproduce the reported counts.
- **Validation**:
  - Commands in the Demo/Validation section.
- **Rollback**: Generated artifacts can be removed; product rollback follows
  sprint commits.

### Task 7.4: Measure Bounded Performance And Storage Growth

- **Location**: Strategy Tester summaries and schema v7 run summary.
- **Description**: Compare baseline with export disabled, v7 export enabled, and
  optional research ML disabled. Measure elapsed time, output size, row counts,
  and peak active path states. Confirm no per-tick full-history scan, handle
  creation, unbounded array growth, or log spam was introduced.
- **Dependencies**: Task 7.3.
- **Acceptance criteria**:
  - Cycle/revision work runs on new M1 bars.
  - Path work is bounded by active attempts and horizon.
  - Regression is quantified; unacceptable degradation blocks completion.
- **Validation**:
  - Compact tester performance comparison.
- **Rollback**: Revert the sprint that introduced the regression and rerun its
  gate before continuing.

### Task 7.5: Final Review Gate And Archive Readiness

- **Location**: this plan, active plan state, `docs/plans/README.md` only when the
  full plan is actually complete and ready to archive.
- **Description**: Perform the MQL5 PASS/FAIL review gate, Python/data review,
  residual-risk review, and rollback rehearsal. Do not archive the plan until
  all sprint commits and evidence exist.
- **Dependencies**: Tasks 7.1 through 7.4.
- **Acceptance criteria**:
  - Include layering, hot path, array/buffer handling, handle cleanup, and
    trading safety pass review.
  - Schema joins, leakage prevention, simulated/broker provenance, and human
    audit support pass review.
  - Rollback points for every sprint are recorded.
- **Validation**:
  - Final diff and commit review.
  - Active-plan state marks completion only after all gates pass.
- **Rollback**: Follow the sprint rollback sequence below.

### Sprint 7 Gate

- [ ] All Sprint 7 tasks complete.
- [ ] Final verification matrix passes or residual failures are explicitly
  accepted by the human owner.
- [ ] Performance/storage impact is measured and acceptable.
- [ ] Active docs contain no stale S1/S2/S3 operational guidance.
- [ ] Exactly one Sprint 7 commit is created with the proposed message.
- [ ] The Sprint 6 commit and all earlier rollback points are recorded.
- [ ] The plan is archived only after active-plan completion is recorded.

## Testing Strategy

### MQL5 Compile

- Use one real MetaEditor compile at the end of each MQL5 sprint, not after every
  atomic task.
- Preferred command is `python3 tools/mt5/compile_mt5.py` with the exact Wine or
  Windows arguments from `docs/environment/mt5-agentic-workflows.md`.
- Treat any warning or error as sprint failure.
- Do not use `/s` syntax check as evidence that `.ex5` was regenerated.

### MQL5 Integration And End-To-End

- Human-in-the-loop Strategy Tester using real ticks or equivalent faithful tick
  modeling.
- Validate PEAK/BOTTOM orientation, breakout timing, revision replacement,
  active exposure ownership, TP/SL, partial TP, session/spread/margin denial,
  broker reconciliation, and run-end censoring.
- Validate export on/off behavior and old model/pattern incompatibility.
- Do not add custom MQL5 test sources, harnesses, or CI.

### Python Unit And Contract

- Use stdlib `unittest`; no new dependency is required.
- Test schema columns, ID uniqueness, parent joins, frozen anchors, depth math,
  nearest Fibonacci derivation, simulated/broker provenance, and cycle-group
  split isolation.
- Run `compileall` and all deterministic ML tests after Python changes.

### DuckDB Integration

- Read compact TSV fixtures using the same explicit column maps as real runs.
- Write/read Parquet and compare counts.
- Validate attempt-level and cycle-level audit outputs against known fixture
  expectations.
- Verify schema v6 backward compatibility separately from v7.

### XGBoost Research

- Training validation is research-only and does not approve runtime promotion.
- Use chronological cycle-group splits and report distinct cycle support.
- Compare baseline and XGBoost metrics only after leakage checks pass.
- Reject any model/export whose schema, engine identity, timeframe, feature set,
  or target source does not match.

### Security And Trading Safety

- Confirm no license or entitlement fields enter exported public research rows.
- Do not export account identifiers, license keys, broker credentials, or magic
  details beyond existing safe config hashes/identifiers.
- Confirm census capture cannot bypass execution gates or create broker orders.
- Confirm simulated outcomes cannot affect entries, exits, lots, SL/TP, daily
  accounting, protection, or broker reconciliation.

### Performance And Reliability

- Cycle/revision calculations occur once per new M1 bar.
- Indicator handles are created in initialization and released in deinit.
- File buffers flush in bounded batches.
- Active simulated paths use bounded arrays/reserves and a fixed horizon.
- Logs remain gated and changed/throttled.

### Accessibility

- Not applicable; no user-facing web UI is added.
- Frontend status wording must remain readable and must not imply old strategy or
  MA confirmation behavior.

## Risks And Mitigations

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Removing MA gates greatly increases candidates/trades | Higher exposure frequency and different live behavior | Preserve every operational/broker guard; validate in tester before live use; retain rollback commit | Candidate, admission, broker send, and position counts compared to baseline |
| Provisional slot `0` revisions become duplicate cycles | Inflated support and leakage | Stable parent cycle ID; revision ID for mutable time/price; strict validator | Unique cycle counts and monotonic revision indexes |
| Fibonacci anchors drift across revisions | Attempt depths are not comparable | Freeze slot `1`/`2` anchors at cycle start; validate equality | Validator rejects anchor changes |
| Final depth leaks into model features | Unrealistic model metrics | Separate revision snapshot features from cycle final labels | Feature exclusion tests and group split audit |
| Repeated attempts from a few cycles inflate significance | False human/model confidence | Always report distinct cycles; group train/validation by cycle | Audit support columns and zero group overlap |
| Simulated outcomes are mistaken for broker outcomes | False profitability claims | Separate files/columns/source labels and broker predicates | Validator rejects provenance violations |
| Old S1/S2/S3 models silently score new engine rows | Unsafe filtering | Schema/engine/timeframe/feature-set compatibility checks | Old artifact reports unavailable/mismatch |
| Passive MA context accidentally remains a gate | Hidden preselection persists | Static call-graph review and tester scenario where MA disagrees | Candidate still appears and reaches admission |
| Intrinsic census increments operational limits | Research changes trading behavior | Record census before gates without registering daily/concurrency execution | Denied census rows do not alter counters |
| Simulated path tracking slows tester | Long-run regression and memory growth | Bounded active states, fixed horizon, batched writes, new-bar cycle updates | Performance comparison and peak state count |
| Cycle finalization is lost at deinit | Missing/corrupt cycle counts | Idempotent deinit censor/finalize and flush before summary | Counts reconcile after short run termination |
| Point range is misinterpreted as volume | Incorrect research conclusions | Use `range_points` terminology; volume remains out of scope | Docs/audit labels contain no false volume claim |
| Historical schema support is broken | Existing evidence/tooling unusable | Preserve exact v4/v5/v6 column variants and regression validation | Known v6 run still validates/builds |

## Rollback Plan

1. **Sprint 7 rollback**: Revert documentation/closeout commit; keep validated
   product/data commits intact.
2. **Sprint 6 rollback**: Revert v7 model/leakage contract. Schema v7 raw data
   and DuckDB audits remain usable, but v7 training/runtime compatibility is
   disabled.
3. **Sprint 5 rollback**: Revert human audit tooling. Raw schema v7 and Parquet
   assembly remain valid.
4. **Sprint 4 rollback**: Revert Python schema v7 support. Preserve raw v7 run
   folders as immutable artifacts; do not feed them to v6 tooling.
5. **Sprint 3 rollback**: Revert schema v7 MQL exporter to schema v6. Preserve or
   move v7 run folders out of active input roots; never rewrite headers in place.
6. **Sprint 2 rollback**: Revert cycle/revision state while retaining the one
   engine behavior from Sprint 1.
7. **Sprint 1 rollback**: Revert to the baseline S1/S2/S3 behavior, input surface,
   indicator visuals, and historical artifact compatibility.

Rollback constraints:

- Do not downgrade or relabel schema v7 artifacts as schema v6.
- Generated datasets/models/audits are ignored and may be removed after their
  source run IDs and evidence summaries are recorded.
- Broker positions opened under the new engine must be reconciled/closed safely
  before deploying a binary rolled back to behavior that cannot identify their
  engine comments. Never use destructive git commands as a runtime rollback.
- Rollback is performed through the recorded sprint commits, one sprint at a
  time, with compile/tester validation after any MQL5 rollback.

## Execution Order

1. Mark this document as active in `docs/plans/README.md` when implementation is
   authorized.
2. Implement Sprint 1 only.
3. Run and record all Sprint 1 validation.
4. Create exactly one Sprint 1 commit and record its rollback point.
5. Start Sprint 2 only after the Sprint 1 gate passes.
6. Repeat the complete/validate/one-commit/rollback-point gate for Sprints 2
   through 7.
7. Do not combine sprint commits, amend them, or start a later sprint early.
8. If a sprint fails, fix within that sprint and rerun its gate; if product/risk
   direction changes, update this plan before continuing.
9. Archive the plan only after final active-plan completion is recorded.

## Completion Checklist

- [ ] S1/S2/S3 inputs and active behavior are removed without compatibility
  shims.
- [ ] One M1 extremum engine produces only the structurally valid direction.
- [ ] M1/macro MA values cannot gate creation or activation.
- [ ] Breakout, SL/TP, broker, protection, license, session, margin, volume,
  magic, symbol, and reconciliation behavior passes review.
- [ ] Cycle/revision/attempt identity is deterministic and copy-safe.
- [ ] Fibonacci anchors are frozen and raw depths/point distances are correct.
- [ ] Schema v7 exports cycles, revisions, attempts, admissions, and broker facts
  with consistent counts.
- [ ] Simulated and broker outcomes are never conflated.
- [ ] Python validation and backward compatibility tests pass.
- [ ] DuckDB audit reports human depth/range/attempt/cycle profitability with
  distinct-cycle support.
- [ ] XGBoost splits are chronological and cycle-group safe.
- [ ] Old artifacts fail closed against the new engine.
- [ ] Performance/storage regression is measured and acceptable.
- [ ] Every sprint has exactly one sprint-specific commit and recorded rollback
  point.
- [ ] Active documentation matches implemented behavior.
