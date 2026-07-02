# Plan: Phase 5 Risk Range Foundation

**Generated**: 2026-07-02
**Estimated Complexity**: High
**Roadmap Phase**: Phase 5
**Primary Output**: Strategy-neutral range and risk foundation that no longer depends on removed Fibonacci feature semantics
**Validation Policy**: Static validation per sprint; one MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback only if needed
**Status**: Planned

## Overview

Phase 5 simplifies the current `Risk Managment Settings` surface into a strategy-range-compatible foundation while preserving the working execution, lot sizing, daily signal, and protection controls needed by future strategies.

This phase must remove active dependency on the old Fibonacci strategy-range model from public risk/range inputs and execution planning. Stoch Structure remains the structural context source, but the execution range contract must be strategy-neutral: a future strategy should be able to provide or request a range without inheriting Fibonacci-specific naming, inputs, or sequencing assumptions.

Phase 5 must not redesign final strategy rules, broker reconciliation, or local-vs-broker source-of-truth behavior. Phase 6 owns broker-aware local execution parity, and Phase 7 owns the deeper real-tick performance pass. This phase should avoid adding hot-path work and should preserve existing broker constraints, volume normalization, protection guards, and magic/symbol scoping.

## Current Baseline

- `services/trading_management/ea_inputs.mqh` still exposes `Base_Strategy_Type = FIB_LEVEL_RANGE` and `Points_Range_Setup`.
- `services/core/enums.mqh` still defines `RangeStrategyTypes` with `ATR_RANGE`, `POINTS_RANGE`, and `FIB_LEVEL_RANGE`.
- `services/trading_signals/execution_planner.mqh` still uses `FIB_LEVEL_RANGE` as the structure-based range branch and logs Fibonacci-specific diagnostics.
- `services/trading_management/strategy_structure_context.mqh` uses `Base_Strategy_Type == FIB_LEVEL_RANGE` to decide whether structure is required.
- `services/trading_signals/market_signal_filters.mqh` contains structure/Fibonacci entry helpers that are still part of the mock foundation.
- Lot sizing already uses `ExecutionLotTypes` and should remain compatible by ordinal behavior.
- Phase 4 compile baseline passed with `0 errors, 0 warnings`.

## Prerequisites

- Phase 0 through Phase 4 are complete and committed.
- Working tree is clean before execution.
- Do not add custom MQL5 tests, test harnesses, or CI.
- Compile is run once after all Phase 5 code and docs edits are complete.
- Preserve enum numeric semantics where user configuration compatibility depends on ordinal values.

## Target Vocabulary

Use this vocabulary unless local code makes a more precise name clearer:

- `Strategy_Range_Mode` for the public input currently represented by `Base_Strategy_Type`.
- `Strategy_Range_Points` for the public input currently represented by `Points_Range_Setup`.
- `StrategyRangeTypes` or the existing `RangeStrategyTypes` with strategy-neutral enum values.
- `STRATEGY_RANGE_ATR`, `STRATEGY_RANGE_POINTS`, and `STRATEGY_RANGE_STRUCTURE` as replacement enum values if the enum members are renamed.
- `structure range`, `strategy range`, `execution range`, and `range resolver` instead of Fibonacci range wording for active behavior.
- Keep `Fibonacci` names only for low-level math/helpers that still calculate percent/price transforms and are not public strategy semantics.

## Files Expected To Change

- `services/core/enums.mqh`
- `services/trading_management/ea_inputs.mqh`
- `services/trading_management/strategy_structure_context.mqh`
- `services/trading_management/indicator_definitions_loader.mqh`
- `services/trading_management/structure_fibonacci_levels.mqh` only if helper names/comments must be isolated
- `services/trading_signals/execution_planner.mqh`
- `services/trading_signals/execution_leg_helpers.mqh`
- `services/trading_signals/execution_logging.mqh`
- `services/trading_signals/market_signal_filters.mqh`
- `services/trading_signals/market_signal_indicators.mqh`
- `services/trading_signals/signal_params_struct.mqh`
- `services/frontend/lightweight_status_ui.mqh` only for public labels
- `HFT_Grid_AI.mq5` only for product description if the phase removes active Fibonacci-facing copy
- `README.md`, `AGENTS.md`, `ROADMAP.md`, and active docs under `docs/addons/` or `docs/architecture/`

