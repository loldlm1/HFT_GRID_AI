# Plan: Phase 4 Domain Rename

**Generated**: 2026-07-02
**Estimated Complexity**: High
**Roadmap Phase**: Phase 4
**Primary Output**: Grid-domain naming replaced by strategy execution foundation naming without behavior expansion
**Validation Policy**: Static validation per sprint; one MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback only if needed

## Overview

Phase 4 removes the remaining grid-specific domain vocabulary from active production source now that Phase 3 removed the legacy feature surface. This is a mechanical, behavior-preserving rename phase across enums, input types, execution state structs, lifecycle helpers, log labels, frontend chart object helpers, file names, include guards, and active docs.

This phase must not redesign risk/range semantics, broker reconciliation, lot sizing formulas, or strategy rules. Phase 5 owns risk/range simplification, and Phase 6 owns broker-aware local execution parity. Phase 4 only changes names, public vocabulary, and stale comments so the foundation no longer presents the removed grid model as an active domain.

## Prerequisites

- Phase 0 through Phase 3 are complete and committed.
- Working tree is clean before execution.
- `HFT_Grid_AI.mq5` compiles at the Phase 3 baseline.
- No custom MQL5 tests or harnesses are reintroduced.
- Compile is run once after all Phase 4 code and docs edits are complete.

## Naming Targets

Use the following vocabulary unless local code makes a more specific name clearer:

- `Grid` / `grid` -> `Execution`, `execution`, `Leg`, or `Range` depending on context.
- `GridOrderState` -> `ExecutionLegState`.
- `grid_orders` -> `execution_legs`.
- `grid_sequence_id` -> `execution_sequence_id`.
- `grid_initialized` -> `execution_initialized`.
- `grid_base_distance_points` -> `execution_base_distance_points`.
- `grid_entry_reference_price` -> `execution_entry_reference_price`.
- `GridOrderStatuses` -> `ExecutionLegStatuses`.
- `GridEntryStyles` -> `ExecutionEntryStyles`.
- `GridLotTypes` -> `ExecutionLotTypes`.
- `GridBaseStrategyTypes` -> `ExecutionRangeStrategyTypes` or `RangeStrategyTypes`.
- `GridTPReferenceModes` -> `ExecutionTPReferenceModes` if still used.
- `ENABLED_GRID_PROTECTION*` -> `ENABLED_EXECUTION_PROTECTION*` while preserving ordinals.

Keep these out of scope unless the user explicitly requests a product rename:

- Repository folder name.
- `HFT_Grid_AI.mq5` entrypoint filename.
- License profile identifiers and backend `ea_id`.
- Historical docs under `docs/plans/archive/`.

## Files Expected To Change

- `services/core/enums.mqh`
- `services/trading_management/ea_inputs.mqh`
- `services/trading_signals.mqh`
- `services/trading_signals/signal_params_struct.mqh`
- `services/trading_signals/grid_price_resolver.mqh`
- `services/trading_signals/grid_order_helpers.mqh`
- `services/trading_signals/grid_order_math.mqh`
- `services/trading_signals/grid_order_logging.mqh`
- `services/trading_signals/grid_order_lifecycle.mqh`
- `services/trading_signals/grid_planner.mqh`
- `services/trading_signals/grid_order_controller.mqh`
- `services/trading_signals/tick_signals_manager.mqh`
- `services/trading_signals/market_signal_detection.mqh`
- `services/trading_signals/market_signal_cleanup.mqh`
- `services/trading_signals/market_signal_state.mqh`
- `services/trading_signals/market_signal_filters.mqh`
- `services/trading_signals/protection_risk_filter.mqh`
- `services/frontend.mqh`
- `services/frontend/grid_visual_utils.mqh`
- `services/frontend/grid_visual_lines.mqh`
- `services/frontend/grid_visualization.mqh`
- `HFT_Grid_AI.mq5`
- `README.md`
- `AGENTS.md`
- `ROADMAP.md`
- Active docs under `docs/addons/` and `docs/architecture/` if they mention active grid vocabulary.

## Files Expected To Be Renamed

Rename files only after their public symbols are renamed and the aggregator include order remains coherent:

- `services/trading_signals/grid_price_resolver.mqh` -> `services/trading_signals/execution_price_resolver.mqh`
- `services/trading_signals/grid_order_helpers.mqh` -> `services/trading_signals/execution_leg_helpers.mqh`
- `services/trading_signals/grid_order_math.mqh` -> `services/trading_signals/execution_lot_math.mqh`
- `services/trading_signals/grid_order_logging.mqh` -> `services/trading_signals/execution_logging.mqh`
- `services/trading_signals/grid_order_lifecycle.mqh` -> `services/trading_signals/execution_lifecycle.mqh`
- `services/trading_signals/grid_planner.mqh` -> `services/trading_signals/execution_planner.mqh`
- `services/trading_signals/grid_order_controller.mqh` -> `services/trading_signals/execution_controller.mqh`
- `services/frontend/grid_visual_utils.mqh` -> `services/frontend/execution_visual_utils.mqh`
- `services/frontend/grid_visual_lines.mqh` -> `services/frontend/execution_visual_lines.mqh`
- `services/frontend/grid_visualization.mqh` -> `services/frontend/execution_visualization.mqh`

## Non-Goals

- Do not change final strategy behavior.
- Do not change broker execution behavior.
- Do not simplify risk/range inputs beyond names required to remove grid vocabulary.
- Do not remove Fibonacci or Stoch Structure internals required by the current mock foundation.
- Do not add custom tests, scripts, CI, or Strategy Tester harnesses.
- Do not rename the EA entrypoint file or repo folder.

## Sprint 1: Public Enums And Inputs

**Goal**: Remove public `GRID_` enum values and grid-named input types while preserving numeric semantics.
**Commit**: `refactor: rename public grid enums`
**Demo/Validation**:
- `rg "GRID_LOT|GRID_ENTRY|GRID_ORDER|GRID_TP|ENABLED_GRID|GridLotTypes|GridEntryStyles|GridOrderStatuses|GridTPReferenceModes|GridBaseStrategyTypes" services/core services/trading_management services/trading_signals`
- `git diff --check`

### Task 1.1: Rename Lot Type Enum Values

- **Location**: `services/core/enums.mqh`, `services/trading_management/ea_inputs.mqh`, `services/trading_signals/grid_order_math.mqh`, `services/trading_signals/grid_planner.mqh`
- **Description**: Rename `GridLotTypes` to `ExecutionLotTypes` and replace `GRID_LOT_SIZE`, `GRID_LOT_PERCENTAGE_BASED`, and `GRID_LOT_CURRENCY_BASED` with non-grid names while preserving ordinal values `0`, `1`, and `2`.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Existing input compatibility by ordinal is preserved.
  - `Lot_Type` still compiles as an input.
  - No `GRID_LOT_*` references remain.
- **Validation**:
  - `rg "GRID_LOT|GridLotTypes" services HFT_Grid_AI.mq5`

### Task 1.2: Rename Execution Leg Status And Entry Style Enums

