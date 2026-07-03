# Plan: Phase 7 Real-Tick Performance

**Generated**: 2026-07-03
**Estimated Complexity**: High
**Roadmap Phase**: Phase 7
**Primary Output**: Real-tick Strategy Tester performance pass with bounded tick work, reused indicator handles, scoped broker reads, quieter logging, and tester-safe frontend throttling
**Validation Policy**: Static validation per sprint; one MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback only if needed
**Status**: Completed

## Completion Evidence

- **Completed**: 2026-07-03.
- **Sprint commits**:
  - Sprint 1: `5f2ec9a perf: reuse execution indicator handles`
  - Sprint 2: `937878b perf: bound structure buffer reads`
  - Sprint 3: `cd9c8f3 perf: reduce execution tick overhead`
  - Sprint 4: `f3055d4 perf: throttle frontend refresh`
- **Static validation**: final sweeps confirmed cached ATR handle usage, deterministic indicator release, bounded Stoch Structure buffer depth, ticket-first broker reconciliation, gated logging, frontend refresh throttling, and no production `4320` structure copy depth.
- **Compile evidence**: portable/headless MetaEditor compile wrote `logs/compile/phase-07-build.log` with `result 0 errors, 0 warnings, 329 ms elapsed, cpu='X64 Regular'`. The MetaEditor process returned exit code `1`, so the explicit log result is the pass/fail source of truth for this phase.
- **Fallback compile**: not run because portable/headless compile produced valid evidence.
- **Custom tests/CI**: not run and not added.

## Overview

Phase 7 reduces hot-path cost for real-tick Strategy Tester optimization without changing strategy behavior.

The current foundation is compile-clean after Phase 6 and has broker-aware local execution plus scoped broker reconciliation. This phase should keep that source-of-truth contract intact while reducing repeated per-tick work: repeated indicator handle creation, large buffer copies, repeated `SymbolInfo*` and `PositionSelect*` reads, repeated array resizing, and chart/logging work that is expensive in tester runs.

This is an optimization/refactor phase, not a strategy redesign. Each sprint must preserve trading semantics, validate statically, and commit before moving to the next sprint. The MT5 compile gate runs once at the end of Sprint 4 only.

## Current Baseline

- `ResolveAtrRangeDistancePoints()` in `services/trading_signals/execution_planner.mqh` creates an `iATR` handle, copies one buffer value, and releases the handle inside range resolution.
- Stoch Structure handles are created in `LoadAllStructStochIndicators()` but there is no explicit release path in `OnDeinit()`.
- `DetectMarketExtrema()` copies five buffers with a fixed `4320` bar depth even though callers usually need a small structure depth.
- `OnTick()` calls `RefreshCustomSymbolRates()` through `CSymbolInfo.Refresh()` and `RefreshRates()` every tick.
- Broker-aware execution now centralizes local checks, but margin/symbol data and position reconciliation can still read broker/platform state repeatedly at activation or lifecycle points.
- `RefreshExecutionVisualization()` is guarded in non-visual tester mode, but visual/live chart work still builds object arrays, preview lots, labels, summaries, and deletes stale objects every refresh.
- File logging is gated by `Enable_File_Logs`, but query-debug state uses dynamic arrays and formatted strings when enabled.

## Prerequisites

- Phase 0 through Phase 6 are complete and committed.
- Working tree is clean before execution.
- Do not add custom MQL5 tests, harnesses, scripts, or CI.
- Compile is run once after all Phase 7 code and docs edits are complete.
- Preserve broker-aware local execution and real broker source-of-truth behavior from Phase 6.
- Preserve public input behavior unless a new input is strictly required for performance control.

## Files Expected To Change