## Non-Goals

- Do not implement the final production strategy.
- Do not remove Stoch Structure as the structural context source.
- Do not rewrite broker-aware execution parity; Phase 6 owns that.
- Do not add tests, harnesses, scripts, or CI.
- Do not run compile after every sprint; compile once at phase end.
- Do not weaken protection risk controls, daily signal limits, license gates, market-status gates, spread checks, broker stop/freeze checks, margin checks, volume normalization, or magic/symbol scoping.
- Do not do the broad real-tick performance pass; Phase 7 owns that.

## Sprint 1: Public Range Input Contract

**Goal**: Replace Fibonacci-specific public risk/range vocabulary with strategy-range vocabulary while preserving user-facing lot and protection controls.
**Commit**: `refactor: define strategy range inputs`
**Demo/Validation**:
- `rg "Base_Strategy_Type|FIB_LEVEL_RANGE|Points_Range_Setup" services/trading_management services/core services/trading_signals`
- `rg "Strategy_Range|RangeStrategyTypes|STRATEGY_RANGE" services`
- `git diff --check`

### Task 1.1: Rename Range Enum Values

- **Location**: `services/core/enums.mqh`
- **Description**: Rename active `RangeStrategyTypes` members away from `FIB_LEVEL_RANGE` into strategy-neutral values while preserving ordinals. Recommended mapping if no better local naming emerges:
  - `ATR_RANGE = 0` -> `STRATEGY_RANGE_ATR = 0`
  - `POINTS_RANGE = 1` -> `STRATEGY_RANGE_POINTS = 1`
  - `FIB_LEVEL_RANGE = 2` -> `STRATEGY_RANGE_STRUCTURE = 2`
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Numeric enum values are preserved.
  - No public enum member exposes Fibonacci as the active strategy range mode.
  - Default behavior remains equivalent to the current structure-based range mode unless explicitly changed later in the phase.
- **Validation**:
  - `rg "FIB_LEVEL_RANGE|ATR_RANGE|POINTS_RANGE" services/core services/trading_management services/trading_signals`

### Task 1.2: Rename Public Range Inputs

- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Rename `Base_Strategy_Type` and `Points_Range_Setup` to strategy-range names. Keep lot sizing, multiplier, target profit, daily signal, and protection inputs available unless a later task proves one is not strategy-neutral.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Risk/range group presents strategy-range terminology.
  - Existing non-mentioned input groups remain unchanged.
  - No deprecated input alias is kept.
- **Validation**:
  - `rg "Base_Strategy_Type|Points_Range_Setup|Risk Managment" services/trading_management`

### Task 1.3: Update Direct Input References

- **Location**: `services/trading_signals/`, `services/trading_management/`
- **Description**: Update direct references to renamed inputs and enum values without changing branch behavior.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance Criteria**:
  - All references compile by symbol after rename.
  - Structure mode still activates the same mock foundation path until Sprint 2 replaces semantics.
- **Validation**:
  - `rg "Base_Strategy_Type|Points_Range_Setup|FIB_LEVEL_RANGE|ATR_RANGE|POINTS_RANGE" services HFT_Grid_AI.mq5`

### Task 1.4: Update Active Labels And Diagnostics

- **Location**: `services/trading_signals/execution_logging.mqh`, `services/frontend/lightweight_status_ui.mqh`, `HFT_Grid_AI.mq5`
- **Description**: Replace active Fibonacci-facing labels that describe the current EA or range mode, while keeping low-level math/helper names for internal transforms where needed.
- **Dependencies**: Tasks 1.1-1.3.
- **Acceptance Criteria**:
  - Active logs and UI no longer present the foundation as Fibonacci-specific strategy behavior.
  - Product/repo/entrypoint names remain unchanged unless directly approved later.
- **Validation**:
  - `rg "Fibonacci EA|Fib EA|INPUTS_EXECUTION|Strategy_Range" services HFT_Grid_AI.mq5`

## Sprint 2: Strategy-Neutral Range Resolver

