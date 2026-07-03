# Plan: Deterministic MA Stoch Strategies

**Generated**: 2026-07-03
**Estimated Complexity**: High
**Risk Level**: High for execution lifecycle and broker reconciliation; Critical where license, protection, margin, magic-number scope, or broker position ownership is touched.

## Overview

Implement three deterministic, independently activatable strategies on top of the current execution foundation.

The new strategy model replaces the current single strategy-context foundation with three fixed strategy variants:

| Strategy | Input | Base TF | Base MA Logic Delay | Macro TF | Macro MA Logic Delay |
| --- | --- | --- | --- | --- | --- |
| S1 | `Enable_Strategy_1` | `PERIOD_M1` | 3 bars | `PERIOD_M3` | 1 closed bar |
| S2 | `Enable_Strategy_2` | `PERIOD_M1` | 5 bars | `PERIOD_M5` | 1 closed bar |
| S3 | `Enable_Strategy_3` | `PERIOD_M1` | 10 bars | `PERIOD_M10` | 1 closed bar |

All strategies use:

- SMA 21 on close price for logic.
- Stoch Structure `k=5`, `d=3`, `slow=3`, `close_close` on `PERIOD_M1`.
- Current/provisional Stoch Structure extremum slot `0` as the setup source of truth.
- Live `close_0` on every tick for entry and strategy SL checks.
- Broker-side bid/ask for TP and real close execution parity.
- Global risk/lot/protection/session/license settings.
- Independent candidate and lifecycle identity by `strategy_id + direction + source_slot + extremum_time + extremum_type + extremum_price`.

The implementation should be completed one sprint at a time. Each sprint must be validated before moving to the next sprint.

## Locked Product Decisions

- Only hedging accounts are supported for this strategy stack. Netting support is out of scope.
- Strategy inputs are limited to strategy enable toggles. Lot sizing, TP percent, protection, session, direction, daily limits, and debug settings remain global.
- Entry and SL use live `close_0` on every tick.
- Faithful backtests should use "Every tick based on real ticks" or equivalent tick modeling.
- TP is evaluated using broker-side bid/ask, not raw `close_0`.
- Macro confirmation is rechecked immediately before entry activation.
- Pending candidates expire when the current/provisional M1 Stoch Structure source identity changes before entry.
- S1, S2, and S3 may all open independent signals from the same extremum when enabled and broker gates pass.
- Aggressive cleanup is allowed for inputs and code paths not aligned with the deterministic strategy model.
- Shifted MA visualization is required in this implementation plan.
- Strategy-specific magic number derivation is preferred if the license contract allows it; otherwise, strategy identity must be preserved through broker comments and local lifecycle state.

## Strategy Contract

### Logic MA Policy

Trading logic must use unshifted MA handles:

```text
iMA(_Symbol, timeframe, 21, 0, MODE_SMA, PRICE_CLOSE)
```

The strategy delay is applied explicitly through buffer indexes.

Visual-only chart overlays may use shifted MA handles:

```text
iMA(_Symbol, timeframe, 21, visual_shift, MODE_SMA, PRICE_CLOSE)
```

Trading logic must not depend on `CopyBuffer` negative offsets or shifted-indicator buffer alignment.

### M1 Setup Rules

Use the current/provisional M1 Stoch Structure extremum from slot `0`.

For a peak:

```text
ext_shift = iBarShift(_Symbol, PERIOD_M1, current_peak_time, false)
ma_now    = MA_M1[ext_shift + strategy_delay]
ma_prev   = MA_M1[ext_shift + strategy_delay + 1]

sell_setup = current_peak.high > ma_now && ma_now < ma_prev
```

For a bottom:

```text
ext_shift = iBarShift(_Symbol, PERIOD_M1, current_bottom_time, false)
ma_now    = MA_M1[ext_shift + strategy_delay]
ma_prev   = MA_M1[ext_shift + strategy_delay + 1]

buy_setup = current_bottom.low < ma_now && ma_now > ma_prev
```

The M1 setup is the structural source of truth. Do not add a second M1 confirmation such as `MA_M1[delay]` versus `MA_M1[delay + 1]` unless it is the same calculation produced by the current extremum shift.

### Macro Confirmation Rules

Macro confirmation is independent from the M1 extremum shift.

For S1:

```text
buy_macro  = MA_M3[1] > MA_M3[2]
sell_macro = MA_M3[1] < MA_M3[2]
```

For S2:

```text
buy_macro  = MA_M5[1] > MA_M5[2]
sell_macro = MA_M5[1] < MA_M5[2]
```

For S3:

```text
buy_macro  = MA_M10[1] > MA_M10[2]
sell_macro = MA_M10[1] < MA_M10[2]
```

Macro confirmation must be rechecked before activating entry. If it no longer matches the candidate direction, the candidate should close/expire without sending a trade.

### Entry Rules

Entry is based on live M1 `close_0`:

```text
buy_entry  = close_0 > high_1
sell_entry = close_0 < low_1
```

Entry activation still passes through broker-aware local execution gates before any broker trade is sent.

### Strategy SL Rules

SL is a local strategy exit, not necessarily a native broker stop.

```text
buy_sl  = close_0 < current_bottom.low
sell_sl = close_0 > current_peak.high
```

The source extremum price used for SL must be captured when the candidate is created and must not drift to a later structure.

### TP Rules

TP uses the current broker-side exit price and the configured global `TP_Percent`:

```text
risk_distance = abs(real_or_estimated_entry_price - source_extremum_price)
tp_distance   = risk_distance * (TP_Percent / 100.0)
```

For buys, TP is above entry and evaluated against the bid side. For sells, TP is below entry and evaluated against the ask side.

After broker fill, TP geometry should reconcile to broker-confirmed entry price where possible while preserving the configured `TP_Percent` risk multiple.

## Prerequisites

- MetaTrader 5 root remains `C:\Program Files\MetaTrader 5-1`.
- Main entrypoint remains `HFT_Grid_AI.mq5`.
- Include pipeline remains ordered through:

```text
services/license_service_setup.mqh
services/trading_tools.mqh
services/trading_management.mqh
services/trading_management_strategies.mqh
services/trading_signals.mqh
services/frontend.mqh
```