- `HFT_Grid_AI.mq5`
- `services/trading_signals.mqh`
- `services/trading_management/indicator_definitions_loader.mqh`
- `services/indicators/extrema_detector.mqh`
- `services/indicators/stochastic_market_indicator.mqh`
- `services/trading_signals/execution_planner.mqh`
- `services/trading_signals/execution_broker_context.mqh`
- `services/trading_signals/execution_broker_reconciliation.mqh`
- `services/trading_signals/execution_lifecycle.mqh`
- `services/trading_signals/execution_controller.mqh`
- `services/trading_signals/execution_logging.mqh`
- `services/frontend/runtime_guard.mqh`
- `services/frontend/execution_visualization.mqh`
- `services/frontend/lightweight_status_ui.mqh`
- `ROADMAP.md`
- `docs/architecture/execution-foundation.md`
- `docs/plans/phase-07-real-tick-performance-plan.md`

Expected new files, if they keep ownership clearer:

- `services/trading_signals/execution_indicator_cache.mqh`
- `services/trading_signals/execution_runtime_cache.mqh`

## Files Expected To Be Deleted

None expected.

Delete only obsolete performance helpers if a sprint proves they are unreachable after replacement. Do not delete historical docs or license/shared-service files in this phase.

## Non-Goals

- Do not implement or redesign final strategy rules.
- Do not weaken broker constraints, margin checks, spread checks, protection risk, session filters, license gates, daily limits, or magic/symbol scoping.
- Do not remove Phase 6 local-vs-broker source-of-truth behavior.
- Do not add custom tests, harnesses, scripts, or CI.
- Do not run compile after each sprint.
- Do not add external dependencies or use terminal runtime tests.
- Do not optimize by hiding errors, suppressing required compile warnings, or skipping cleanup paths.
- Do not make frontend/chart objects influence trading decisions.

## Target Performance Contract

Use these principles throughout Phase 7:

- Indicator handles are created during initialization or lazy cached once, reused, and released in `OnDeinit()`.
- Tick-path indicator reads copy only the minimum bars needed for the current decision.
- Broker and symbol facts are captured once per decision boundary and passed by reference where possible.
- Position reconciliation avoids repeated full `PositionsTotal()` scans when a valid ticket already exists.
- Logging and chart work are quiet by default in non-visual tester runs and throttled for visual/live chart refresh.
- Arrays that grow in hot paths use existing reserve helpers or pre-sized local buffers where practical.

## Sprint 1: Indicator Handle Lifecycle And ATR Cache

**Goal**: Remove repeated ATR handle creation from range resolution and add deterministic release for indicator handles.
**Commit**: `perf: reuse execution indicator handles`
**Demo/Validation**:
- ATR range resolution uses a cached handle instead of creating/releasing on every call.
- Stoch Structure and ATR handles have explicit release paths.
- `git diff --check`

### Task 1.1: Add Execution Indicator Cache

- **Location**: `services/trading_signals/execution_indicator_cache.mqh`, `services/trading_signals.mqh`
- **Description**: Add a small cache for execution-owned indicator handles, starting with ATR by symbol/timeframe/period.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - ATR handle is created once for the resolved timeframe and period.
  - Cached handle is invalidated if symbol, timeframe, or period changes.
  - Helper returns `INVALID_HANDLE` on failure without crashing.
  - Include order remains through `services/trading_signals.mqh`.
- **Validation**:
  - `rg "execution_indicator_cache|ResolveExecutionAtrHandle|iATR|IndicatorRelease" services/trading_signals services/trading_management HFT_Grid_AI.mq5`

### Task 1.2: Replace Per-Call ATR Handle Creation

- **Location**: `services/trading_signals/execution_planner.mqh`
- **Description**: Update `ResolveAtrRangeDistancePoints()` to use the cached ATR handle and copy only the closed candle value it needs.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - No `iATR()` call remains inside `ResolveAtrRangeDistancePoints()`.
  - No `IndicatorRelease()` call remains in the ATR distance resolver.
  - Existing ATR mode behavior still uses the closed candle shift.