**Goal**: Replace the public Fibonacci range branch with a strategy-neutral range resolver that supports points, ATR, and structure range modes.
**Commit**: `refactor: add strategy range resolver`
**Demo/Validation**:
- `rg "Resolve.*Fibonacci.*Base|FIB_LEVEL|Strategy_Range|STRATEGY_RANGE" services/trading_signals services/trading_management`
- `git diff --check`

### Task 2.1: Introduce Range Resolution Contract

- **Location**: `services/trading_signals/execution_planner.mqh`
- **Description**: Introduce a small resolver contract for execution range calculation, keeping inputs to the existing `SignalParams`, timeframe, entry reference, and broker constraints. The resolver should return distance points and any structure step metadata needed by current execution legs.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Points mode uses `Strategy_Range_Points` and `EnforceBrokerDistance`.
  - ATR mode keeps the existing ATR behavior without adding extra per-tick work beyond the current baseline.
  - Structure mode uses Stoch Structure context but no longer exposes Fibonacci as the mode name.
- **Validation**:
  - `rg "CalculateBaseExecutionContext|Resolve.*Range|Strategy_Range" services/trading_signals/execution_planner.mqh`

### Task 2.2: Replace Fibonacci Base Distance Naming

- **Location**: `services/trading_signals/execution_leg_helpers.mqh`, `services/trading_signals/execution_planner.mqh`
- **Description**: Rename or wrap active `ResolveFibonacciExecutionBaseDistance` behavior into a structure-range helper. Keep low-level Fibonacci percentage math only as an implementation detail if still required by Stoch Structure.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Active execution planner no longer calls a Fibonacci-named base range resolver.
  - Structure range branch still produces broker-safe positive distance points.
  - No compatibility wrapper with the old public strategy naming remains.
- **Validation**:
  - `rg "ResolveFibonacciExecutionBaseDistance|Fibonacci.*Base|fib.*range" services/trading_signals`

### Task 2.3: Decouple Structure Requirements From Old Range Names

- **Location**: `services/trading_management/strategy_structure_context.mqh`, `services/trading_signals/market_signal_indicators.mqh`, `services/trading_signals/market_signal_filters.mqh`
- **Description**: Replace checks tied to the old structure/Fibonacci range value with strategy-neutral structure range checks.
- **Dependencies**: Tasks 2.1-2.2.
- **Acceptance Criteria**:
  - `AnyStructureGuardEnabled()` and `ContextRequiresStructure()` depend on the new strategy range contract.
  - Indicator loading still hydrates Stoch Structure only when needed by the active foundation.
  - Signal filters remain deterministic and fail closed when required structure data is unavailable.
- **Validation**:
  - `rg "FIB_LEVEL_RANGE|Base_Strategy_Type|Strategy_Range_Mode|STRATEGY_RANGE_STRUCTURE" services/trading_management services/trading_signals`

### Task 2.4: Normalize Range Diagnostics

- **Location**: `services/trading_signals/execution_planner.mqh`, `services/trading_signals/execution_logging.mqh`
- **Description**: Replace Fibonacci-specific debug fields in execution range diagnostics with strategy-neutral fields such as `range_mode`, `range_points`, `structure_steps`, `logical_next_price`, and `broker_safe_next_price`.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance Criteria**:
  - Diagnostics remain useful for signal/range troubleshooting.
  - No new per-tick logging is introduced.
  - Debug gates remain respected.
- **Validation**:
  - `rg "fib_|fibo|Fibonacci|range_mode|structure_steps" services/trading_signals/execution_planner.mqh services/trading_signals/execution_logging.mqh`

## Sprint 3: Lot, Protection, And Daily Limits Remain Strategy-Neutral

**Goal**: Keep execution lot sizing, daily signal limits, and protection behavior compatible with the new range foundation without weakening safeguards.
**Commit**: `refactor: keep risk controls strategy neutral`
**Demo/Validation**:
- `rg "Lot_Type|ExecutionLotTypes|Protection_Risk|Daily_Signal|Strategy_Range" services`
- `git diff --check`

### Task 3.1: Verify Lot Type Compatibility Against New Range Contract

