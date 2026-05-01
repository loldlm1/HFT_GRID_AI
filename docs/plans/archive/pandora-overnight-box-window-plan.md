# Plan: Pandora Overnight Box Window

**Generated**: 2026-04-30
**Estimated Complexity**: Medium

## Overview
Allow `Pandora_Box_Time_Range` to support overnight windows such as `23:00-00:10` without marking the box as `PANDORA INVALID WINDOW`. The simplest safe approach is to keep Pandora's existing same-day behavior unchanged, then add explicit wrapped-window semantics only when `start > end`.

The intended behavior is:
- `12:00-13:30` remains a same-day box exactly as it works now.
- `23:00-00:10` means the box starts on the last known closed D1 candle day and closes on the current adjusted trading day, so Pandora can trade after the close time on the current day.
- `00:00-00:00` remains invalid for Pandora because identical start/end values do not define a usable box range.
- The session time filter remains an admission gate only. It should continue blocking or force-closing according to `Session_*` inputs, but it should not decide whether the Pandora box window is valid.
- Existing DST/season handling should continue through `Session_Time_Dst_Mode`, with a small improvement so Pandora resolves the offset for the specific box day instead of applying today's offset to every historical day.
- No automated tests or compile execution are required in this plan because manual MT5 validation will be done separately.

## Key Code Findings
- `services/trading_signals/pandora_box_state.mqh` rejects wrapped Pandora windows in `PandoraParseWindowMinutes()` because it returns false when `parsed_start >= parsed_end`.
- Runtime Pandora window times are resolved in `PandoraEnsureWindowParsed()` using `ResolveCurrentDayStart()` and `ResolveTradingTimeOffsetMinutes()`.
- Historical chart boxes use `PandoraResolveWindowForDay()` and currently share the same same-day-only parser.
- `services/trading_management/session_time_filter_context.mqh` already supports wrapped session ranges through `SessionTimeFilterParseRange()` and `SessionTimeFilterMinuteInRange()`.
- `services/trading_signals/pandora_box_detection.mqh` calls `SessionTimeFilterAllowsSignalAttempt()` only after the box exists and price triggers, so the session filter is already in the right layer for this situation.

## Resolved Product Decisions
- Wrapped Pandora boxes are owned by the day they close for daily lifecycle purposes.
- The wrapped start side should use the last known closed D1 candle anchor, not `day_anchor - 86400`, because brokers/symbols can expose Sunday, Saturday, or Friday as the most recent D1 bar.
- Identical start/end values remain invalid for Pandora.
- No extra questions are blocking the implementation plan.

## Prerequisites
- Preserve the ordered include pipeline from `HFT_Grid_AI.mq5`.
- Do not re-include sibling services from Pandora files.
- Keep MQL5 style consistent: 2-space indentation, explicit types, no `auto`, no lambdas, no range-for.
- Treat the existing session filter as correct unless manual validation proves otherwise.
- Do not add test files, harness cases, or compile steps for this change.

## Sprint 1: Define Wrapped Pandora Window Semantics
**Goal**: Make the product behavior explicit before changing implementation.
**Demo/Validation**:
- A maintainer can read the notes and know how `23:00-00:10` maps to actual MT5 datetimes.
- Same-day windows remain clearly backward compatible.

### Task 1.1: Document The Runtime Semantics In The Implementation Notes
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a short local comment near the Pandora window parser/resolver explaining that wrapped windows are assigned to the day they close.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `start < end` means current-day start to current-day end.
  - `start > end` means last known closed D1 candle day start to current adjusted day end.
  - `start == end` remains invalid for Pandora unless product requirements explicitly change.
- **Validation**:
  - Manual code review only.

### Task 1.2: Confirm Session Filter Scope Stays Unchanged
- **Location**: `services/trading_signals/pandora_box_detection.mqh`
- **Description**: Review the current calls to `SessionTimeFilterWindowIsOpen()` and `SessionTimeFilterAllowsSignalAttempt()` and keep them as signal-admission logic, not box-window parsing logic.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Pandora can compute a valid overnight box even if the current session is closed.
  - Pandora only attempts entries when the session filter allows attempts, if `Pandora_Box_Use_Session_Filter = true`.
