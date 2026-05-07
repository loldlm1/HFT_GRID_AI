# Plan: Pandora Box Body Entry Type

**Generated**: 2026-05-07
**Estimated Complexity**: Medium

## Overview
Add two Pandora Box inputs so the strategy can choose between the current tick/wick breakout behavior and a new closed-candle body breakout behavior.

The safe implementation path is to keep `ENTRY_WICK_TYPE` as the default and route it through the existing tick-price trigger unchanged. The new `ENTRY_BODY_TYPE` path should only trigger from the last closed candle on `Pandora_Box_Entry_Body_Timeframe`, defaulting to `PERIOD_M5`. Body mode uses inclusive comparisons against the offset breakout levels:
- Bullish: `close_1 >= g_pandora_box_state.breakout_high_price`
- Bearish: `close_1 <= g_pandora_box_state.breakout_low_price`

Re-entry/rearm in body mode should also use the configured body timeframe: after a Pandora position closes, that direction must first print a closed candle back inside the raw Pandora box on the body timeframe, then print a later closed candle outside the offset breakout level before another entry is allowed.

No compile run or automated test coverage is required for this plan. Manual MT5 validation will be done separately.

## Current Code Findings
- Pandora inputs are centralized in `services/trading_management/ea_inputs.mqh`.
- Pandora runtime state, daily lifecycle, rearm state, and history snapshots live in `services/trading_signals/pandora_box_state.mqh`.
- Current Pandora detection runs on every tick through `PandoraDetectSignals()` from `Main_Tick()` in `HFT_Grid_AI.mq5`.
- Original entry triggering was isolated in `PandoraPriceTriggersSignal()` in `services/trading_signals/pandora_box_detection.mqh`; the implementation should split that into a preserved wick trigger plus a body-close trigger wrapper.
- Current order construction is isolated in `BuildPandoraOrderForSignal()` and already uses the Pandora breakout price as the entry reference.
- Current rearm behavior uses `PandoraPreviousCloseInsideBox()` and `PandoraRefreshRearmState()` with the Pandora box timeframe.
- Current frontend summary is built in `PandoraAppendSummary()` in `services/frontend/pandora_box_visualization.mqh`.

## Resolved Product Decisions
- Scope is only the current MQL5 EA in this workspace, not Rails.
- Existing behavior must remain unchanged when the new entry type is left at its default.
- `ENTRY_WICK_TYPE` means the current breakout behavior: live tick/current-price crossing of Pandora breakout prices.
- `ENTRY_BODY_TYPE` means a selected timeframe's last fully closed candle must close outside the offset breakout price.
- The body entry timeframe default is `PERIOD_M5`.
- A body breakout candidate is a per-direction, per-closed-candle event; the same closed body candle must not create repeated entries.
- Body breakout candidates are consumed when the EA observes a qualifying closed candle, even if a downstream guard blocks order creation. The EA then waits for the next closed body candle rather than retrying stale candle-close signals.
- Existing direction concurrency still applies through `PandoraDirectionHasActiveSignal()` and `SignalConcurrencyAllowsAttempt()`.
- The chart summary/logs should display the active Pandora entry type and effective body timeframe.
- Manual validation only; do not add compile/test harness requirements.

## Prerequisites
- Preserve the fixed include pipeline: do not re-include sibling services or introduce circular includes.
- Keep all input declarations centralized in `services/trading_management/ea_inputs.mqh`.
- Keep enum definitions in `microservices/core/enums.mqh`.
- Keep MQL5 style consistent with the repo: 2-space indentation, explicit types, no `auto`, no lambdas, no range-for.
- Use `iTime(_Symbol, tf, 1)` and `iClose(_Symbol, tf, 1)` for body mode so the EA reads the last closed candle, not the still-forming candle.
- Keep `PERIOD_M5` as the new default so the body mode is deterministic and independent of chart timeframe. If a user explicitly sets `PERIOD_CURRENT`, resolve it through a helper and show the effective timeframe in logs/panel output.

## Sprint 1: Define Inputs And Runtime State
**Goal**: Introduce the new configuration surface without changing current behavior.
**Demo/Validation**:
- Opening the EA Inputs panel shows the new Pandora entry type and body timeframe fields.
- Leaving defaults produces the same wick/tick breakout behavior as before.

