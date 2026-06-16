# Plan: Pandora First Entry Deep Levels

**Generated**: 2026-06-16
**Estimated Complexity**: High
**Risk Class**: Trading-safety sensitive

## Overview

Add a Pandora first-entry mode input that controls when the first real market
entry is admitted after a valid Pandora breakout. The default must preserve the
current breakout behavior. The new deep-entry modes observe the original
breakout locally, wait for configured SL-depth levels in the same trade
direction, and only then use the existing broker-realistic market-entry flow.

The core rule is that the real entry price always comes from the market path
already used today: broker fill first, otherwise broker-realistic local anchor
when broker execution cannot complete. SL/TP point distances remain
deterministic from the active real/local entry anchor, including slippage.

For `First_Entry_Sl_*`, local observation uses fixed TP checks only. If the
local observation reaches its TP before the requested deep SL entry level, the
opportunity is discarded and can consume the Pandora entry budget according to
the mode. Step trailing is only allowed after a real broker-realistic market
entry is admitted.

## Prerequisites

- Before executing this plan, read `docs/planner-execution-discipline.md`.
- Execute one Sprint per batch unless the user explicitly approves a larger
  batch after reviewing validation from the previous Sprint.
- Preserve the current include pipeline and avoid sibling re-includes.
- Run the MetaEditor compile gate after every implementation Sprint:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

- Read `BUILD.log`, confirm the result, then delete `BUILD.log` before handoff.
- Keep all new MQL5 identifiers in local style: `CamelCase` functions,
  `snake_case` locals, 2-space indentation, explicit constructors.

## Product Contract

- Add input `Pandora_First_Entry_Mode` immediately after
  `Pandora_Box_Max_Entries`.
- Default is `First_Entry_Breakout`.
- `First_Entry_Breakout`: preserve current behavior.
- `First_Entry_Off`: at breakout, admit a local-only broker-realistic entry,
  never send `OrderSend`, and let local SL/TP close it.
- `First_Entry_Sl_1`: at breakout, observe the virtual breakout entry. If
  breakout TP hits first, discard the opportunity. If SL1 hits first, admit the
  real market entry in the same direction.
- `First_Entry_Sl_2`: at breakout, observe the virtual breakout entry. If
  breakout TP hits before SL1, discard. If SL1 hits, move to an SL1 observation
  stage. If SL1 TP hits before SL2, discard. If SL2 hits, admit the real market
  entry in the same direction.
- `SL1 = breakout_entry +/- 1 * resolved_sl_points`.
- `SL2 = breakout_entry +/- 2 * resolved_sl_points`.
- TP distances for local observation use resolved fixed TP points, even when
  `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP`.
- Once a real market entry is admitted, current Pandora trailing behavior may
  apply from the actual active anchor.
- Deep-mode opportunities expire only when the operating window ends.

## Sprint 1: Input And Runtime Configuration

**Goal**: Add the public input and runtime configuration without changing
trading behavior.
**Commit**: `feat: add pandora first entry mode input`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- Default `First_Entry_Breakout` produces no behavior changes.
- MT5 inputs show `Pandora_First_Entry_Mode` after `Pandora_Box_Max_Entries`.

### Task 1.1: Add First Entry Mode Enum

- **Location**:
  - `microservices/core/enums.mqh`
- **Description**: Add `PandoraFirstEntryModes`.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Enum values are:
    - `First_Entry_Off = 0`
    - `First_Entry_Breakout = 1`
    - `First_Entry_Sl_1 = 2`
    - `First_Entry_Sl_2 = 3`
  - Names match the user-facing input values exactly.
- **Validation**:
  - Compile gate.
  - Manual enum location review near existing Pandora enums.

### Task 1.2: Add Input After Max Entries

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Add `input PandoraFirstEntryModes Pandora_First_Entry_Mode`
  immediately after `Pandora_Box_Max_Entries`.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Default is `First_Entry_Breakout`.
  - No other input order changes.
  - No changes to default risk values.
- **Validation**:
  - Compile gate.
  - Visual inspection in MT5 input list.