- No custom MQL5 test harness is reintroduced.
- Implementation sprints compile at sprint end using MetaEditor portable/headless first.
- Warnings and errors are sprint failures unless a temporary exception is explicitly documented.

## Sprint 1: Strategy Contract And Input Surface

**Goal**: Replace the foundation input surface with the deterministic strategy contract and remove incompatible legacy strategy settings.
**Commit**: `refactor: define deterministic strategy inputs`
**Demo/Validation**:
- Inspect MT5 EA inputs and confirm only aligned strategy/risk controls remain.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 1.1: Add Strategy Identity Enums And Constants

- **Location**:
  - `services/core/enums.mqh`
  - New or existing strategy config include under `services/trading_management/` or `services/trading_signals/`
- **Description**: Define deterministic strategy identifiers and fixed descriptors for S1, S2, S3.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Strategy IDs are explicit and stable.
  - S1/S2/S3 map to M1 delay 3/5/10 and macro M3/M5/M10.
  - No removed legacy public enum prefixes are reintroduced.
- **Validation**:
  - Static grep for strategy IDs and descriptor usage.

### Task 1.2: Replace Strategy Inputs

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Add `Enable_Strategy_1`, `Enable_Strategy_2`, and `Enable_Strategy_3`. Remove inputs that are no longer aligned with the deterministic strategy model.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Strategy toggles exist and default to the desired operational default.
  - `Strategy_Timeframe`, `Stoch_Structure_Period_Type`, `Strategy_Range_Mode`, `Strategy_Range_Points`, and obsolete Strategy Context inputs are removed or replaced.
  - Risk, license, session, spread, protection, direction, lot, `TP_Percent`, daily limit, and debug settings remain where still applicable.
- **Validation**:
  - Static grep confirms removed public inputs are not active.
  - MetaEditor compile at sprint end.

### Task 1.3: Remove Or Isolate Range/Fibonacci Strategy Surface

- **Location**:
  - `services/trading_management/structure_fibonacci_levels.mqh`
  - `services/trading_management/strategy_structure_context.mqh`
  - `services/trading_signals/market_signal_filters.mqh`
  - `services/trading_signals/execution_leg_helpers.mqh`
  - `services/trading_signals/execution_planner.mqh`
- **Description**: Delete or isolate code paths that only exist for the old range/Fibonacci strategy behavior and are not required by the new strategy.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - The execution foundation no longer plans entries from Fibonacci structure bands.
  - No deprecated compatibility aliases are kept.
  - Broker guardrails remain intact.
- **Validation**:
  - Static grep for removed input names and old range-only functions.
  - Compile at sprint end.

### Task 1.4: Add Hedging-Only Runtime Guard

- **Location**:
  - `HFT_Grid_AI.mq5`
  - Existing runtime guard or trading management module
- **Description**: Block initialization or signal activation when the account is not hedging.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Netting accounts fail closed before strategy signals can open broker positions.
  - The block reason is visible in logs/frontend status when practical.
- **Validation**:
  - Compile.
  - Manual review of fail-closed path.

## Sprint 2: Strategy State, Identity, And Broker Scope

**Goal**: Make S1/S2/S3 independent through signal identity, lifecycle state, dedupe, broker comments, and magic scope.
**Commit**: `feat: add deterministic strategy lifecycle identity`
**Demo/Validation**:
- With all strategies enabled, static review confirms candidates can coexist by strategy ID.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 2.1: Extend SignalParams With Strategy Identity

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Add fields for `strategy_id`, `strategy_label`, base timeframe, macro timeframe, base delay, macro delay, source extremum time, source extremum type, source extremum price, raw entry trigger, raw stop anchor, and TP/risk geometry.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Constructors and copy constructors preserve all new fields.
  - No aggregate initialization is used for structs with constructors.
  - Existing arrays can still copy/assign `SignalParams`.
- **Validation**:
  - Compile.
  - Static review of constructors.

### Task 2.2: Dedupe By Strategy And Extremum

- **Location**:
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
- **Description**: Replace context-only dedupe with `strategy_id + direction + source_extremum_time`.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - S1/S2/S3 can each create a signal from the same extremum.
  - Duplicate signals for the same strategy/direction/extremum are blocked.
  - `Signal_Concurrency_Mode` still applies globally when configured.
- **Validation**:
  - Static review of dedupe paths.
  - Compile.

### Task 2.3: Strategy-Aware Broker Comments

- **Location**:
  - `services/trading_signals/execution_leg_helpers.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
- **Description**: Include strategy label or ID in execution comments and reconciliation fallback.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Comments cannot collide between S1/S2/S3 on the same direction/time/level.
  - Reconciliation remains scoped by symbol, direction, magic number, and comment where required.
- **Validation**:
  - Static review of comment format.
  - Compile.

### Task 2.4: Derive Strategy Magic Numbers When License Allows

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/license_service_setup.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
- **Description**: Investigate the license magic-number contract. If allowed, derive per-strategy magic numbers from the verified base magic. If not allowed, retain base magic and rely on strategy comments plus local identity.
- **Dependencies**: Task 2.3.
- **Acceptance Criteria**:
  - The plan implementation documents the chosen magic strategy in code comments or docs.
  - License guard behavior remains fail-closed.
  - Reconciliation remains deterministic.
- **Validation**:
  - Static review of license and magic paths.
  - Compile.

## Sprint 3: Indicator Cache And Shifted Visualization

**Goal**: Add efficient persistent indicator handles for strategy logic and chart visualization.
**Commit**: `feat: cache deterministic strategy indicators`
**Demo/Validation**:
- All required handles load once at init and release on deinit.
- Visual shifted MA lines are available without affecting trading logic.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 3.1: Load Shared Stoch Structure M1

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
- **Description**: Replace configurable Stoch Structure loading with fixed M1 `k=5`, `d=3`, `slow=3`, `STO_CLOSECLOSE`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Stoch Structure M1 is loaded once.
  - The structure snapshot is shared by all strategies.
  - Indicator release is deterministic.
- **Validation**:
  - Compile.
  - Static review for per-tick handle creation.

### Task 3.2: Add Raw MA Logic Handles

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - New strategy indicator cache helper if useful
- **Description**: Add persistent unshifted SMA 21 handles for M1, M3, M5, and M10.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Handles use `ma_shift=0`.
  - Copy depth is bounded to the maximum needed for setup and macro confirmation.
  - No raw MA handle is created on tick paths.
- **Validation**:
  - Static grep for `iMA`.
  - Compile.

### Task 3.3: Add Shifted Visual MA Handles Or Chart Objects

- **Location**:
  - `services/frontend/execution_visualization.mqh`
  - `services/frontend/execution_visual_lines.mqh`
  - `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Show the shifted MA view for S1/S2/S3 without using shifted buffers for trading logic.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - S1 visual MA reflects delay 3 on M1.
  - S2 visual MA reflects delay 5 on M1.
  - S3 visual MA reflects delay 10 on M1.
  - Macro visual MA lines may show shift 1 when practical.
  - Visual failures do not block trading logic unless handle creation for required logic indicators fails.