- **Location**: `services/trading_signals/execution_lot_math.mqh`, `services/trading_signals/execution_planner.mqh`
- **Description**: Ensure fixed-lot, account-percentage target, and target-currency lot modes still resolve lots using the new strategy range points and broker volume normalization.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `ExecutionLotTypes` ordinal behavior remains unchanged.
  - `NormalizeVolumeForSymbol`, `NormalizeVolumeUpForSymbol`, and margin/target-lot feasibility behavior are preserved.
  - Target-profit lot modes do not silently open when the computed lot is infeasible.
- **Validation**:
  - `rg "ResolveEffectiveExecutionLotType|ResolveExecutionLegLotSize|NormalizeTargetModeRequiredLot|Strategy_Range" services/trading_signals`

### Task 3.2: Keep Protection Risk Controls Independent

- **Location**: `services/trading_signals/protection_risk_filter.mqh`, `services/trading_signals/market_signal_state.mqh`
- **Description**: Confirm protection risk modes, drawdown thresholds, daily/weekly locks, market-close guard, and forced close paths do not rely on removed range semantics.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - No range mode branch weakens protection controls.
  - Force-close paths still close signal arrays and broker positions by magic number and symbol.
  - Daily/weekly protection locks still reset by the proper timeframe anchor.
- **Validation**:
  - `rg "Protection_Risk|ENABLED_EXECUTION_PROTECTION|CloseAllExecutionLegs|Strategy_Range" services/trading_signals`

### Task 3.3: Keep Daily Signal Limits Strategy-Neutral

- **Location**: `services/trading_signals/market_signal_state.mqh`, `services/trading_signals/tick_signals_manager.mqh`
- **Description**: Ensure daily signal counters and outcome registration remain independent of the selected range mode.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Daily signal limits still apply to bullish and bearish outcomes.
  - Outcome registration still uses realized broker/source-of-truth profit when available.
  - No removed strategy-range assumptions are added.
- **Validation**:
  - `rg "Daily_Signal|RegisterDailySignalOutcome|SignalLimit" services/trading_signals`

### Task 3.4: Remove Or Isolate Remaining Active Fibonacci Strategy Semantics

- **Location**: `services/trading_signals/market_signal_filters.mqh`, `services/trading_management/structure_fibonacci_levels.mqh`, `services/indicators/fibonacci_calculator.mqh`
- **Description**: Decide per reference whether it is low-level math still needed by Stoch Structure or active strategy-facing behavior. Rename or isolate active behavior; leave internal math only when it is clearly implementation detail.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - Public risk/range inputs do not reference Fibonacci semantics.
  - Active execution planner and signal diagnostics do not describe the strategy as Fibonacci-driven.
  - Low-level Fibonacci helpers, if retained, are not presented as strategy mode or feature surface.
- **Validation**:
  - `rg "FIB_LEVEL_RANGE|Base_Strategy_Type|Fibonacci EA|Fib EA|fibo_steps|fib_level_offset" services HFT_Grid_AI.mq5`

## Sprint 4: Final Sweep, Compile Gate, And Documentation

**Goal**: Run the final static sweep, compile once, and document Phase 5 completion.
**Commit**: `docs: record phase 5 compile result`
**Demo/Validation**:
- Static sweeps show only approved low-level math names or historical docs.
- MetaEditor compile reports `0 errors, 0 warnings`.
- `git status --short` is clean after final commit.

### Task 4.1: Final Source Sweep

- **Location**: Active production source and active docs.
- **Description**: Search for old input names, enum values, Fibonacci-facing strategy labels, and risk/range wording that should no longer be active.
- **Dependencies**: Sprints 1-3.
- **Acceptance Criteria**:
  - No active `Base_Strategy_Type`, `Points_Range_Setup`, or `FIB_LEVEL_RANGE` references remain.
  - No active UI/log/input group presents the current foundation as Fibonacci-specific.
  - Any retained Fibonacci references are limited to low-level math helpers or explicitly documented implementation details.