- **Validation**:
  - Manual Strategy Tester review with `Pandora_Box_Use_Session_Filter` enabled and disabled.

## Sprint 2: Add Overnight Parsing Without Breaking Same-Day Windows
**Goal**: Accept `start > end` in Pandora and resolve it deterministically.
**Demo/Validation**:
- `Pandora_Box_Time_Range = "23:00-00:10"` no longer displays `PANDORA INVALID WINDOW`.
- `Pandora_Box_Time_Range = "12:00-13:30"` behaves exactly as before.

### Task 2.1: Extend Pandora Runtime State With Wrap Metadata
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a `bool window_wraps` field to `PandoraBoxRuntimeState`, reset it in `Reset()`, and update any daily reset behavior only if needed.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - The new field is initialized to `false`.
  - Existing same-day windows keep `window_wraps = false`.
- **Validation**:
  - Manual code review.

### Task 2.2: Replace Same-Day-Only Pandora Parsing With Wrap-Aware Parsing
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Change `PandoraParseWindowMinutes()` to return start minutes, end minutes, and a wrap flag. Keep invalid format checks exactly as they are, but allow `parsed_start > parsed_end`.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - `"12:00-13:30"` parses as valid, `wraps=false`.
  - `"23:00-00:10"` parses as valid, `wraps=true`.
  - `"00:10-00:10"` remains invalid for Pandora.
  - Empty strings, missing delimiters, bad hour/minute values, and malformed ranges remain invalid.
- **Validation**:
  - Manual input panel checks using valid same-day, valid wrapped, and invalid values.

### Task 2.3: Centralize Pandora Window Datetime Resolution
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add a small helper that converts a close-day D1 anchor, a previous closed D1 anchor, parsed minutes, and the wrap flag into `window_start_time` and `window_end_time`. Use the helper from both runtime parsing and historical snapshot resolution.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Same-day windows produce the same start/end datetimes as the current code.
  - Wrapped windows produce `start_time < end_time`.
  - Wrapped windows are assigned to the day they close:
    - Example with zero offset: if `day_anchor=2026.03.24 00:00` and the last closed D1 candle anchor is `2026.03.23 00:00`, `23:00-00:10` resolves to `2026.03.23 23:00` through `2026.03.24 00:10`.
    - If the previous D1 anchor is `2026.03.20 00:00` because the symbol has no Sunday/Monday D1 bar yet, the wrapped start resolves from `2026.03.20 23:00` rather than calendar Sunday.
  - Runtime and history visualization use identical window resolution.
- **Validation**:
  - Visual Strategy Tester check on a wrapped range.
  - Confirm the chart panel moves from `INVALID WINDOW` to `WAIT`, `ARMED`, or `READY` depending on tester time.

### Task 2.4: Thread The D1 Shift Through Historical Snapshot Resolution
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: Change the Pandora history snapshot path so `PandoraRebuildHistorySnapshots()` passes the D1 shift into `PandoraBuildHistorySnapshot()`, and the window resolver can use `iTime(_Symbol, PERIOD_D1, shift + 1)` as the wrapped start anchor.
- **Dependencies**: Task 2.3
- **Acceptance Criteria**:
  - Runtime wrapped windows use `iTime(_Symbol, PERIOD_D1, 1)` as the start-day anchor.
  - Historical wrapped windows use `iTime(_Symbol, PERIOD_D1, shift + 1)` as the start-day anchor.
  - If the required previous D1 anchor is unavailable, the snapshot/window is marked invalid with a clear reason such as `No previous D1 anchor for Pandora wrapped window`.
  - The implementation does not use a raw `day_anchor - 86400` fallback for wrapped starts.
- **Validation**:
  - Manual visual review on symbols whose recent D1 history includes different weekend behavior.