- **Validation**:
  - Compile.
  - Visual smoke check in MT5 after implementation.

### Task 3.4: Add Efficient Buffer Access Helpers

- **Location**:
  - `services/trading_signals/market_signal_indicators.mqh`
  - New strategy indicator helper if useful
- **Description**: Add helpers to fetch only the required MA buffer windows and M1 rates.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - M1 setup helper can resolve `MA_M1[ext_shift + delay]` and `[ext_shift + delay + 1]`.
  - Macro helper can resolve `[1]` and `[2]`.
  - `CopyRates`/`CopyBuffer` calls are bounded and checked.
  - No full-history scans exist on tick paths.
- **Validation**:
  - Static review of copy depths and array bounds.
  - Compile.

## Sprint 4: Deterministic Candidate Detection

**Goal**: Produce deterministic candidates from confirmed M1 structure, base MA delayed slope, and macro confirmation.
**Commit**: `feat: detect deterministic ma stoch candidates`
**Demo/Validation**:
- In logs/debug mode, candidates identify strategy, direction, extremum, delayed MA values, macro confirmation, and entry trigger.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 4.1: Extract Latest Confirmed M1 Extremum

- **Location**:
  - `services/indicators/extrema_detector.mqh`
  - `services/indicators/stochastic_market_indicator.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
- **Description**: Provide a cheap, explicit helper for latest confirmed peak/bottom data from the M1 Stoch Structure snapshot.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - The helper returns extremum type, time, high/low anchor price, and validity.
  - Provisional/live unconfirmed extrema are not used.
  - The result is stable across all strategies for the same M1 bar.
- **Validation**:
  - Static review of structure slots used.
  - Compile.

### Task 4.2: Implement Base M1 Setup Evaluation

- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
  - New deterministic strategy filter helper if useful
- **Description**: Evaluate peak/bottom relationship against delayed M1 SMA slope for each enabled strategy.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Sell setup: `peak.high > MA_M1[ext_shift + delay]` and delayed slope down.
  - Buy setup: `bottom.low < MA_M1[ext_shift + delay]` and delayed slope up.
  - Invalid shifts, missing MA data, or insufficient bars fail closed.
- **Validation**:
  - Compile.
  - Debug log sample in tester or visual run after implementation.

### Task 4.3: Implement Macro Confirmation

- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
  - Strategy indicator helper
- **Description**: Evaluate macro SMA 21 `[1]` versus `[2]` for each strategy.
- **Dependencies**: Task 3.4.
- **Acceptance Criteria**:
  - S1 uses M3, S2 uses M5, S3 uses M10.
  - Macro confirmation uses closed bars only.
  - The confirmation can be reused at candidate creation and rechecked before entry activation.
- **Validation**:
  - Compile.
  - Static review of buffer indexes.

### Task 4.4: Create Strategy Candidates On New M1 Structure State

- **Location**:
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/market_signal_state.mqh`
- **Description**: Replace context evaluation with deterministic strategy iteration over enabled S1/S2/S3.
- **Dependencies**: Tasks 4.1, 4.2, 4.3.
- **Acceptance Criteria**:
  - Candidate creation runs on new relevant M1 bar/structure state, not every tick.
  - Candidate stores source extremum and raw entry trigger (`high_1` for buy, `low_1` for sell).
  - Candidate stores stop anchor from source extremum.
  - Candidate is deduped by strategy/direction/extremum.
  - Daily signal limits and direction mode are applied before activation or at candidate creation consistently.
- **Validation**:
  - Compile.
  - Debug log confirms no candidate churn on every tick.

### Task 4.5: Expire Candidates On Any New Confirmed Extremum

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/market_signal_state.mqh`
- **Description**: Close pending non-filled candidates when a newer confirmed M1 Stoch Structure extremum appears.
- **Dependencies**: Task 4.4.
- **Acceptance Criteria**:
  - Pending candidates expire without broker action.
  - Active broker positions are not closed only because a new extremum appears.
  - Expiration is logged behind debug settings.
- **Validation**:
  - Compile.
  - Static review of pending versus active status checks.

## Sprint 5: Entry, SL, TP, And Broker-Aware Lifecycle

**Goal**: Activate candidates and manage exits with the new deterministic rules while preserving broker-aware gates and reconciliation.
**Commit**: `feat: execute deterministic strategy lifecycle`
**Demo/Validation**:
- Tester visual or log run shows setup, pending candidate, broker-aware activation, active position, TP or SL close, and cleanup.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 5.1: Add Raw Close Entry Trigger

- **Location**:
  - `services/trading_signals/execution_lifecycle.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_leg_helpers.mqh`
- **Description**: Activate first entry when live M1 `close_0` crosses the stored trigger.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Buy activates on `close_0 > stored_high_1`.
  - Sell activates on `close_0 < stored_low_1`.
  - Macro confirmation is rechecked immediately before activation.
  - If macro confirmation fails, the candidate expires without broker send.
  - Broker eligibility still runs before broker send.
- **Validation**:
  - Compile.
  - Static review of broker guardrail call order.

### Task 5.2: Add Strategy SL By Source Extremum

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Close active positions when live `close_0` invalidates the source extremum.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Buy SL: `close_0 < source_bottom.low`.
  - Sell SL: `close_0 > source_peak.high`.
  - Close uses scoped broker position closure and does not overwrite broker facts.
  - Failed close attempts do not mark the signal complete until reconciliation confirms closure.
- **Validation**:
  - Compile.
  - Static review of position-close retcode handling.

### Task 5.3: Add TP Percent Risk Geometry

- **Location**:
  - `services/trading_signals/execution_planner.mqh`
  - `services/trading_signals/execution_leg_helpers.mqh`
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Compute TP from source risk distance and global `TP_Percent`, then evaluate TP by broker-side bid/ask.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - TP respects `TP_Percent / 100.0` risk multiple.
  - TP recalculates from broker-confirmed entry price after fill when available.
  - Broker stops/freeze/spread constraints are checked before activation.
  - If required broker-safe geometry cannot be maintained, activation is blocked.
- **Validation**:
  - Compile.
  - Static review of bid/ask side selection.

### Task 5.4: Preserve Existing Risk And Protection Gates

- **Location**:
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/session_time_filter_manager.mqh`
  - `services/trading_signals/market_status_controller.mqh`
