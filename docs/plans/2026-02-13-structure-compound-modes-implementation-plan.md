# Structure Compound Modes Implementation Plan

Date: 2026-02-13  
Status: Execution-aligned plan

## 1) Goal

Replace legacy base structure slot filters with a single compound mode input that maps to explicit 4-slot structure templates and parity twins.

Required behavior:
1. One user input for structure pattern filtering.
2. Deterministic template matching with fixed `EQ` semantics.
3. `COMPOUND_MODE_OFF` force-passes structure-type filtering.
4. Active compound modes fail closed on missing/invalid/insufficient structure snapshots.
5. `Strategy_Direction_Mode` remains the only position-direction controller.
6. Keep strict `Base_Fresh_Structure_Time` behavior independent from compound OFF.

## 2) Scope

In scope:
1. Add `TrendStructureCompoundModes`.
2. Add `Base_Structure_Compound_Filter`.
3. Remove legacy `TrendStructureFilterModes` and base slot/retest inputs.
4. Add a dedicated compound matcher helper.
5. Integrate matcher into `market_signal_filters`.
6. Replace legacy structure filter tests with compound tests.

Out of scope:
1. Reworking `Structure_Trigger_Entry` mechanics.
2. Adding new risk modules.
3. Expanding trend/macro/session contexts.

## 3) Locked Decisions

1. Identical sequences are deduped:
   - Keep `PULLBACK_CONTINUE_*`
   - Drop `REVERSAL_CONFIRM_*`
2. Uncommon modes are visible from day one:
   - `COMPOUND_MODE_CHOP_GUARD`
   - `COMPOUND_MODE_VOLATILITY_TRAP`
   - `COMPOUND_MODE_COMPRESSION_WAIT`
3. `COMPOUND_MODE_OFF` does not block structure-type filtering, even when structure data is missing.
4. `Candle_Strategy_Type == OFF_CANDLE_STRUCTURE` continues to pass candle filtering.
5. `Base_Fresh_Structure_Time` remains strict and can still reject entries on missing/stale structure data.
6. Snapshot timestamp fallback remains `second_structure_time` (then `first_structure_time`).

## 4) Implementation Phases

### Phase 1: Enum + Input Migration

Files:
1. `services/core/enums.mqh`
2. `services/trading_management/ea_inputs.mqh`

Tasks:
1. Remove `TrendStructureFilterModes`.
2. Add deduped `TrendStructureCompoundModes`.
3. Replace `Strategy Base Context` inputs with:
   - `Base_Structure_Compound_Filter`
   - `Base_Fresh_Structure_Time`

### Phase 2: Context and Matcher Layer

Files:
1. `services/trading_management/strategy_structure_context.mqh`
2. `services/trading_signals/structure_compound_modes.mqh`
3. `services/trading_signals.mqh`

Tasks:
1. Refactor context to carry compound filter only.
2. Implement canonical template resolution.
3. Evaluate parity twins internally.
4. Enforce strict `EQ` slot matching.

### Phase 3: Filter Integration

Files:
1. `services/trading_signals/market_signal_filters.mqh`

Tasks:
1. Remove legacy structure slot matcher path.
2. Integrate compound matcher into structure-type stage.
3. Keep `OFF => true` for structure-type checks.
4. Keep strict fresh-time evaluation and second-time fallback.

### Phase 4: Tests

Files:
1. `tests/harness/cases/structure_compound_modes_test_case.mqh`
2. `tests/structure_compound_modes_test.mq5`
3. `tests/hft_grid_ai_tests_harness.mq5`

Tasks:
1. Add compound parity pass cases.
2. Add one-slot mismatch fail cases.
3. Add `EQ` required/forbidden cases.
4. Add insufficient-depth fail-closed case.
5. Add `OFF` force-pass case for invalid snapshot.
6. Remove legacy structure filter mode test artifacts.

## 5) Validation Gates

1. Compile-only gate:
   `./scripts/run_mql5_tests.sh --compile-only`
2. Fast runtime smoke:
   `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`
3. Review:
   - `logs/test-runner/latest/summary.log`
   - `logs/test-runner/latest/compile/*.metaeditor.log`
   - `logs/test-runner/latest/runtime/*.terminal.log`
   - `logs/test-runner/latest/runtime/*.mql.log`