### Task 1.3: Resolve Runtime Config

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add runtime storage and resolver for the configured first
  entry mode.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance Criteria**:
  - Invalid enum values fail closed to `First_Entry_Breakout`.
  - Runtime state reset initializes the mode to `First_Entry_Breakout`.
  - `PandoraSyncRuntimeConfig()` updates the runtime mode.
- **Validation**:
  - Compile gate.
  - Diff review for config-only changes.

## Sprint 2: Deep Observation State And Price Math

**Goal**: Add deterministic local-observation state and helper math without
changing order sending.
**Commit**: `feat: model pandora deep entry observation`
**Demo/Validation**:
- Compile passes.
- Logs or debug inspection can resolve breakout TP, SL1, SL1 TP, and SL2
  targets for both bullish and bearish directions.

### Task 2.1: Add Observation State

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
- **Description**: Add minimal state for deep first-entry observation.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Add a simple stage enum such as:
    - `PANDORA_FIRST_ENTRY_STAGE_NONE`
    - `PANDORA_FIRST_ENTRY_STAGE_BREAKOUT_OBSERVE`
    - `PANDORA_FIRST_ENTRY_STAGE_SL1_OBSERVE`
    - `PANDORA_FIRST_ENTRY_STAGE_MARKET_ADMITTED`
    - `PANDORA_FIRST_ENTRY_STAGE_DISCARDED`
    - `PANDORA_FIRST_ENTRY_STAGE_EXPIRED`
  - `SignalParams` stores:
    - configured mode snapshot
    - current observation stage
    - observation anchor price/time
    - current deep trigger price
    - current observation TP price
    - discard/expiration marker
  - Default and copy constructors preserve all fields.
- **Validation**:
  - Compile gate.
  - Constructor and copy-constructor diff review.

### Task 2.2: Add Price Math Helpers

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add helpers to compute observation targets from existing
  resolved Pandora points.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Helpers use existing point resolution for `Pandora_Points_Value_Mode`.
  - Bullish:
    - `SL1 = anchor - sl_points * point`
    - `SL2 = anchor - 2 * sl_points * point`
    - `TP = anchor + tp_points * point`
  - Bearish:
    - `SL1 = anchor + sl_points * point`
    - `SL2 = anchor + 2 * sl_points * point`
    - `TP = anchor - tp_points * point`
  - Prices are normalized with existing Pandora/broker price helpers.
  - Observation TP remains available even when step trailing is enabled.
- **Validation**:
  - Compile gate.
  - Manual trace on sample bullish and bearish prices.

### Task 2.3: Add Observation Hit Predicates

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add helpers to detect observation TP hit, SL1 hit, SL2 hit,
  and operating-window expiration.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Uses existing `GridCurrentPriceForDirection()` side conventions.
  - Does not create positions or send orders.
  - Expiration is based on operating-window end. When the session filter is
    enabled, use the existing session-window state. When disabled, expire on
    Pandora day reset/window lifecycle.
- **Validation**:
  - Compile gate.
  - Manual review against Pandora session-filter semantics.

## Sprint 3: Detection And Budget Semantics

**Goal**: Route breakout events into either current admission or deep
observation while preserving daily and Pandora budgets.
**Commit**: `feat: add pandora deep entry admission flow`
**Demo/Validation**:
- Breakout mode remains unchanged.
- Deep modes create an active observation without broker send.
- Budget is consumed only on configured discard or real market admission.