- **Description**: Confirm the new lifecycle still passes through license, spread, market status, session, protection, volume, and margin checks.
- **Dependencies**: Tasks 5.1, 5.2, 5.3.
- **Acceptance Criteria**:
  - No strategy detector can open/close broker positions directly.
  - Local broker-aware eligibility remains the final gate before send.
  - Symbol and magic/comment scope are preserved for close and reconciliation.
- **Validation**:
  - Static guardrail audit.
  - Compile.

### Task 5.5: Remove Grid/Deep-Level Behavior If Obsolete

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_leg_helpers.mqh`
  - `services/trading_signals/execution_planner.mqh`
  - `services/frontend/execution_visualization.mqh`
- **Description**: Delete remaining multi-level grid/range behavior if it no longer matches the single deterministic entry lifecycle.
- **Dependencies**: Tasks 5.1, 5.2, 5.3.
- **Acceptance Criteria**:
  - Execution legs represent the needed lifecycle only.
  - No unused deep-entry/grid inputs or paths remain.
  - Frontend does not display obsolete levels.
- **Validation**:
  - Static grep for removed concepts.
  - Compile.

## Sprint 6: Tester Performance And Telemetry

**Goal**: Keep "Every tick based on real ticks" backtests efficient while preserving deterministic tick-level entry/SL behavior.
**Commit**: `perf: optimize deterministic strategy tester path`
**Demo/Validation**:
- Backtest logs show bounded strategy evaluation and no per-tick indicator handle churn.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 6.1: Gate Expensive Work To New Bars And Structure Changes

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/market_signal_state.mqh`
- **Description**: Evaluate Stoch Structure and setup creation only when the relevant M1 state changes.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Stoch Structure snapshots are not copied on every tick when no new M1 bar/structure state exists.
  - Tick path only checks live entry/SL/TP for existing pending/active candidates.
  - Macro buffers are refreshed only when their closed-bar state may have changed.
- **Validation**:
  - Static review of `CopyBuffer` placement.
  - Debug log sample with `Enable_Logs=true`.

### Task 6.2: Cache M1 Rates Per Tick

- **Location**:
  - `services/trading_signals/market_signal_indicators.mqh`
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Fetch `close_0`, `high_1`, and `low_1` once per tick when needed.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Pending/active strategy lifecycle reuses one M1 rates snapshot per tick.
  - Missing rates fail closed without repeated logs.
  - Array bounds are checked.
- **Validation**:
  - Compile.
  - Static review of tick-path market data calls.

### Task 6.3: Compact Strategy Diagnostics

- **Location**:
  - `services/trading_signals/execution_logging.mqh`
  - Frontend lightweight UI if useful
- **Description**: Add low-noise debug events for candidate creation, macro invalidation, entry activation, SL, TP, broker block, and expiration.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Logs are gated by debug/log inputs.
  - Repeated per-tick rejections do not spam logs.
  - Diagnostic records include strategy ID and source extremum time.
- **Validation**:
  - Compile.
  - Debug log smoke run.

### Task 6.4: Final Compile And Tester Smoke Procedure

- **Location**:
  - `logs/compile/`
  - `README.md` or plan notes if procedure documentation is needed
- **Description**: Run the project compile command and define a short Strategy Tester smoke procedure.
- **Dependencies**: Tasks 6.1, 6.2, 6.3.
- **Acceptance Criteria**:
  - Portable/headless compile returns 0 errors and 0 warnings.
  - Tester smoke run verifies all three strategies can initialize.
  - Any tester limitations are documented.
- **Validation**:
  - Preferred command:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\deterministic-strategies.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

## Sprint 7: Strategy-Scoped Visual Charts

**Goal**: Make human-in-the-loop validation deterministic by showing only the visual indicators that belong to enabled strategies, and by opening/reusing macro timeframe charts for each enabled strategy's macro confirmation.
**Commit**: `feat: scope deterministic strategy visuals`
**Demo/Validation**:
- With only `Enable_Strategy_1=true`, the active M1 chart shows only the S1 shifted M1 MA, and a macro M3 chart shows only the S1 macro MA shifted by 1.
- With S1 and S2 enabled, the M1 chart shows only S1/S2 shifted M1 MAs, and M3/M5 macro charts are opened/reused with their shifted macro MAs.
- With all strategies enabled, the M1 chart shows S1/S2/S3 shifted M1 MAs, and M3/M5/M10 macro charts are opened/reused.
- Disabled strategy visuals are absent.
- Compile at sprint end with 0 errors and 0 warnings.

### Research Notes

- `ChartIndicatorAdd` requires the indicator handle and destination chart to have the same symbol and timeframe; otherwise visual macro indicators should not be attached to the M1 chart.
- `ChartOpen` can open a chart for a symbol/timeframe and returns the chart ID or 0 on failure.
- `ChartSetSymbolPeriod` is asynchronous; if reused charts are retargeted, indicator attachment should account for queued chart changes.