- **Validation**:
  - `rg "ResolveAtrRangeDistancePoints|iATR|IndicatorRelease|CopyBuffer" services/trading_signals/execution_planner.mqh services/trading_signals/execution_indicator_cache.mqh`

### Task 1.3: Release Cached Handles On Deinit

- **Location**: `HFT_Grid_AI.mq5`, `services/trading_management/indicator_definitions_loader.mqh`, `services/trading_signals/execution_indicator_cache.mqh`
- **Description**: Add deterministic release helpers for Stoch Structure handles and execution indicator cache handles, then call them in `OnDeinit()`.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance Criteria**:
  - Stoch Structure handles loaded into `ExtStructStochIndicatorsHandle` are released.
  - ATR cache handle is released.
  - Arrays are cleared after release.
  - Releasing handles is idempotent.
- **Validation**:
  - `rg "Release.*Indicator|IndicatorRelease|ExtStructStochIndicatorsHandle|OnDeinit" services HFT_Grid_AI.mq5`

### Task 1.4: Gate Noisy Indicator Startup Logs

- **Location**: `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Keep critical errors visible, but gate success/startup indicator logs behind `Enable_Logs` so optimization runs do not print unnecessary messages.
- **Dependencies**: Task 1.3.
- **Acceptance Criteria**:
  - Failed indicator creation still logs.
  - Success logs are gated.
  - No behavior change to handle loading.
- **Validation**:
  - `rg "LOADED STRUCTURE|Strategy context|Enable_Logs|ERROR LOADING STRUCTURE" services/trading_management/indicator_definitions_loader.mqh`

## Sprint 2: Bounded Structure Buffer Reads

**Goal**: Reduce large `CopyBuffer` and series-array work in Stoch Structure snapshot loading.
**Commit**: `perf: bound structure buffer reads`
**Demo/Validation**:
- Structure detection no longer copies fixed 4320 bars unconditionally.
- Buffer depth is derived from needed structure depth with a safe cap.
- `git diff --check`

### Task 2.1: Add Structure Copy Depth Resolver

- **Location**: `services/indicators/extrema_detector.mqh`, `services/trading_management/strategy_structure_context.mqh`
- **Description**: Add a helper that computes a bounded copy depth from requested extrema depth and indicator period.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Default depth remains sufficient for current `max_depth = 13` behavior.
  - Copy depth has a minimum safety window and a maximum cap.
  - The magic `4320` value is isolated behind a named constant or removed.
- **Validation**:
  - `rg "4320|STRUCTURE.*COPY|Resolve.*Depth|CopyBuffer" services/indicators services/trading_management`

### Task 2.2: Copy Only Required Structure Buffers

- **Location**: `services/indicators/extrema_detector.mqh`
- **Description**: Replace fixed-depth `CopyBuffer()` calls with the resolved copy depth, keeping the same five buffers and closed/current indexing behavior.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - All five buffer copies use the same bounded depth.
  - Failure handling remains fail-closed for invalid copies.
  - Array series orientation remains correct.
  - The scan loop iterates only over copied bars.
- **Validation**:
  - `rg "CopyBuffer\\(indicator_handle|ArraySetAsSeries|for\\(int i = 1" services/indicators/extrema_detector.mqh`

### Task 2.3: Reduce Per-Bar Price Calls During Structure Scan

- **Location**: `services/indicators/extrema_detector.mqh`
- **Description**: Avoid unnecessary `iHigh`, `iLow`, and `iTime` calls where a bar is not relevant to structure detection, or group them after cheap buffer checks.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Price/time calls happen only when needed for initial range tracking or confirmed extrema handling.
  - Structure semantics remain equivalent for initial peak/bottom detection.
  - No full-history scan is introduced.
- **Validation**:
  - `rg "iHigh|iLow|iTime|indicator_extremum_values|indicator_peak_values|indicator_bottom_values" services/indicators/extrema_detector.mqh`

### Task 2.4: Keep Structure Snapshot Loading Fail-Closed

- **Location**: `services/indicators/stochastic_market_indicator.mqh`, `services/trading_signals/market_signal_indicators.mqh`
- **Description**: Confirm callers still fail closed when bounded structure data is unavailable.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance Criteria**:
  - Invalid structure snapshots do not produce signals.
  - Debug/tester stop behavior for critical indicator failures remains explicit.
  - No new fallback opens trades without structure data.
- **Validation**:
  - `rg "LoadStructureSnapshotFromHandle|CaptureContextIndicators|structure_valid|TesterStop" services/indicators services/trading_signals`

## Sprint 3: Broker, Logging, And Array Hot-Path Boundaries

**Goal**: Reduce repeated broker/platform reads, position scans, dynamic array churn, and logging work on active tick paths.
**Commit**: `perf: reduce execution tick overhead`
**Demo/Validation**:
- Broker snapshots reuse cached symbol constraints and avoid repeated symbol reads where possible.
- Position reconciliation avoids full scans when a valid scoped ticket exists.
- Query debug logging remains gated and avoids unnecessary state array growth.
- `git diff --check`

### Task 3.1: Tighten Broker Execution Snapshot Reads

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/utils/broker_constraints_helper.mqh`
- **Description**: Reuse `g_symbol_constraints` for point/tick/volume facts and avoid duplicate `SymbolInfo*` reads in the hot activation boundary unless the cache is invalid or stale.
- **Dependencies**: Sprints 1-2.
- **Acceptance Criteria**:
  - Margin estimate uses cached contract/point facts where safe.
  - Constraint refresh remains time-bounded and fail-closed.
  - No risk guard is weakened.