### Task 1.1: Add Pandora Entry Type Enum
- **Location**: `microservices/core/enums.mqh`
- **Description**: Add a Pandora-specific enum near the other Pandora enums.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Adds `enum PandoraEntryTypes`.
  - Defines `ENTRY_WICK_TYPE = 0`.
  - Defines `ENTRY_BODY_TYPE = 1`.
  - Existing enum numeric values are not changed.
- **Validation**:
  - Manual diff review confirms no existing enum values moved or changed.

### Task 1.2: Add New Pandora Inputs
- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Add inputs under `"+= Pandora Box Strategy =+"`.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Adds `input PandoraEntryTypes Pandora_Box_Entry_Type = ENTRY_WICK_TYPE;`
  - Adds `input ENUM_TIMEFRAMES Pandora_Box_Entry_Body_Timeframe = PERIOD_M5;`
  - Existing Pandora input defaults are unchanged.
- **Validation**:
  - Manual Inputs panel review in MT5.

### Task 1.3: Extend Pandora Runtime State
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Store entry type, configured/effective body timeframe, and per-direction body candle processing stamps.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - `PandoraBoxRuntimeState` stores the selected entry type.
  - It stores the resolved body entry timeframe.
  - It stores last processed bullish and bearish body close bar times.
  - `Reset()` and `PandoraResetDailyState()` initialize the new fields safely.
  - `PandoraSyncRuntimeConfig()` hydrates the new fields from inputs.
- **Validation**:
  - Manual code review.

### Task 1.4: Add Timeframe Resolution Helper
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a helper such as `PandoraResolveEntryBodyTimeframe()` to centralize body timeframe rules.
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Default input resolves to `PERIOD_M5`.
  - Standard MT5 timeframes are allowed because body mode only needs `iTime()`/`iClose()`, not indicator handles.
  - Unsupported or unusable values fall back to a safe timeframe, preferably the repo's existing Pandora timeframe fallback behavior.
  - `PERIOD_CURRENT` is handled explicitly and the effective timeframe is stable enough to display in logs/panel output.
  - The helper does not alter `PandoraResolveBoxTimeframe()`.
- **Validation**:
  - Manual review with `PERIOD_M5`, `PERIOD_CURRENT`, and `Strategy_Timeframe` scenarios.

## Sprint 2: Implement Body-Close Trigger Path
**Goal**: Add body entry detection while preserving the current wick entry path.
**Demo/Validation**:
- With `ENTRY_WICK_TYPE`, signals trigger exactly as they do today.
- With `ENTRY_BODY_TYPE`, an M5 candle wick outside the breakout level does not enter unless the candle closes outside the offset breakout level.

### Task 2.1: Split Trigger Detection By Entry Type
- **Location**: `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Replace or wrap `PandoraPriceTriggersSignal()` with an entry-type-aware trigger helper.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Wick mode calls the existing current-price logic unchanged.
  - Body mode reads only `iTime(_Symbol, body_tf, 1)` and `iClose(_Symbol, body_tf, 1)`.
  - Body mode compares the close against `breakout_high_price` / `breakout_low_price`, not raw `box_high` / `box_low`.
  - Body mode uses inclusive checks: `>=` for bullish and `<=` for bearish.
  - Missing candle data returns false and does not corrupt state.
- **Validation**:
  - Manual Strategy Tester review with a candle that wicks out and closes inside: no body entry.
  - Manual Strategy Tester review with a candle that closes outside: body entry candidate appears.

### Task 2.2: Enforce One Body Entry Event Per Closed Candle Per Direction
- **Location**: `services/trading_signals/pandora_box_state.mqh`, `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Add helpers to check and mark whether a body close bar has already been processed for a direction.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - A bullish body close bar can produce at most one bullish candidate.
  - A bearish body close bar can produce at most one bearish candidate.
  - If a direction has an active Pandora signal, the same closed candle cannot be reused immediately after that signal closes.
  - Daily reset clears processed body candle stamps.
  - Wick mode does not use these body stamps.
- **Validation**:
  - Manual tester scenario where a position opens and closes before the next M5 candle closes; the EA does not reopen on the same M5 close.