### Task 7.1: Scope M1 Shifted MA Visual Handles By Enabled Strategy

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - Strategy visual helper module if useful
- **Description**: Load/add M1 shifted visual MA handles only for enabled strategies.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - S1 visual M1 MA shift 3 is loaded only when `Enable_Strategy_1` is true.
  - S2 visual M1 MA shift 5 is loaded only when `Enable_Strategy_2` is true.
  - S3 visual M1 MA shift 10 is loaded only when `Enable_Strategy_3` is true.
  - Logic MA handles remain unaffected and still load for all required timeframes.
  - Disabled strategy visual handles are not added to the current chart.
- **Validation**:
  - Static review of handle loading conditions.
  - Compile.
  - Human chart check with one, two, and three enabled strategies.

### Task 7.2: Add Macro Chart Visual Runtime State

- **Location**:
  - New visual state helper under `services/frontend/` or `services/trading_management/`
  - `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Track EA-opened macro chart IDs and strategy-specific macro visual handles.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - Macro chart state tracks strategy ID, macro timeframe, chart ID, indicator handle, and ownership.
  - EA only closes charts it opened itself, not arbitrary user charts.
  - State resets safely on `OnDeinit`.
  - Missing or closed charts fail gracefully without affecting trading logic.
- **Validation**:
  - Compile.
  - Manual chart close/reload smoke check.

### Task 7.3: Open Or Reuse Macro Timeframe Charts For Enabled Strategies

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - Optional chart helper under `services/frontend/`
- **Description**: For each enabled strategy, open or reuse the correct macro timeframe chart and attach its shifted macro MA.
- **Dependencies**: Task 7.2.
- **Acceptance Criteria**:
  - S1 opens/reuses M3 and attaches SMA 21 shift 1 on M3.
  - S2 opens/reuses M5 and attaches SMA 21 shift 1 on M5.
  - S3 opens/reuses M10 and attaches SMA 21 shift 1 on M10.
  - Chart/indicator symbol and timeframe match before `ChartIndicatorAdd`.
  - Repeated init/deinit cycles do not create duplicate macro charts beyond one chart per enabled macro timeframe owned by this EA session.
  - Failures log behind existing debug/log settings and do not block strategy execution unless a required logic handle fails.
- **Validation**:
  - Compile.
  - Manual MT5 check for S1-only, S2-only, S3-only, S1+S2, and all enabled.

### Task 7.4: Remove Visual Noise From Disabled Strategies

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/frontend/execution_visualization.mqh` if chart objects are also affected
- **Description**: Ensure inactive strategies do not leave stale MA visual handles, chart objects, or macro charts after reinitialization.
- **Dependencies**: Tasks 7.1, 7.2, 7.3.
- **Acceptance Criteria**:
  - Changing enabled strategy inputs and reinitializing removes old EA-owned visual artifacts.
  - M1 chart does not show inactive strategy shifted MAs.
  - Macro charts for inactive strategies are closed only if the EA opened them; user charts are not closed.
  - Trading logic remains independent from visual cleanup.
- **Validation**:
  - Compile.
  - Human-in-the-loop input toggle check.

### Task 7.5: Add Visual Validation Notes

- **Location**:
  - `AGENTS.md`
  - `docs/plans/deterministic-ma-stoch-strategies-plan.md`
  - Optional README section if product-facing docs need it
- **Description**: Document the expected visual validation setup without adding MQL5 tests or CI.
- **Dependencies**: Tasks 7.1-7.4.
- **Acceptance Criteria**:
  - Documentation says visual validation is human-in-the-loop.
  - Documentation states that only enabled strategy visuals should be visible.
  - Documentation states that macro MA visual charts are validation aids and must not affect trading decisions.
- **Validation**:
  - Static doc review.

## Sprint 8: Hide Logical MA Tester Noise

**Goal**: Keep the Strategy Tester chart deterministic by hiding logic-only `shift=0` MA handles while leaving strategy-scoped shifted visual MAs visible.
**Commit**: `fix: hide deterministic logic ma tester visuals`
**Demo/Validation**:
- With only `Enable_Strategy_1=true`, the visual tester M1 chart shows only the S1 shifted M1 MA, not the logic `shift=0` MA.
- With S1/S2/S3 combinations, only enabled shifted visual MAs and their linked macro charts remain visible.
- Signal calculations continue to use `shift=0` logic handles.
- Compile at sprint end with 0 errors and 0 warnings.

### Research Notes

- `TesterHideIndicators()` controls whether indicators created by an EA are displayed during Strategy Tester runs.
- The visibility mode applies to indicators created after the call, so logic handles must be created while the tester hide mode is enabled and visual handles must be created after visibility is restored.
- This does not replace logic handles with shifted visual handles; the chart remains validation-only.

### Task 8.1: Hide Logic MA Handles During Tester Creation

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Wrap `LoadDeterministicMaLogicIndicators()` handle creation with tester-only hidden indicator mode.
- **Dependencies**: Sprint 7.
- **Acceptance Criteria**:
  - `ExtDeterministicMaLogicHandles` still loads M1/M3/M5/M10 with `shift=0`.
  - Logic MA handles are hidden in Strategy Tester visual charts.
  - Hide mode is restored before visual shifted handles are created.
  - Live/non-tester behavior remains unaffected.
- **Validation**:
  - Static review of handle creation order.
  - Compile.
  - Human-in-the-loop visual tester check.

### Task 8.2: Document Tester Visual Source Boundaries

- **Location**:
  - `AGENTS.md`
  - `docs/plans/deterministic-ma-stoch-strategies-plan.md`
- **Description**: Document that hidden logic handles remain the signal source and shifted handles remain visual-only.
- **Dependencies**: Task 8.1.
- **Acceptance Criteria**:
  - Documentation states logic `shift=0` MAs are hidden in tester visual mode.
  - Documentation states shifted MA handles must not become the signal source.
- **Validation**:
  - Static doc review.

## Sprint 9: Deterministic Extremum Telemetry

**Goal**: Confirm the source-extremum mismatch with low-noise `query_debug.txt` telemetry before changing signal behavior.
**Commit**: `chore: add deterministic extremum telemetry`
**Demo/Validation**:
- `query_debug.txt` records the selected deterministic source slot, type, time, price, high, and low for every deterministic candidate/event.
- `query_debug.txt` records a changed-state audit comparing current/provisional slot `0` with confirmed slot `1`.
- No signal selection behavior changes in this sprint.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 9.1: Add Source Slot Metadata To Deterministic Snapshots