### Task 3.1: Split Observation Start From Budget Consumption

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/market_signal_state.mqh`
- **Description**: For `First_Entry_Sl_1` and `First_Entry_Sl_2`, start a
  running Pandora observation signal at breakout without immediately consuming
  `Pandora_Box_Max_Entries`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `First_Entry_Breakout` still calls existing budget/daily signal registration
    at the same lifecycle point as today.
  - `First_Entry_Off` consumes budget immediately because it admits a local-only
    entry at breakout.
  - Deep modes reserve an active observation to prevent duplicate same-direction
    entries while pending.
  - Existing session, protection, market status, concurrency, and daily signal
    guards are still checked before observation starts.
- **Validation**:
  - Compile gate.
  - Diff review of `RegisterDailySignalStart()` and
    `PandoraRegisterEntryTriggered()` call sites.

### Task 3.2: Consume Budget On Deep Entry Or Discard

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Add explicit helper(s) for deep-mode budget consumption.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - `First_Entry_Sl_1` consumes budget when:
    - breakout TP hits first and the opportunity is discarded, or
    - SL1 hits and market admission begins.
  - `First_Entry_Sl_2` consumes budget when:
    - breakout TP hits before SL1 and the opportunity is discarded, or
    - SL1 TP hits before SL2 and the opportunity is discarded, or
    - SL2 hits and market admission begins.
  - After budget consumption, `Pandora_Box_Max_Entries` and daily completion
    behavior remain consistent with the existing `total_entries` /
    `closed_entries` model.
- **Validation**:
  - Compile gate.
  - Manual scenario review with `Pandora_Box_Max_Entries = 1`.

### Task 3.3: Add Simple Discard Outcome

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/frontend/pandora_box_panel.mqh`
  - `services/frontend/pandora_box_visualization.mqh`
- **Description**: Prefer a simple explicit discard marker. If this creates too
  much churn in close/outcome handling, map discard to the existing
  `PANDORA_CLOSE_TP` with a deep-discard marker label.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Discarded opportunities are distinguishable in logs/panel/markers.
  - `Pandora_Box_Stop_On_First_Win` can complete the day on a discard TP when
    configured.
  - Broker history is never implied for discarded opportunities.
- **Validation**:
  - Compile gate.
  - Manual log and panel label review.

### Task 3.4: Expire Deep Observations

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
- **Description**: Close observations that reach the end of the operating
  window without TP discard or deep market admission.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - Expiration does not call `OrderSend`.
  - Expiration does not create broker PnL.
  - Expiration closes the running signal so the day/session can clean up.
  - Budget consumption on expiration is intentionally reviewed before coding.
    Default policy: expiration does not consume `Pandora_Box_Max_Entries`.
- **Validation**:
  - Compile gate.
  - Strategy Tester visual scenario where price never reaches TP or deep SL.

## Sprint 4: Market Admission And Local-Only Execution

**Goal**: Connect deep modes to the existing broker-realistic execution path
and add explicit local-only behavior for `First_Entry_Off`.
**Commit**: `feat: execute pandora first entry modes`
**Demo/Validation**:
- `First_Entry_Off` never creates broker history.
- `First_Entry_Sl_1` and `First_Entry_Sl_2` enter the market only after their
  configured deep trigger.
- Real entry SL/TP/trailing are based on fill/current executable anchor, not the
  original breakout anchor.

### Task 4.1: Implement First Entry Off Local-Only Path

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Add a clean local-only admission path for
  `First_Entry_Off`.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - No `OrderSend` is attempted.
  - Entry anchor uses current executable side: Ask for buy, Bid for sell.
  - Local SL/TP are computed from the local-only entry anchor.
  - Broker status/labels do not imply a broker reject.
  - Local close and metrics behave like current local-only Pandora lifecycle.
- **Validation**:
  - Compile gate.
  - Strategy Tester visual run confirms no matching broker deal.

### Task 4.2: Admit Market Entry From SL1/SL2 Trigger

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: When the deep trigger is hit, transition the signal to the
  existing pending-admission/market-send path.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Same-direction market entry only.
  - Existing spread, margin, market-status, platform-disabled, retry, and broker
    stop-sync behavior remain intact.
  - Fill price rebases active local SL/TP.
  - Slippage does not change configured SL point distance.
- **Validation**:
  - Compile gate.
  - Manual diff review of `GridExecuteLevelTrade()` and retry paths.

### Task 4.3: Gate Trailing To Real Market Admission

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Ensure step trailing is ignored during deep local
  observation and only starts after a real broker-realistic market entry.