### Task 2.3: Preserve Existing Admission Guards
- **Location**: `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Keep the existing order of daily budget, direction, rearm, session, protection, daily limit, and concurrency gates logically intact.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - `PandoraEntryBudgetReached()` still caps opened entries.
  - `PandoraDirectionAllowed()` still controls direction.
  - `PandoraDirectionReadyForEntry()` still blocks active same-direction Pandora signals.
  - `PandoraGuardsAllowAttempt()` still owns protection, debug, session, daily, and concurrency checks.
  - Body mode does not bypass `SINGLE_RUNNING_SIGNAL`.
- **Validation**:
  - Manual diff review and tester pass with `Signal_Concurrency_Mode = SINGLE_RUNNING_SIGNAL`.

### Task 2.4: Keep Order Construction Unchanged
- **Location**: `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Do not change `BuildPandoraOrderForSignal()` except for optional logging metadata if needed.
- **Dependencies**: Task 2.3
- **Acceptance Criteria**:
  - Entry reference remains the appropriate Pandora breakout price.
  - SL/TP/trailing/lot logic remains unchanged.
  - `Pandora_Box_Set_Broker_SLTP`, lot modes, and trailing modes keep their current behavior.
- **Validation**:
  - Manual diff review.

## Sprint 3: Align Rearm Logic With Entry Type
**Goal**: Make re-entry semantics consistent with the selected entry type.
**Demo/Validation**:
- In body mode, after an SL/TP/BE close, a same-direction re-entry requires a body-timeframe close back inside the raw box, followed by a later body-timeframe close outside the offset breakout level.

### Task 3.1: Resolve Rearm Timeframe By Entry Type
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a helper such as `PandoraResolveRearmTimeframe()` that returns the body timeframe for `ENTRY_BODY_TYPE` and the existing box timeframe for `ENTRY_WICK_TYPE`.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Wick mode rearm behavior remains unchanged.
  - Body mode rearm uses the resolved body timeframe.
  - The rearm helper is used anywhere rearm close bar time or rearm close price is read.
- **Validation**:
  - Manual code review.

### Task 3.2: Update Close-Inside-Box Rearm Check
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Update `PandoraPreviousCloseInsideBox()` and `PandoraRefreshRearmState()` to use the entry-type-aware rearm timeframe.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Wick mode still checks the existing Pandora box timeframe close.
  - Body mode checks `iClose(_Symbol, body_tf, 1)`.
  - The inside-box check remains inclusive against raw `box_low` and `box_high`.
  - `last_rearm_close_bar_time` tracks the effective rearm timeframe's closed bar time.
- **Validation**:
  - Manual tester scenario:
    - Entry closes.
    - Next body timeframe candle closes outside only: no rearm.
    - Later body timeframe candle closes inside raw box: rearm ready.
    - Later body timeframe candle closes outside offset breakout level: re-entry allowed.

### Task 3.3: Reset Mode-Sensitive State On Daily/Config Changes
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Ensure daily reset and relevant config changes do not leave stale body or rearm stamps.
- **Dependencies**: Task 3.2
- **Acceptance Criteria**:
  - New day clears body processed stamps and rearm stamps.
  - If entry type or effective body timeframe changes while the EA is running, stale processed body bar times cannot block the new configuration indefinitely.
  - Existing Pandora history snapshot state remains independent unless the frontend summary needs the effective timeframe.
- **Validation**:
  - Manual input-change review in visual tester.

## Sprint 4: Observability And Documentation
**Goal**: Make the new mode visible for manual analysis without cluttering the chart.
**Demo/Validation**:
- Chart panel/status shows the active Pandora entry type and effective body timeframe.
- Logs identify body-mode entries and the body candle that triggered them.

### Task 4.1: Add Entry Type Labels
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add compact label helpers for entry type and effective body timeframe.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - `ENTRY_WICK_TYPE` displays as a concise label such as `WICK`.
  - `ENTRY_BODY_TYPE` displays as a concise label such as `BODY`.
  - Effective timeframe displays as a stable MT5 period label such as `M5`.
- **Validation**:
  - Manual visual review.

### Task 4.2: Update Pandora Chart Summary
- **Location**: `services/frontend/pandora_box_visualization.mqh`, optionally `services/frontend/pandora_box_panel.mqh`
- **Description**: Extend the compact Pandora status line with the active entry type and effective body timeframe.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Wick mode summary remains short and readable.
  - Body mode summary includes `entry=BODY` and `tf=M5` or equivalent.
  - The panel width cap still prevents excessive visual growth.
- **Validation**:
  - Manual chart review in live chart and Strategy Tester comment fallback.