- **Location**:
  - `services/trading_signals/market_signal_indicators.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Carry deterministic source slot metadata from structure snapshot selection into signal params.
- **Dependencies**: Sprint 8.
- **Acceptance Criteria**:
  - Deterministic snapshots include `source_slot` and confirmation metadata.
  - Signal params persist source slot metadata for lifecycle/event logging.
  - Existing confirmed-slot behavior remains unchanged.
- **Validation**:
  - Static review.
  - Compile.

### Task 9.2: Emit Source Audit And Candidate Telemetry

- **Location**:
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/execution_logging.mqh`
- **Description**: Log selected/current/confirmed extrema and candidate MA context into the existing query debug file.
- **Dependencies**: Task 9.1.
- **Acceptance Criteria**:
  - `DETERMINISTIC_SOURCE_AUDIT` shows selected slot, current slot, and confirmed slot.
  - `DETERMINISTIC_CANDIDATE` shows direction, strategy, source slot/type/time/price, base MA pair, macro MA pair, trigger, and stop.
  - Lifecycle events include source slot/type/time/price and raw trigger/stop.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop tester run with `Enable_File_Logs=true`.

## Sprint 10: Current Extremum Source Of Truth

**Goal**: Make the deterministic strategy use the current/provisional Stoch Structure extremum as the signal source of truth instead of the latest confirmed historical extremum.
**Commit**: `fix: use current deterministic extremum source`
**Demo/Validation**:
- Sales are only created from current PEAK slot `0` over the delayed M1 MA with bearish base and macro slopes.
- Buys are only created from current BOTTOM slot `0` under the delayed M1 MA with bullish base and macro slopes.
- Pending deterministic signals expire when the current source extremum changes by slot/type/time/price before entry.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 10.1: Switch Deterministic Selection To Current Slot

- **Location**:
  - `services/trading_signals/market_signal_indicators.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
- **Description**: Replace confirmed-slot selection with current/provisional slot `0` selection for deterministic strategies.
- **Dependencies**: Sprint 9.
- **Acceptance Criteria**:
  - Deterministic signal creation selects `os_market_structures[0]`.
  - Logs show `source_slot=0` for new deterministic candidates and lifecycle events.
  - MA evaluation still uses `iBarShift()` on the source extremum time plus strategy delay.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop chart/log comparison.

### Task 10.2: Expire Pending Signals On Current Extremum Change

- **Location**:
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
- **Description**: Close/remove pending deterministic signals without broker exposure when the current source extremum no longer matches their source identity.
- **Dependencies**: Task 10.1.
- **Acceptance Criteria**:
  - Pending signals from stale current extrema are removed before entry.
  - Broker-exposed deterministic signals are not removed by source changes.
  - Source identity compares type, time, and price with symbol-point tolerance.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop tester run with current/confirmed source audit logs.

## Sprint 11: Dynamic Pending Entry Anchor

**Goal**: Keep deterministic SL anchored to the selected Stoch Structure extremum while allowing the pending entry trigger to move to the latest favorable M1 breakout anchor before broker exposure exists.
**Commit**: `fix: refresh deterministic pending entry anchor`
**Status**: Completed on 2026-07-03. Compile passed with 0 errors and 0 warnings; runtime confirmation remains human-in-the-loop through `query_debug.txt`.
**Demo/Validation**:
- Pending deterministic sells keep the PEAK-derived SL immutable and can refresh `raw_trigger` upward from newer M1 `low_1` values that remain below the stop anchor.
- Pending deterministic buys keep the BOTTOM-derived SL immutable and can refresh `raw_trigger` downward from newer M1 `high_1` values that remain above the stop anchor.
- `query_debug.txt` records `DETERMINISTIC_ENTRY_REFRESH` only when the pending trigger changes, including old/new trigger, stop anchor, M1 rates, risk before/after, lot before/after, TP before/after, and refresh reason.
- Broker-exposed legs never refresh their entry trigger.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 11.1: Refresh Pending Entry Trigger Before Activation

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Add a deterministic pending-entry refresh helper that evaluates the latest M1 `high_1`/`low_1` before the live `close_0` breakout check.
- **Dependencies**: Sprint 10.
- **Acceptance Criteria**:
  - Refresh runs only for deterministic `EXECUTION_LEG_PENDING` legs without broker exposure.
  - BEARISH refresh accepts only `low_1 > current_trigger && low_1 < stop_anchor`.
  - BULLISH refresh accepts only `high_1 < current_trigger && high_1 > stop_anchor`.
  - `raw_stop_anchor_price` and source extremum metadata remain unchanged.
- **Validation**:
  - Static review of pending versus active lifecycle checks.
  - Compile.

### Task 11.2: Recompute Pending Risk Geometry On Refresh

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
- **Description**: When the trigger refreshes, recompute the pending leg's entry reference, TP, risk distance, broker-distance-adjusted risk points, base lot, and signal-level execution reference fields.
- **Dependencies**: Task 11.1.
- **Acceptance Criteria**:
  - `signal.raw_entry_trigger_price`, `signal.entry_price`, `signal.execution_entry_reference_price`, `leg.entry_reference_price`, `leg.take_profit_price`, `leg.initial_take_profit_price`, `leg.lot_size`, `leg.initial_lot_size`, `signal.raw_take_profit_price`, and risk-distance fields stay aligned.
  - Existing broker spread/stops/freeze/margin gates remain the final authority before order send.
  - Refresh aborts without mutation if the refreshed trigger cannot produce valid risk, TP, or lot values.
- **Validation**:
  - Static review of all updated fields.
  - Compile.

### Task 11.3: Add Entry Refresh Telemetry

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_logging.mqh`
- **Description**: Emit changed-state query debug telemetry for each accepted pending-entry refresh.
- **Dependencies**: Task 11.2.
- **Acceptance Criteria**:
  - Log label is `DETERMINISTIC_ENTRY_REFRESH`.
  - Log includes strategy, direction, source slot/type/time/price, old trigger, candidate trigger, new trigger, stop, `close_0`, `high_1`, `low_1`, risk before/after, TP before/after, lot before/after, and reason.
  - Repeated ticks with the same refreshed state do not spam the file.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop tester run with `Enable_File_Logs=true`.