- **Validation**:
  - `rg "SymbolInfoDouble|SymbolInfoInteger|g_symbol_constraints|BrokerExecutionEstimateMarginPerLot|CaptureBrokerExecutionSnapshot" services/trading_signals services/utils`

### Task 3.2: Avoid Position Full Scan When Ticket Is Valid

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Ensure reconciliation uses ticket-first selection and only falls back to a full positions scan when the ticket is missing or stale.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Valid ticket path performs no `PositionsTotal()` scan.
  - Fallback scan remains scoped by symbol, magic number, direction, and comment.
  - Missing ticket behavior remains deterministic.
- **Validation**:
  - `rg "PositionsTotal|PositionGetTicket|SelectBrokerPositionSnapshotByTicket|FindBrokerPositionSnapshotByComment" services/trading_signals/execution_broker_reconciliation.mqh services/trading_signals/execution_lifecycle.mqh`

### Task 3.3: Reduce Query Debug Dynamic Array Churn

- **Location**: `services/trading_signals/execution_logging.mqh`
- **Description**: Add reserve sizing or a bounded changed-state cache for query debug state arrays so enabled file logging does not resize arrays one element at a time indefinitely.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - `Enable_File_Logs == false` remains a near-zero-cost return path.
  - Changed-state cache has bounded or reserved growth.
  - No log labels required for troubleshooting are removed.
- **Validation**:
  - `rg "ExecutionShouldLogChangedState|ArrayResize\\(g_query_debug|Enable_File_Logs|ExecutionAppendQueryDebug" services/trading_signals/execution_logging.mqh`

### Task 3.4: Reserve Arrays In Active Signal/Object Helpers

- **Location**: `services/utils/array_functions.mqh`, `services/frontend/execution_visual_utils.mqh`, `services/frontend/execution_visualization.mqh`
- **Description**: Use reserve sizes consistently where helper arrays grow in active paths, without changing array contents or ordering.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - Existing `AddElementToArray()` reserve behavior remains intact.
  - Hot-path object tracking arrays avoid avoidable one-by-one reallocations where practical.
  - No chart object behavior changes.
- **Validation**:
  - `rg "ArrayResize|AddElementToArray|PushObjectName|summary_lines|current_objects" services/utils services/frontend`

## Sprint 4: Frontend Throttle, Final Sweep, Compile Gate, And Documentation