### Task 4.3: Add Trigger Logs
- **Location**: `services/trading_signals/pandora_box_detection.mqh`, `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add `Enable_Logs` guarded `PrintFormat()` messages when a Pandora entry opens, including entry type, effective body timeframe, and body close details when applicable.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Wick entries include `entry=WICK`.
  - Body entries include `entry=BODY`, `tf=<effective timeframe>`, `bar=<closed bar time>`, and `close=<close price>`.
  - Existing `PANDORA_ENTRY_OPEN` counters remain present.
- **Validation**:
  - Manual log review.

### Task 4.4: Update User-Facing Docs And Agent Notes
- **Location**: `docs/guides/pandora-box-strategy-inputs.md`, `docs/guides/pandora_box_guide_en.md`, `docs/guides/pandora_box_guide_es.md`, `AGENTS.md`
- **Description**: Document the new entry type and body timeframe behavior.
- **Dependencies**: Sprints 2 and 3
- **Acceptance Criteria**:
  - Docs state `ENTRY_WICK_TYPE` is the default and preserves current behavior.
  - Docs state `ENTRY_BODY_TYPE` uses the selected timeframe's last closed candle.
  - Docs state body mode compares against offset breakout levels.
  - Docs state body mode rearm uses the body timeframe.
  - Docs state manual tester validation is recommended before live use.
- **Validation**:
  - Manual documentation review.

## Manual Validation Strategy
- No automated tests or compile runs are required from the implementation agent.
- Use MT5 Strategy Tester visual mode and broker logs.
- Baseline regression:
  - `Pandora_Box_Entry_Type = ENTRY_WICK_TYPE`.
  - Keep existing Pandora settings.
  - Confirm breakouts trigger as they did before.
- Body wick rejection:
  - `Pandora_Box_Entry_Type = ENTRY_BODY_TYPE`.
  - `Pandora_Box_Entry_Body_Timeframe = PERIOD_M5`.
  - Create or find an M5 candle whose wick crosses the breakout level but close is inside/equal-not-outside the level.
  - Confirm no entry.
- Body inclusive breakout:
  - Confirm bullish entry when M5 `close_1 >= breakout_high_price`.
  - Confirm bearish entry when M5 `close_1 <= breakout_low_price`.
- One-entry-per-closed-candle:
  - Confirm repeated ticks after the same M5 close do not open multiple same-direction Pandora entries.
  - Confirm a quick close before the next M5 close does not reuse the same body candle for another entry.
- Rearm:
  - After SL/TP/BE, confirm body mode waits for a body-timeframe close back inside raw `box_low`/`box_high`.
  - Confirm re-entry requires a later body-timeframe close outside the offset breakout level.
- Concurrency:
  - With `Signal_Concurrency_Mode = SINGLE_RUNNING_SIGNAL`, confirm body mode does not authorize concurrent same-direction Pandora entries.
- Observability:
  - Confirm panel/status displays entry type and effective timeframe.
  - Confirm logs include entry type and body candle details for body entries.

## Potential Risks & Gotchas
- `PERIOD_CURRENT` can be ambiguous in an input because it can depend on chart context. Mitigation: default to `PERIOD_M5`, resolve `PERIOD_CURRENT` through a single helper, and display the effective timeframe.
- If body candidate stamps are only marked after successful order creation, a fast close could allow the same closed candle to be reused. Mitigation: mark a body candle as processed for that direction when the body breakout candidate is observed, before allowing any same-candle re-entry.
- If body candidate stamps are marked before all guards pass, a session/concurrency guard can consume that candle. This is intentional: body mode treats a closed candle as a one-time signal event and waits for the next closed candle if the current event cannot become an order.
- Body mode rearm must compare inside-box closes against raw box high/low, not offset breakout prices. Offset prices are only for breakout entry confirmation.
- The existing early `OnTick()` return for excessive spread or closed market can delay body candidate observation. This is inherited behavior; manual validation should include normal-spread periods.
- Chart summary lines are capped, so adding labels should be compact enough not to hide other Pandora state.

## Rollback Plan
- Set `Pandora_Box_Entry_Type = ENTRY_WICK_TYPE` to restore current behavior at runtime.
- To revert the code change completely:
  - Remove `PandoraEntryTypes` from `microservices/core/enums.mqh`.
  - Remove the two new inputs from `services/trading_management/ea_inputs.mqh`.
  - Remove body timeframe/runtime stamp fields and helpers from `services/trading_signals/pandora_box_state.mqh`.
  - Restore `PandoraPriceTriggersSignal()` in `services/trading_signals/pandora_box_detection.mqh` to the current tick-price-only implementation.
  - Revert frontend/doc additions.