## Sprint 12: Deterministic Chart Line Cleanup And Telemetry

**Goal**: Remove stale deterministic signal lines from the chart and make pending-signal expiration visible in `query_debug.txt`.
**Commit**: `fix: clean deterministic chart lines`
**Status**: Completed on 2026-07-03. Compile passed with 0 errors and 0 warnings; runtime confirmation remains human-in-the-loop through chart visual review and `query_debug.txt`.
**Demo/Validation**:
- Expired pending deterministic signals emit `DETERMINISTIC_SIGNAL_EXPIRED` with old and new source-extremum identity.
- Chart level lines are tracked in the visualization cache and deleted when their signal no longer exists.
- Deterministic SL is labeled as the stop/SL anchor instead of being shown as a generic `NEXT` level.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 12.1: Track Execution Level Objects

- **Location**:
  - `services/frontend/execution_visualization.mqh`
  - `services/frontend/execution_visual_lines.mqh`
- **Description**: Use tracked line updates for execution-level chart objects so stale signal objects can be removed by the existing visualization cache.
- **Dependencies**: Sprint 11.
- **Acceptance Criteria**:
  - Entry, TP, SL/stop, and next-level chart object names are pushed into the current visualization object list when visible.
  - Objects absent from the current running signal set are deleted on refresh.
  - Existing `Enable_Chart_Levels=false` cleanup remains intact.
- **Validation**:
  - Static review.
  - Compile.

### Task 12.2: Render Deterministic Stop As SL

- **Location**:
  - `services/frontend/execution_visualization.mqh`
- **Description**: For deterministic signals, draw `raw_stop_anchor_price` as the `STOP`/SL line and suppress the unused `NEXT` line.
- **Dependencies**: Task 12.1.
- **Acceptance Criteria**:
  - Deterministic chart visualization shows entry, SL, and TP without a misleading `NEXT` line.
  - Non-deterministic execution visualization behavior is unchanged.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop visual tester check.

### Task 12.3: Log Pending Source Expiration