### Task 2.5: Keep Existing Box Computation And Trading Logic Intact
- **Location**: `services/trading_signals/pandora_box_detection.mqh`, `services/trading_signals/pandora_box_state.mqh`
- **Description**: Do not change `CopyRates()`, box high/low calculation, range validation, breakout price calculation, entry budgets, rearm logic, daily limits, or concurrency guards except where they consume the corrected window datetimes.
- **Dependencies**: Task 2.4
- **Acceptance Criteria**:
  - `PandoraComputeBoxWindow()` still computes high/low from `CopyRates()` over the resolved window.
  - `Pandora_Box_Max_Range_Points` still invalidates oversized boxes.
  - `Pandora_Box_Use_Session_Filter` still gates attempts after price triggers.
- **Validation**:
  - Manual diff review.

## Sprint 3: Make Season Changes Reliable For Current And Historical Boxes
**Goal**: Ensure Pandora windows continue to align when `Session_Time_Dst_Mode` changes the effective offset across broker seasons.
**Demo/Validation**:
- Current-day Pandora windows follow the active season.
- Historical Pandora rectangles use the offset that belongs to their own day, not blindly the current day offset.

### Task 3.1: Add A Reference-Time Offset Helper While Preserving The Existing API
- **Location**: `microservices/utils/time_offset_helper.mqh`
- **Description**: Add a helper such as `ResolveTradingTimeOffsetMinutesAt(datetime reference_time)` and make existing `ResolveTradingTimeOffsetMinutes()` call it with `TimeCurrent()`.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `DST_MODE_OFF` returns `0`.
  - `DST_MODE_MANUAL` returns `Session_Time_Dst_Manual_Offset_Minutes`.
  - `DST_MODE_AUTO_EXNESS` uses `ExnessDstActive(reference_time)`.
  - Existing callers of `ResolveTradingTimeOffsetMinutes()` keep the same behavior.
- **Validation**:
  - Manual code review.

### Task 3.2: Resolve Pandora Start And End Offsets Against Their Own Window Anchors
- **Location**: `services/trading_signals/pandora_box_state.mqh`
- **Description**: In the centralized Pandora datetime helper, resolve the offset using the start-side D1 anchor and end-side D1 anchor. This avoids one-hour mistakes on exact DST transition days and in historical snapshots.
- **Dependencies**: Task 3.1, Task 2.4
- **Acceptance Criteria**:
  - Same-day behavior remains unchanged outside DST boundary days.
  - Wrapped windows crossing a season boundary remain chronological.
  - Runtime and historical wrapped windows both resolve offsets from their own D1 anchors.
  - `PandoraHistoryConfigSignature()` still refreshes when relevant offset inputs or effective offset behavior changes.
- **Validation**:
  - Manual Strategy Tester check around concrete dates:
    - Exness DST start date: 2026-03-08.
    - Exness DST end date: 2026-11-01.

### Task 3.3: Leave Session Filter Logic Untouched Except For Shared Helper Compatibility
- **Location**: `services/trading_management/session_time_filter_context.mqh`
- **Description**: Keep `SessionTimeFilterCurrentMinutes()` using `ResolveTradingTimeOffsetMinutes()` so active session evaluation remains based on current server time.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Session filter still supports wrapped ranges.
  - Session filter still defaults invalid enabled ranges to the full trading day with a warning.
  - No Pandora-specific behavior is introduced into session filter files.
- **Validation**:
  - Manual chart/log review with an enabled wrapped session window.

## Sprint 4: Update User-Facing Documentation And Chart Messaging
**Goal**: Make the new behavior discoverable without changing the compact frontend design.
**Demo/Validation**:
- Users no longer see docs saying Pandora must always be same-day.
- Invalid messages remain useful for genuinely malformed ranges.

### Task 4.1: Update Pandora Input Documentation
- **Location**: `README.md`, `docs/guides/pandora-box-strategy-inputs.md`, `docs/guides/pandora_box_guide_en.md`, `docs/guides/pandora_box_guide_es.md`
- **Description**: Update `Pandora_Box_Time_Range` documentation to say `HH:MM-HH:MM` supports same-day windows and overnight windows where start is later than end.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Same-day example remains present.
  - New wrapped example is present, for example `23:00-00:10`.
  - Docs explain that wrapped boxes are assigned to the day they close.
  - Docs explain that the wrapped start day comes from the last known closed D1 candle.
  - Docs state that the session filter gates entries, not box construction.