**Goal**: Keep chart/frontend work from dominating tester/live ticks, run final static sweeps, compile once, and document Phase 7 completion.
**Commit**: `perf: throttle frontend refresh`
**Documentation Commit**: `docs: record phase 7 compile result`
**Demo/Validation**:
- Chart work remains disabled in non-visual tester mode and throttled in visual/live mode.
- Static sweeps show bounded indicator, broker, logging, and frontend hot paths.
- MetaEditor compile reports `0 errors, 0 warnings`.
- `git status --short` is clean after final commit.

### Task 4.1: Throttle Frontend Refresh In Tick Path

- **Location**: `HFT_Grid_AI.mq5`, `services/frontend/runtime_guard.mqh`, `services/frontend/execution_visualization.mqh`, `services/frontend/lightweight_status_ui.mqh`
- **Description**: Add a cheap frontend refresh throttle for chart work while preserving immediate refresh on init, chart events, and important state transitions where already explicit.
- **Dependencies**: Sprints 1-3.
- **Acceptance Criteria**:
  - Non-visual tester mode still skips chart work.
  - Visual/live refresh frequency is bounded.
  - Chart event handling can still force a refresh.
  - Trading decisions do not depend on frontend state.
- **Validation**:
  - `rg "FrontendChartWorkEnabled|FrontendSkippingChartWork|RefreshExecutionVisualization|ChartRedraw|MQL_VISUAL_MODE|MQL_TESTER" HFT_Grid_AI.mq5 services/frontend`

### Task 4.2: Final Performance Source Sweep

- **Location**: Active production source.
- **Description**: Search for known hot-path risks and confirm retained occurrences are intentional.
- **Dependencies**: Sprints 1-3 and Task 4.1.
- **Acceptance Criteria**:
  - `iATR` creation is cached.
  - Stoch Structure handles have release path.
  - `CopyBuffer` depth is bounded.
  - Full position scans are fallback-only.
  - Logging/frontend work remains gated.
  - No custom tests, scripts, harnesses, or CI were added.
- **Validation**:
  ```powershell
  rg "iATR|IndicatorRelease|CopyBuffer|4320|PositionsTotal|PositionGetTicket|ArrayResize|AppendFileLog|RefreshExecutionVisualization" services HFT_Grid_AI.mq5
  rg "run_mql5_tests|TEST_PASS|TEST_FAIL|harness" services HFT_Grid_AI.mq5
  git diff --check
  ```

### Task 4.3: Run Portable/Headless Compile

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile once after all Phase 7 code and docs edits.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Compile reports `0 errors, 0 warnings`.
  - No custom tests or harnesses are run.
- **Validation**:
  ```powershell
  $mt5Root = "C:\Program Files\MetaTrader 5-1"
  $metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
  $entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
  $logDir = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile"
  $log = Join-Path $logDir "phase-07-build.log"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  if(Test-Path $log) { Remove-Item -LiteralPath $log -Force }
  $argString = "/portable /s /compile:`"$entrypoint`" /log:`"$log`""
  $proc = Start-Process -FilePath $metaeditor -ArgumentList $argString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.4: Fallback Compile Only If Evidence Is Missing Or Fails

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run normal MetaEditor compile only if portable compile fails or does not produce usable evidence.
- **Dependencies**: Task 4.3.
- **Acceptance Criteria**:
  - Fallback reason is documented.
  - Fallback result is parsed for warnings/errors.
- **Validation**:
  ```powershell
  $fallbackLog = Join-Path $logDir "phase-07-build-fallback.log"
  $fallbackArgString = "/s /compile:`"$entrypoint`" /log:`"$fallbackLog`""
  $fallbackProc = Start-Process -FilePath $metaeditor -ArgumentList $fallbackArgString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.5: Record Phase 7 Result