- **Validation**:
  ```powershell
  rg "Base_Strategy_Type|Points_Range_Setup|FIB_LEVEL_RANGE" services HFT_Grid_AI.mq5
  rg "Fibonacci EA|Fib EA|fibo_steps|fib_level_offset" services HFT_Grid_AI.mq5 README.md AGENTS.md ROADMAP.md docs/addons docs/architecture
  git diff --check
  ```

### Task 4.2: Run Portable/Headless Compile

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile once after all Phase 5 edits.
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
  $log = Join-Path $logDir "phase-05-build.log"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  $argString = "/portable /s /compile:`"$entrypoint`" /log:`"$log`""
  $proc = Start-Process -FilePath $metaeditor -ArgumentList $argString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.3: Fallback Compile Only If Evidence Is Missing Or Fails

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run normal MetaEditor compile only if portable compile fails or does not produce usable evidence.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Fallback reason is documented.
  - Fallback result is parsed for warnings/errors.
- **Validation**:
  ```powershell
  $fallbackLog = Join-Path $logDir "phase-05-build-fallback.log"
  $fallbackArgString = "/s /compile:`"$entrypoint`" /log:`"$fallbackLog`""
  $fallbackProc = Start-Process -FilePath $metaeditor -ArgumentList $fallbackArgString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.4: Record Phase 5 Result

- **Location**: `ROADMAP.md`, `docs/plans/phase-05-risk-range-foundation-plan.md`
- **Description**: Record status, compile command, log/evidence path, process exit code, and result line.
- **Dependencies**: Task 4.2 or 4.3.
- **Acceptance Criteria**:
  - Phase 5 status is documented.
  - Compile result is documented.
  - Working tree is clean after final commit.
- **Validation**:
  - `git status --short`

## Phase 5 Acceptance Criteria

- Public risk/range inputs use strategy-range vocabulary.
- The range mode no longer depends on `FIB_LEVEL_RANGE` or Fibonacci-facing public strategy semantics.
- Lot sizing modes remain compatible under `ExecutionLotTypes`.
- Broker volume normalization and target-profit lot feasibility are preserved.
- Protection risk, market-close guard, and daily signal limits are not weakened.
- Stoch Structure remains available as the structural context source for the mock foundation.
- No custom tests, scripts, harnesses, or CI are added.
- `HFT_Grid_AI.mq5` compiles with `0 errors, 0 warnings`.

## Validation Strategy

Use static validation per sprint:

```powershell
rg "Base_Strategy_Type|Points_Range_Setup|FIB_LEVEL_RANGE" services HFT_Grid_AI.mq5
rg "Fibonacci EA|Fib EA|fibo_steps|fib_level_offset" services HFT_Grid_AI.mq5 README.md AGENTS.md ROADMAP.md docs/addons docs/architecture
rg "Strategy_Range|STRATEGY_RANGE|ExecutionLotTypes|Protection_Risk|Daily_Signal" services
git diff --check
git status --short
```

Run the MT5 compile gate once after all code and docs edits are complete. Do not run custom MQL5 tests.

## Potential Risks And Gotchas

- Public enum compatibility depends on numeric ordinals. Preserve values when renaming range enum members.
- Removing Fibonacci-facing strategy semantics can accidentally remove low-level math still used by Stoch Structure. Rename or isolate active behavior; do not delete required math blindly.
- `iATR` currently creates/releases a handle inside range resolution. Do not add more hot-path indicator work in this phase; Phase 7 owns optimization.
- Protection and daily limits are high-risk. Do not change their behavior unless a compile error or clear dependency requires it.
- Target-profit lot sizing depends on resolved range points. Ensure the new range resolver never returns invalid points silently.
- Some user `.set` files may reference old input names. This refoundation explicitly removes deprecated aliases, but enum ordinals should remain stable where practical.
- MetaEditor may return a non-zero process exit code even when the project log reports `0 errors, 0 warnings`; record both the process exit code and explicit log result.

## Rollback Plan

- Revert sprint commits in reverse order.
- If compile fails after input or enum renames, first verify all symbol references and enum ordinal values.
- If range resolution produces invalid points, restore the last known working branch and reintroduce strategy-neutral naming incrementally.
- If protection or daily-limit behavior is affected, revert the relevant sprint before attempting further cleanup.