- **Location**: `services/core/enums.mqh`, `services/trading_signals/signal_params_struct.mqh`, `services/trading_signals/grid_order_lifecycle.mqh`, `services/trading_signals/grid_order_controller.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Rename `GridOrderStatuses` and `GridEntryStyles` to execution-leg names. Replace `GRID_ORDER_*` and `GRID_ENTRY_STYLE_*` values with `EXECUTION_LEG_*` and `EXECUTION_ENTRY_STYLE_*` equivalents while preserving ordinal values.
- **Dependencies**: Task 1.1 can run in parallel if edits do not touch the same lines.
- **Acceptance Criteria**:
  - Execution status semantics remain unchanged.
  - No `GRID_ORDER_*` or `GRID_ENTRY_STYLE_*` enum values remain in active source.
- **Validation**:
  - `rg "GRID_ORDER|GRID_ENTRY|GridOrderStatuses|GridEntryStyles" services HFT_Grid_AI.mq5`

### Task 1.3: Rename Range Strategy And TP Reference Types

- **Location**: `services/core/enums.mqh`, `services/trading_management/ea_inputs.mqh`, `services/trading_signals/grid_planner.mqh`, `services/trading_signals/grid_order_helpers.mqh`
- **Description**: Rename `GridBaseStrategyTypes` and `GridTPReferenceModes` to execution/range names without changing enum member ordinals or branch behavior.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - `ATR_RANGE`, `POINTS_RANGE`, and `FIB_LEVEL_RANGE` keep their values.
  - No active `GridBaseStrategyTypes` or `GridTPReferenceModes` references remain.
- **Validation**:
  - `rg "GridBaseStrategyTypes|GridTPReferenceModes|GRID_TP" services HFT_Grid_AI.mq5`

### Task 1.4: Rename Protection Mode Values

- **Location**: `services/core/enums.mqh`, `services/trading_signals/protection_risk_filter.mqh`, active docs if needed.
- **Description**: Rename `ENABLED_GRID_PROTECTION`, `ENABLED_GRID_PROTECTION_DAILY`, and `ENABLED_GRID_PROTECTION_WEEKLY` to execution-protection names while preserving values `1`, `2`, and `3`.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Protection behavior remains unchanged.
  - No `ENABLED_GRID_*` references remain in active source.
- **Validation**:
  - `rg "ENABLED_GRID" services HFT_Grid_AI.mq5`

## Sprint 2: Execution State And Lifecycle Identifiers

**Goal**: Rename core signal execution state from grid/order terminology to execution/leg terminology.
**Commit**: `refactor: rename execution state domain`
**Demo/Validation**:
- `rg "GridOrderState|grid_orders|grid_sequence_id|grid_initialized|grid_base|grid_entry|grid_resolved|grid_initial" services HFT_Grid_AI.mq5`
- `git diff --check`

### Task 2.1: Rename Signal Execution State Fields

- **Location**: `services/trading_signals/signal_params_struct.mqh`
- **Description**: Rename `GridOrderState` to `ExecutionLegState` and rename `SignalParams` fields from `grid_*` to `execution_*` or `range_*` names.
- **Dependencies**: Sprint 1 enum names.
- **Acceptance Criteria**:
  - Copy constructor assigns all renamed fields.
  - Array field `execution_legs[]` replaces `grid_orders[]`.
  - No stale `grid_*` fields remain in `SignalParams`.
- **Validation**:
  - `rg "GridOrderState|grid_orders|grid_sequence_id|grid_initialized|grid_base|grid_entry|grid_resolved|grid_initial" services/trading_signals/signal_params_struct.mqh`

### Task 2.2: Rename Planner And Lifecycle Function Families

- **Location**: `services/trading_signals/grid_planner.mqh`, `services/trading_signals/grid_order_lifecycle.mqh`, `services/trading_signals/grid_order_controller.mqh`, `services/trading_signals/tick_signals_manager.mqh`
- **Description**: Rename function families such as `BuildGridOrderForSignal`, `UpdateGridLifecycle`, `IsGridSignalComplete`, `GridExecuteLevelTrade`, and `GridCloseAllLevels` to execution/leg names.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Call graph compiles by symbol after rename.
  - Function behavior and branch conditions are unchanged.
  - No `Grid*Lifecycle`, `Grid*Order`, or `Grid*SignalComplete` active references remain.
- **Validation**:
  - `rg "BuildGrid|UpdateGrid|IsGrid|GridExecute|GridClose|GridOrder|grid_order" services/trading_signals HFT_Grid_AI.mq5`

### Task 2.3: Rename Helper And Math Function Families

- **Location**: `services/trading_signals/grid_order_helpers.mqh`, `services/trading_signals/grid_order_math.mqh`, `services/trading_signals/grid_price_resolver.mqh`
- **Description**: Rename broker-safe helper, level, lot, and projected-profit functions from `Grid*` to `Execution*`, `Leg*`, or `Range*` names.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Broker-distance, spread, volume, margin, and price-normalization checks remain intact.
  - No hot-path allocations or extra market-data calls are introduced.
- **Validation**:
  - `rg "GridResolve|GridCurrent|GridGuard|GridPoints|GridAbsolute|GridHas|GetGrid|ResolveGrid|ProjectedGrid|grid_" services/trading_signals`

### Task 2.4: Rename Signal Detection Assignments

- **Location**: `services/trading_signals/market_signal_detection.mqh`, `services/trading_signals/market_signal_filters.mqh`, `services/trading_signals/market_signal_cleanup.mqh`, `services/trading_signals/market_signal_state.mqh`
- **Description**: Update signal creation, duplicate detection, cleanup, and state tracking to the renamed execution fields and functions.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance Criteria**:
  - Sequence ID and structure de-duplication behavior stays unchanged.
  - Cleanup still removes chart objects through renamed frontend helpers.
- **Validation**:
  - `rg "grid_|Grid" services/trading_signals/market_signal_detection.mqh services/trading_signals/market_signal_filters.mqh services/trading_signals/market_signal_cleanup.mqh services/trading_signals/market_signal_state.mqh`

## Sprint 3: File Names, Aggregators, Logs, And Frontend

**Goal**: Rename file-level modules, include guards, logging labels, chart helpers, and active docs.
**Commit**: `refactor: rename execution modules and telemetry`
**Demo/Validation**:
- `rg "grid_|Grid[A-Z]|GRID_" services HFT_Grid_AI.mq5 README.md AGENTS.md ROADMAP.md docs/addons docs/architecture`
- `git diff --check`

### Task 3.1: Rename Trading Signal Module Files

- **Location**: `services/trading_signals.mqh`, files listed in "Files Expected To Be Renamed"
- **Description**: Rename `grid_*` trading signal files to execution names, then update aggregator includes in the same ordered chain.
- **Dependencies**: Sprint 2 should complete first to reduce churn.
- **Acceptance Criteria**:
  - Include order remains sequential.
  - No deleted file path remains in aggregators.
  - Include guards match the new filenames.
- **Validation**:
  - `rg "grid_price_resolver|grid_order_helpers|grid_order_math|grid_order_logging|grid_order_lifecycle|grid_planner|grid_order_controller" services HFT_Grid_AI.mq5`

### Task 3.2: Rename Frontend Visualization Modules

- **Location**: `services/frontend.mqh`, `services/frontend/grid_visual_utils.mqh`, `services/frontend/grid_visual_lines.mqh`, `services/frontend/grid_visualization.mqh`, `HFT_Grid_AI.mq5`
- **Description**: Rename frontend module files and functions from grid visuals to execution visuals. Rename chart object prefixes and object names away from `GRID` unless the name is the unchanged product identity.
- **Dependencies**: Tasks 2.1-2.4.
- **Acceptance Criteria**:
  - `RefreshExecutionVisualization()` or equivalent replaces `RefreshGridVisualization()`.
  - `ResetExecutionVisualizationCache()` or equivalent replaces `ResetGridVisualizationCache()`.
  - Chart labels remain concise and readable.
  - No active chart object names use `GRID_`.
- **Validation**:
  - `rg "GridVisualization|GridSignal|GRID_|grid_visual|HFT_GRID" services/frontend HFT_Grid_AI.mq5`

### Task 3.3: Rename Logging And Query Debug Vocabulary

- **Location**: renamed execution logging module, `logs` labels emitted by active code.
- **Description**: Rename labels and messages such as `INPUTS_GRID`, `GRID_STOP_LEVEL_LIMIT`, and `GRID_*` comments to execution vocabulary while preserving useful signal diagnostics.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Logs do not describe active behavior as grid.
  - Existing debug gates remain respected.
  - No new per-tick logging is introduced.
- **Validation**:
  - `rg "INPUTS_GRID|GRID_STOP|GRID_|grid" services/trading_signals services/frontend`

### Task 3.4: Update Active Docs And Roadmap

- **Location**: `README.md`, `AGENTS.md`, `ROADMAP.md`, `docs/addons/`, `docs/architecture/`
- **Description**: Replace active grid-domain language with execution foundation language and document the Phase 4 rename result. Keep historical phase plans as history.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - Active docs no longer instruct contributors to use grid terminology for current behavior.
  - Roadmap marks Phase 4 execution status during/after implementation.
- **Validation**:
  - `rg "grid-specific|GRID_|Grid[A-Z]|grid_" README.md AGENTS.md ROADMAP.md docs/addons docs/architecture`

## Sprint 4: Final Static Sweep And Compile Gate

**Goal**: Resolve rename fallout, run the single Phase 4 MetaEditor compile gate, and document the result.
**Commit**: `docs: record phase 4 compile result`
**Demo/Validation**:
- Targeted `rg` sweeps return only approved product identity or historical plan/archive references.
- MetaEditor compile reports `0 errors, 0 warnings`.
- `git status --short` is clean after final commit.

### Task 4.1: Full Production Rename Sweep

- **Location**: Entire active production source.
- **Description**: Run broad searches and fix any remaining active grid-domain references that are not explicitly out of scope.
- **Dependencies**: Sprints 1-3.
- **Acceptance Criteria**:
  - No `GRID_` enum value remains for active behavior.
  - No `grid_` identifiers remain in active source.
  - No `Grid[A-Z]` function/type names remain in active source.
  - File names and include guards use execution naming.
- **Validation**:
  ```powershell
  rg "GRID_|Grid[A-Z]|grid_" services HFT_Grid_AI.mq5
  rg "grid_price_resolver|grid_order_helpers|grid_order_math|grid_order_logging|grid_order_lifecycle|grid_planner|grid_order_controller|grid_visual" services HFT_Grid_AI.mq5
  git diff --check
  ```

### Task 4.2: Run Portable/Headless Compile

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile once after all Phase 4 edits.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Compile reports `0 errors, 0 warnings`.
  - No custom tests or harnesses are run.
- **Validation**:
  ```powershell
  $mt5Root = "C:\Program Files\MetaTrader 5-1"
  $metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
  $entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
  $logDir = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile"
  $log = Join-Path $logDir "phase-04-build.log"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  & $metaeditor /portable /s /compile:$entrypoint /log:$log
  ```

### Task 4.3: Fallback Compile Only If Portable Evidence Is Missing Or Fails

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run normal MetaEditor compile only if portable compile fails or does not produce usable evidence.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Fallback reason is documented.
  - Fallback result is parsed for warnings/errors.
- **Validation**:
  ```powershell
  $fallbackLog = Join-Path $logDir "phase-04-build-fallback.log"
  & $metaeditor /s /compile:$entrypoint /log:$fallbackLog
  ```

### Task 4.4: Record Phase 4 Result

- **Location**: `ROADMAP.md`, `docs/plans/phase-04-domain-rename-plan.md`
- **Description**: Record status, compile command, log/evidence path, process exit code, and result line.
- **Dependencies**: Task 4.2 or 4.3.
- **Acceptance Criteria**:
  - Phase 4 status is documented.
  - Compile result is documented.
  - Working tree is clean after final commit.
- **Validation**:
  - `git status --short`

## Phase 4 Acceptance Criteria

- Public lot type enum values no longer use `GRID_`.
- Active production code no longer uses `Grid[A-Z]`, `grid_`, or `GRID_` identifiers for current behavior.
- Execution state uses execution/leg/range vocabulary.
- File names and include guards are renamed away from grid-domain module names.
- Frontend chart helpers and logs no longer present active behavior as grid.
- Historical archive plans may retain old vocabulary.
- `HFT_Grid_AI.mq5` compiles with `0 errors, 0 warnings`.

## Validation Strategy

Use targeted validation during sprints:

```powershell
rg "GRID_|Grid[A-Z]|grid_" services HFT_Grid_AI.mq5
rg "grid_price_resolver|grid_order_helpers|grid_order_math|grid_order_logging|grid_order_lifecycle|grid_planner|grid_order_controller|grid_visual" services HFT_Grid_AI.mq5
rg "GRID_LOT|GRID_ENTRY|GRID_ORDER|GRID_TP|ENABLED_GRID|GridLotTypes|GridEntryStyles|GridOrderStatuses|GridTPReferenceModes|GridBaseStrategyTypes" services HFT_Grid_AI.mq5
git diff --check
git status --short
```

Run the MT5 compile gate once after all code and docs edits are complete.

## Potential Risks And Gotchas

- MQL5 enum input compatibility depends on numeric ordinals. Preserve enum values during rename.
- Broad symbol renames can silently miss string literals, log labels, chart object names, include guards, and comments. Use both identifier and string searches.
- File renames can break include order. Update only aggregators and keep the existing service cascade.
- Frontend chart object prefix changes may leave old chart objects on existing charts. Decide during execution whether to delete old cleanup strings completely or isolate one temporary cleanup path; do not keep grid vocabulary as active behavior.
- `HFT_Grid_AI` remains the entrypoint and repository identity unless the user explicitly requests product renaming.
- Phase 5 will simplify risk/range semantics. Avoid mixing semantic changes into this rename phase.
- Compile logs may be emitted only to `C:\Program Files\MetaTrader 5-1\logs\metaeditor.log` even when `/log:` is provided, as observed in Phase 3.

## Rollback Plan

- Revert sprint commits in reverse order.
- If compile fails after a file rename, first verify aggregators and include guards before changing logic.
- If enum input compatibility is accidentally broken, restore the original ordinal values immediately and re-run static validation.