- **Dependencies**: Tasks 4.1-4.2.
- **Acceptance Criteria**:
  - Deep observation TP is fixed even when
    `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP`.
  - `First_Entry_Off` uses local fixed SL/TP, not trailing.
  - After SL1/SL2 real admission, existing step trailing works from the active
    entry anchor.
- **Validation**:
  - Compile gate.
  - Strategy Tester visual scenario with step trailing enabled.

### Task 4.4: Preserve Broker Stop Sync

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Verify deep-entry fills still synchronize broker-side
  protection only after successful broker execution, matching current Pandora
  behavior.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Opening market requests keep the current no-initial-SLTP behavior.
  - Broker-side protection targets are derived from the real fill or accepted
    local anchor.
  - Failed/wide/pending broker stops remain non-fatal to local lifecycle.
- **Validation**:
  - Compile gate.
  - Invalid stops manual tester scenario.

## Sprint 5: Visual Diagnostics And Documentation

**Goal**: Make the feature visible enough for Strategy Tester review and update
the strategy guides.
**Commit**: `docs: document pandora first entry modes`
**Demo/Validation**:
- Chart shows simple deep-entry observation levels.
- Guides explain budget, discard, expiration, and trailing semantics.

### Task 5.1: Add Simple Chart Lines

- **Location**:
  - `services/frontend/pandora_box_visualization.mqh`
  - `services/frontend/grid_visualization.mqh` only if existing grid helpers are
    the right boundary
  - `microservices/frontend/grid_visual_lines.mqh` only if reusable line helpers
    are needed
- **Description**: Draw simple visual levels for active deep observations.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Show current observation TP.
  - Show SL1 and/or SL2 target relevant to the active mode.
  - Keep labels short Spanish ASCII, for example `TP obs`, `SL1 entry`,
    `SL2 entry`, `Deep descartado`.
  - Do not add chart-object churn in per-tick hot paths.
  - Clear objects on deinit/day reset with existing cleanup boundaries.
- **Validation**:
  - Compile gate.
  - Visual Strategy Tester inspection on desktop chart.

### Task 5.2: Update Panel/Logs

- **Location**:
  - `services/frontend/pandora_box_panel.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_logging.mqh`
- **Description**: Add compact diagnostics for first-entry mode and observation
  stage.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Logs distinguish observation start, TP discard, deep trigger, real
    admission, local-only off, and expiration.
  - Panel labels remain compact and do not drive trading behavior.
  - No account, license, or broker credential data is logged.
- **Validation**:
  - Compile gate.
  - Review `query_debug.txt` output from short tester run if file logging is on.

### Task 5.3: Update User Guides

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
- **Description**: Document the new input, default behavior, deep-entry
  semantics, budget consumption, discard outcomes, expiration, and trailing
  limits.
- **Dependencies**: Tasks 5.1-5.2.
- **Acceptance Criteria**:
  - Guides state that deep entries are same-direction, not reversal entries.
  - Guides state that real entry price is broker-realistic and SL points are
    deterministic from the active entry anchor.
  - Guides state that local observation uses fixed TP even if trailing is
    enabled.
  - Regression checklist includes all first-entry modes.
- **Validation**:
  - Markdown review.
  - Compile gate if docs are committed with code from the Sprint.

## Sprint 6: Regression Scenarios And Final Hardening

**Goal**: Validate all modes in narrow Strategy Tester/manual scenarios and
clean up edge cases before handoff.
**Commit**: `test: validate pandora first entry modes`
**Demo/Validation**:
- MetaEditor compile passes with zero errors and warnings.
- `BUILD.log` is inspected and deleted.
- Diff review confirms no unrelated include or license changes.

### Task 6.1: Breakout And Off Regression

- **Location**:
  - No required code location unless defects are found.
- **Description**: Validate default breakout and local-only off modes.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - `First_Entry_Breakout` matches prior behavior.
  - `First_Entry_Off` creates no broker trade and closes locally at fixed SL/TP.
  - `Pandora_Box_Max_Entries = 1` completes the day after the valid local close.
- **Validation**:
  - Strategy Tester visual mode.
  - Broker history and chart marker review.

### Task 6.2: SL1 Scenarios