- **Location**: `ROADMAP.md`, `docs/architecture/execution-foundation.md`, `docs/plans/phase-07-real-tick-performance-plan.md`
- **Description**: Record status, compile command, log/evidence path, process exit code, and result line.
- **Dependencies**: Task 4.3 or 4.4.
- **Acceptance Criteria**:
  - Phase 7 status is documented.
  - Compile result is documented.
  - Architecture doc reflects performance boundaries now implemented.
  - Working tree is clean after final commit.
- **Validation**:
  - `git status --short`

## Phase 7 Acceptance Criteria

- Indicator handles are initialized, reused, and released deterministically.
- ATR range mode no longer creates/releases an indicator handle inside range resolution.
- Stoch Structure buffer copies are bounded by needed depth rather than a fixed full-session depth.
- Per-tick work is bounded and easy to inspect.
- Position scans are ticket-first and fallback-only.
- Logging is quiet by default and file/debug logging remains gated.
- Chart/frontend updates are skipped in non-visual tester mode and throttled elsewhere.
- Broker/risk/session/license/daily-signal safeguards are not weakened.
- No custom tests, scripts, harnesses, or CI are added.
- `HFT_Grid_AI.mq5` compiles with `0 errors, 0 warnings`.

## Validation Strategy

Use static validation per sprint:

```powershell
rg "iATR|IndicatorRelease|ResolveExecutionAtrHandle|Release.*Indicator" services HFT_Grid_AI.mq5
rg "CopyBuffer|4320|Resolve.*Depth|DetectMarketExtrema" services/indicators services/trading_signals
rg "PositionsTotal|PositionGetTicket|PositionSelectByTicket|FindBrokerPosition" services/trading_signals
rg "Enable_File_Logs|AppendFileLog|ExecutionShouldLogChangedState|ArrayResize" services/trading_signals services/frontend services/utils
rg "FrontendChartWorkEnabled|RefreshExecutionVisualization|ChartRedraw|MQL_TESTER|MQL_VISUAL_MODE" HFT_Grid_AI.mq5 services/frontend
git diff --check
git status --short
```

Run the MT5 compile gate once after all Phase 7 code and docs edits are complete. Do not run custom MQL5 tests.

## Potential Risks And Gotchas

- Cached indicator handles can go stale if timeframe, symbol, or period changes. Cache keys must include all three and release stale handles.
- Releasing Stoch Structure handles too early would break signal detection. Release only during explicit reload or `OnDeinit()`.
- Reducing structure copy depth can change signals if the first valid extrema pair sits deeper than the new window. Use a conservative bounded window with a cap, not an aggressive tiny buffer.
- Moving price/time calls behind cheap checks can subtly alter initial peak/bottom detection. Preserve the initial range tracking logic.
- Position scan reduction must not skip reconciliation after broker/manual close events. Ticket-first is correct, but stale tickets still need fallback or deterministic completion.
- Throttled frontend refresh can make visual labels lag. Keep chart events and explicit init/deinit refresh immediate.
- File logging changes must not hide critical order or protection failures. Only reduce debug/query churn.
- Performance work can accidentally weaken safety guards by caching dynamic broker facts too long. Keep broker constraints refresh-bounded and fail-closed.
- MetaEditor may return process exit code `1` even when the log reports `0 errors, 0 warnings`; record both and treat the explicit log result as the compile source of truth.

## Rollback Plan

- Revert sprint commits in reverse order.
- If ATR cache causes invalid handle behavior, revert Sprint 1 and restore per-call ATR creation temporarily.
- If bounded structure copies alter signals too aggressively, revert Sprint 2 or increase the copy-depth resolver limits before retrying.
- If broker reconciliation misses manual close events, revert Sprint 3 and keep Phase 6 ticket/comment reconciliation until a narrower optimization is prepared.
- If frontend throttling hides important visual state, revert Task 4.1 while keeping non-frontend performance improvements.
- If compile fails after include changes, check aggregator order first, then missing forward dependencies and deinit release helper declarations.