- **Validation**:
  - Manual documentation review.

### Task 4.2: Keep Frontend Status Labels Stable
- **Location**: `services/frontend/pandora_box_visualization.mqh`, `services/frontend/pandora_box_panel.mqh`
- **Description**: Avoid changing successful status text unless needed. Only ensure `INVALID WINDOW` is reserved for malformed ranges, not valid wrapped ranges.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Valid wrapped range displays normal Pandora lifecycle text.
  - Bad input still displays `PANDORA INVALID WINDOW`.
  - Invalid historical boxes remain marked with the current simple `INV` label.
- **Validation**:
  - Manual visual Strategy Tester review.

### Task 4.3: Update `AGENTS.md` If Behavior Is Accepted
- **Location**: `AGENTS.md`
- **Description**: Add one concise note under Pandora/frontend or workflow notes describing wrapped Pandora box support and the session filter boundary.
- **Dependencies**: Sprint 4.1
- **Acceptance Criteria**:
  - Future agents see the intended wrapped-window behavior.
  - The include-order and service-boundary guidance remains unchanged.
- **Validation**:
  - Manual documentation review.

## Manual Validation Strategy
- Use MT5 Strategy Tester visual mode; no automated tests or compile runs are required from the implementation agent.
- Validate same-day regression:
  - `Pandora_Box_Time_Range = "12:00-13:30"`.
  - Confirm the box remains pending before close, computes after close, and keeps previous high/low behavior.
- Validate overnight runtime:
  - `Pandora_Box_Time_Range = "23:00-00:10"`.
  - On a date like `2026-03-24`, confirm the box uses the last known closed D1 candle day late window through current-day early window and no longer says `INVALID WINDOW`.
  - On a Monday or market-open scenario, confirm the start date follows `iTime(_Symbol, PERIOD_D1, 1)` rather than calendar Sunday if the broker/symbol does not expose a Sunday D1 bar.
- Validate invalid inputs:
  - `"00:10-00:10"` remains invalid unless product requirements change.
  - Malformed strings still show `PANDORA INVALID WINDOW`.
- Validate session filter interaction:
  - With `Pandora_Box_Use_Session_Filter = true`, confirm a valid box can compute while entries are blocked outside enabled sessions.
  - Confirm entries resume only inside an enabled session window.
- Validate season handling:
  - Check `Session_Time_Dst_Mode = DST_MODE_AUTO_EXNESS` around `2026-03-08` and `2026-11-01`.
  - Check `DST_MODE_MANUAL` with `Session_Time_Dst_Manual_Offset_Minutes = 60`.
  - Confirm historical rectangles for days on different sides of a DST boundary do not shift by the wrong hour.

## Potential Risks & Gotchas
- Wrapped-window ownership is the most important product decision. This plan assumes `23:00-00:10` belongs to the day it closes, not the day it opens.
- `start == end` could mean a full-day box in the session filter, but this plan keeps it invalid for Pandora because a full-day breakout box would blur daily reset and trade timing semantics.
- Weekend data can be sparse. Using the previous D1 anchor handles broker-specific Friday/Saturday/Sunday behavior, but `CopyRates()` may still return no data if the requested intraday span has no bars.
- `TimeCurrent()` is server-time based. The plan preserves that model and only adds a reference-time offset helper for Pandora window conversion.
- Historical snapshots currently use up to 8 D1 anchors. If a broker's D1 bars are non-standard, rectangles will follow broker history, not local calendar expectations.

## Rollback Plan
- Revert the parser/state changes in `services/trading_signals/pandora_box_state.mqh` to restore same-day-only behavior.
- Revert the reference-time offset helper while keeping the original `ResolveTradingTimeOffsetMinutes()` function.
- Revert documentation updates if the product decision changes.
- No database migrations, generated artifacts, or test harness files are involved.