- **Location**:
  - No required code location unless defects are found.
- **Description**: Validate SL1 observation, discard, and market admission.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - Breakout TP before SL1 discards and consumes the valid opportunity.
  - SL1 before breakout TP admits market entry.
  - Fill/retry rebases SL/TP from actual entry.
  - Spread guard and retry behavior remain current.
- **Validation**:
  - Strategy Tester visual mode, real ticks preferred.
  - `query_debug.txt` review when relevant.

### Task 6.3: SL2 Scenarios

- **Location**:
  - No required code location unless defects are found.
- **Description**: Validate two-stage deep observation.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - Breakout TP before SL1 discards.
  - SL1 reached then SL1 TP before SL2 discards.
  - SL2 reached admits market entry.
  - Expiration closes pending observation at operating-window end.
- **Validation**:
  - Strategy Tester visual mode, real ticks preferred.
  - Chart level review for SL1, SL1 TP, and SL2.

### Task 6.4: Points Mode And Trailing Matrix

- **Location**:
  - No required code location unless defects are found.
- **Description**: Validate points and box-percent math, plus trailing behavior.
- **Dependencies**: Sprints 1-5.
- **Acceptance Criteria**:
  - `PANDORA_VALUE_MODE_POINTS` uses configured points.
  - `PANDORA_VALUE_MODE_BOX_PERCENT` resolves all SL/TP observation targets from
    the box range.
  - Step trailing is ignored during local observation.
  - Step trailing starts only after real market admission.
- **Validation**:
  - Strategy Tester visual mode.
  - Manual calculation against chart levels.

## Testing Strategy

- Compile after every Sprint with MetaEditor and delete `BUILD.log` after
  inspection.
- Use Strategy Tester visual mode with "Every tick based on real ticks" when
  validating deep triggers, spread, retry, order lifecycle, and SL/TP timing.
- Keep tester scenarios narrow:
  - default breakout unchanged
  - local-only off
  - SL1 discard
  - SL1 real admission
  - SL2 breakout TP discard
  - SL2 SL1-TP discard
  - SL2 real admission
  - operating-window expiration
  - step trailing enabled during observation and after real admission
  - invalid stops / broker stop tightening
  - high spread at deep trigger then normal spread
- Review `query_debug.txt` only for short focused runs. Clear or rotate before
  longer sessions if needed.

## Potential Risks & Gotchas

- Deferring budget consumption can accidentally allow duplicate observations.
  Mitigation: keep an active running signal/observation reservation even before
  `total_entries` increments.
- Existing code assumes `PandoraRegisterEntryTriggered()` happens when the
  signal is built. Mitigation: split observation-start logs from budget
  consumption and review all `total_entries`, `closed_entries`, and
  `counted_entries` paths.
- `Pandora_Risk_Trailing_Mode` currently makes TP zero in some Pandora paths.
  Mitigation: add a dedicated fixed-observation TP helper that ignores trailing
  until real market admission.
- Expiration semantics may need product confirmation. Default policy in this
  plan is that expiration closes the observation without consuming
  `Pandora_Box_Max_Entries`.
- Adding a new close outcome can create panel/counting churn. Mitigation: prefer
  a separate deep-discard marker and reuse `PANDORA_CLOSE_TP` for win/day
  completion if the new outcome spreads too far.
- Broker fill slippage must not reuse the old breakout anchor. Mitigation:
  continue using `PandoraMarkBrokerExecuted()` and active source-of-truth
  rebasing before computing local SL/TP.
- Chart objects can become noisy in tester. Mitigation: draw only active
  observation levels and reuse existing object update/cleanup helpers.

## Rollback Plan

- Revert the Sprint commits in reverse order.
- If rollback must be partial, first set default behavior to
  `First_Entry_Breakout` and bypass all deep-observation branches.
- Remove chart diagnostics before removing core state if visual objects cause
  cleanup problems.
- After rollback, run MetaEditor compile, inspect `BUILD.log`, delete it, and
  confirm `First_Entry_Breakout` matches the previous Pandora behavior.