- **Location**:
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/execution_logging.mqh`
- **Description**: Log and visually clean pending deterministic signals that are removed when the current source extremum changes before entry.
- **Dependencies**: Task 12.2.
- **Acceptance Criteria**:
  - `DETERMINISTIC_SIGNAL_EXPIRED` includes strategy, direction, old source slot/type/time/price, new source slot/type/time/price, raw trigger, raw stop, and reason.
  - Expired pending signals call chart-level cleanup before removal.
  - Broker-exposed deterministic signals are never removed by this path.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop query debug check with `Enable_File_Logs=true`.

## Sprint 13: Current Delayed Base Slope Confirmation

**Goal**: Require the current M1 MA slope delayed by strategy offset to still confirm direction when a pending deterministic signal is about to execute.
**Commit**: `fix: confirm current delayed base slope`
**Status**: Completed on 2026-07-03. Compile passed with 0 errors and 0 warnings; runtime confirmation remains human-in-the-loop through `query_debug.txt`.
**Demo/Validation**:
- S1 entry requires current `M1_MA[3] > M1_MA[4]` for buys and `M1_MA[3] < M1_MA[4]` for sells.
- S2 entry requires current `M1_MA[5] > M1_MA[6]` for buys and `M1_MA[5] < M1_MA[6]` for sells.
- S3 entry requires current `M1_MA[10] > M1_MA[11]` for buys and `M1_MA[10] < M1_MA[11]` for sells.
- `query_debug.txt` records current base and macro confirmation values before entry, and records `DETERMINISTIC_BASE_EXPIRED` when M1 delayed slope no longer confirms.
- Compile at sprint end with 0 errors and 0 warnings.

### Task 13.1: Add Current Base Slope Helper

- **Location**:
  - `services/trading_signals/market_signal_filters.mqh`
- **Description**: Add a deterministic current-base confirmation helper that uses the strategy delay directly rather than `extremum_shift + delay`.
- **Dependencies**: Sprint 12.
- **Acceptance Criteria**:
  - Helper uses `CopyDeterministicMaSlopeValues(DETERMINISTIC_BASE_TIMEFRAME, base_delay, ...)`.
  - Helper returns bullish confirmation only for `ma_now > ma_prev`.
  - Helper returns bearish confirmation only for `ma_now < ma_prev`.
- **Validation**:
  - Static review.
  - Compile.

### Task 13.2: Gate Pending Entry With Current Base Slope

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Revalidate current delayed M1 base slope after entry trigger and before broker execution.
- **Dependencies**: Task 13.1.
- **Acceptance Criteria**:
  - Pending entry expires with `DETERMINISTIC_BASE_EXPIRED` when current delayed M1 slope no longer confirms.
  - Macro confirmation remains required before broker execution.
  - Broker-aware execution gates remain unchanged and still run after confirmations pass.
- **Validation**:
  - Static review.
  - Compile.

### Task 13.3: Add Entry Confirmation Telemetry

- **Location**:
  - `services/trading_signals/execution_logging.mqh`
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Log current base and macro slope values for successful and failed pending-entry confirmations.
- **Dependencies**: Task 13.2.
- **Acceptance Criteria**:
  - `DETERMINISTIC_ENTRY_CONFIRM` includes base shift, base MA pair, macro shift, macro MA pair, trigger, stop, `close_0`, `high_1`, and `low_1`.
  - `DETERMINISTIC_BASE_EXPIRED` includes the same confirmation context and closes the pending signal.
  - `DETERMINISTIC_MACRO_EXPIRED` includes the same confirmation context when macro confirmation fails.
- **Validation**:
  - Static review.
  - Compile.
  - Human-in-the-loop query debug check with `Enable_File_Logs=true`.

## Testing Strategy

- Use static sweeps after cleanup tasks:
  - Removed input names.
  - Obsolete range/Fibonacci/grid concepts.
  - Per-tick `iMA` or `iCustom` creation.
  - Unchecked `CopyBuffer` or array access.
- Use MetaEditor compile at the end of each implementation sprint.
- Treat warnings as failures.
- Use debug-gated tester logs to verify:
  - S1/S2/S3 descriptors load.
  - M1 source extremum is captured.
  - Delayed M1 MA setup is calculated from `ext_shift + delay`.
  - Macro confirmation uses `[1]` and `[2]`.
  - Pending candidate expires on new confirmed extremum.
  - Entry uses live `close_0`.
  - SL uses live `close_0`.
  - TP uses broker-side bid/ask and `TP_Percent`.
  - Broker reconciliation owns ticket, volume, entry, and close facts after fill.
- Use human-in-the-loop visual checks after Sprint 7:
  - S1-only: M1 shift 3 MA on base chart, M3 shift 1 MA on macro chart.
  - S2-only: M1 shift 5 MA on base chart, M5 shift 1 MA on macro chart.
  - S3-only: M1 shift 10 MA on base chart, M10 shift 1 MA on macro chart.
  - Multiple strategies: only enabled shifted MAs and their macro charts are visible.
- Use human-in-the-loop visual checks after Sprint 8:
  - Logic `shift=0` MAs are absent from visual tester charts.
  - Shifted strategy MAs remain visible when their strategy input is enabled.
- Use human-in-the-loop query debug checks after Sprint 9:
  - `DETERMINISTIC_SOURCE_AUDIT` distinguishes selected/current/confirmed extrema.
  - `DETERMINISTIC_CANDIDATE` includes source slot/type/time/price and MA pairs.
- Use human-in-the-loop query debug checks after Sprint 10:
  - New deterministic candidates use `source_slot=0`.
  - Pending signals tied to stale current extrema disappear before entry.
- Use human-in-the-loop query debug checks after Sprint 11:
  - `DETERMINISTIC_ENTRY_REFRESH` appears between `DETERMINISTIC_SIGNAL_INIT` and `DETERMINISTIC_ENTRY` when newer M1 anchors improve the pending trigger.
  - `DETERMINISTIC_ENTRY` uses the latest refreshed `raw_trigger`.
  - `raw_stop` remains the source extremum price through refresh, entry, TP, or SL.
- Use human-in-the-loop visual and query debug checks after Sprint 12:
  - Expired pending signals emit `DETERMINISTIC_SIGNAL_EXPIRED`.
  - Closed or expired deterministic signals leave no stale chart-level lines.
  - Deterministic stop anchors appear as SL/stop lines, not as misleading `NEXT` lines.
- Use human-in-the-loop query debug checks after Sprint 13:
  - `DETERMINISTIC_ENTRY_CONFIRM` appears before valid entries and includes current delayed M1 slope values.
  - `DETERMINISTIC_BASE_EXPIRED` appears when current delayed M1 slope changes against a pending signal before entry.
  - Entry is sent only after current base and macro confirmation both pass.

## Potential Risks And Gotchas

- **Shifted MA confusion**: Logic must not use shifted MA buffers. Mitigation: raw `ma_shift=0` logic handles plus separate visual shifted handles.
- **Extremum confirmation ambiguity**: The latest structure slot is provisional and may repaint. Mitigation: treat slot/type/time/price as source identity and expire pending signals when it changes.
- **Tick-model dependency**: Live `close_0` makes "open prices only" backtests unreliable. Mitigation: document real-tick testing as the faithful mode.
- **Broker close failure**: Freeze levels or broker retcodes can block closes. Mitigation: do not mark signals closed until broker reconciliation confirms closure.
- **Magic-number licensing**: Per-strategy magic derivation may conflict with license expectations. Mitigation: investigate before implementation and fall back to comment-scoped identity.
- **Aggressive cleanup blast radius**: Removing old range/grid paths may break frontend assumptions. Mitigation: cleanup in its own sprint and compile before strategy logic work continues.
- **Performance regression**: Three strategies can multiply buffer copies. Mitigation: shared M1 Stoch snapshot, shared M1 MA buffer, macro caches by timeframe, and tick-rate work only for pending/active candidates.
- **Hedging-only assumption**: Users on netting accounts will be blocked. Mitigation: fail closed with an explicit message.
- **Visual chart ownership**: Closing macro charts automatically could close a user's chart. Mitigation: track EA-opened chart IDs and close only those charts.
- **Asynchronous chart changes**: Retargeting or opening charts can complete after the call returns. Mitigation: verify `ChartSymbol` and `ChartPeriod` before adding indicators and retry later if needed.
- **Current extremum repaint**: Slot `0` can move while the structure is forming. Mitigation: treat slot/type/time/price as source identity and expire pending signals when it changes.
- **Telemetry noise**: Per-tick source logs can become large. Mitigation: use changed-state query debug logs for source audits and full logs only for actual candidates/lifecycle events.
- **Pending trigger drift**: Moving the trigger after signal creation can desynchronize risk, TP, lot sizing, and chart lines. Mitigation: refresh all pending geometry fields atomically and skip refresh when any recalculation fails.
- **Same-tick refresh and entry**: A tick may both improve the pending trigger and satisfy the breakout. Mitigation: refresh first, then evaluate entry against the refreshed trigger.
- **Visual cleanup blind spots**: Chart objects not tracked by the visualization cache can survive signal removal. Mitigation: route level drawing through tracked updates and directly clean expired pending signals.
- **Entry confirmation drift**: A signal can be valid at the source extremum but invalid by current delayed M1 slope at entry time. Mitigation: add a current-base confirmation gate immediately before broker execution.

No additional product questions are blocking this plan. The remaining unknowns are implementation discoveries, especially the exact magic-number license contract, whether all old range/grid code can be deleted in one sprint without forcing a larger frontend rewrite, and the exact lifecycle policy for EA-opened macro charts after manual user interaction.

## Rollback Plan

- Revert sprint commits in reverse order.
- If Sprint 1 cleanup is too broad, restore the last compile-clean foundation baseline and reapply only the new strategy toggles.
- If per-strategy magic numbers are unsafe, keep base magic and revert only the magic derivation task while retaining strategy comments.
- If visual MA overlays introduce frontend instability, disable visual overlays without changing the strategy logic handles.
- Keep broker guardrails and license checks fail-closed throughout rollback.
