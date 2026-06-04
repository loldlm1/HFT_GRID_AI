# Pandora Box Strategy Inputs Guide

This guide documents the MT5 `input` fields used by Pandora Box in `services/trading_management/ea_inputs.mqh` under both groups:
- `"+= Pandora Box Strategy +="`
- `"+= Pandora Risk Management Settings +="`

Use this as the source of truth when configuring the EA in the Inputs panel.

## How Pandora Works
- The EA parses `Pandora_Box_Time_Range` (`HH:MM-HH:MM`) and builds a daily box (`high/low`) after the window closes.
- Same-day windows use `start < end`; overnight windows use `start > end` and belong to the day they close. The overnight start day comes from the last known closed D1 candle, so broker-specific Friday/Saturday/Sunday history is respected. `start == end` is invalid.
- Breakout triggers are computed with `Pandora_Box_Offset_Points` above the box high and below the box low.
- `Pandora_Box_Entry_Type = ENTRY_WICK_TYPE` keeps the legacy tick/current-price breakout. `ENTRY_BODY_TYPE` requires the selected body timeframe's last closed candle to close outside the offset breakout level.
- Body entries use inclusive checks (`close_1 >= breakout_high_price` for bullish, `close_1 <= breakout_low_price` for bearish) and consume each qualifying closed candle once per direction, even if a later guard blocks the order.
- When the selected trigger passes local admission guards, Pandora opens a deterministic local entry before the broker send result is known.
- `Pandora_Box_Use_Session_Filter` gates Pandora entry attempts only; it does not decide whether the box construction window is valid.
- If `Pandora_Box_Max_Range_Points > 0`, the day is invalid when the box range exceeds that limit.
- Direction filtering is controlled by `Pandora_Box_Direction_Mode`.
- After each close, re-entry on that direction requires `close_1` to return inside the raw box before a new entry is allowed. Wick mode uses the Pandora box timeframe; body mode uses `Pandora_Box_Entry_Body_Timeframe`.
- `Pandora_Box_Max_Entries` is a deterministic local-entry budget (`0` means unlimited). A broker-blocked or broker-rejected attempt still consumes this budget because the EA keeps the local operation alive.
- When budget is reached and local entries are still open, status becomes `PANDORA WAIT_CLOSE`; it becomes `PANDORA DONE` after those budgeted local entries are closed by local SL/TP, BE, trailing, or broker close.
- `Pandora_Box_Entry_Count_Mode` affects the `counted` analytics counter only (`SL`/`TP`/`BE` counting), not the opened-entry budget.
- `Pandora_Box_Stop_On_First_Win = true` finishes the day after the first profitable Pandora closure.
- `Pandora_Points_Value_Mode` decides whether offset/SL/TP values are raw points or percentages of the current box range.
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP` disables fixed TP and advances SL in milestones.
- `Pandora_Box_Set_Broker_SLTP` adds broker-side SL/TP protection when possible, but the exact Pandora SL/TP remains local and authoritative for lifecycle and statistics.
- If spread, invalid stops, volume, margin, market state, or another broker rule blocks the send, the entry is treated as `local_rejected` for local reporting and remains active until exact local SL/TP or BE logic closes it.
- Broker SL/TP may be wider than the configured Pandora distances temporarily when broker stops/freeze rules require it. The EA keeps the exact local targets and tries to tighten broker protection when the server permits it.
- Chart trade markers always draw the local entry path. Executed broker entries use labels such as `20$ (Posicion ejecutada)`; blocked/rejected entries use labels such as `10$ (Posicion local - ERR_Spread)`, `ERR_Stops`, `ERR_Volumen`, or `ERR_Margen`.

## Input Reference

| Input | Default | What it does | Recommended usage |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Daily box build window. Use `start < end` for same-day windows or `start > end` for overnight windows such as `23:00-00:10`; `start == end` is invalid. | Use liquid market windows; usually 60-180 minutes. |
| `Pandora_Box_Stop_On_First_Win` | `true` | Ends Pandora for the day after first profitable closure. | Keep `true` for conservative pacing. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Allowed side(s): `BOTH_DIRECTION`, `BULLISH_DIRECTION`, `BEARISH_DIRECTION`. | Restrict to one side only with a clear directional bias. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session manager gating to Pandora attempts. | Keep `true` if session windows are part of risk policy. |
| `Pandora_Box_Enable_Visualization` | `true` | Draws the Pandora visual layer: current box/breakout guides plus up to 8 day-zones (current day + previous 7 trading days). Invalid historical days keep the same DimGray fill and use a simple label. | Keep enabled for setup and troubleshooting. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Adds broker-side SL/TP protection when opening/modifying positions. The exact Pandora SL/TP is still enforced locally; broker stops can be wider temporarily and tightened later. | Keep `true` for extra server-side protection, but validate local SL/TP behavior in tester. |
| `Pandora_Box_Entry_Type` | `ENTRY_WICK_TYPE` | Entry trigger style. `ENTRY_WICK_TYPE` uses live tick/current-price breakout; `ENTRY_BODY_TYPE` requires a closed candle outside the offset breakout level. | Keep `WICK` for legacy behavior; use `BODY` to reduce wick-only breaks. |
| `Pandora_Box_Entry_Body_Timeframe` | `PERIOD_M5` | Standard MT5 timeframe used by `ENTRY_BODY_TYPE` for closed-candle breakout and rearm checks. `PERIOD_CURRENT` resolves through the Pandora/strategy timeframe fallback. | Start with `PERIOD_M5` for deterministic body confirmation. |
| `Enable_Chart_Levels` | `true` | Enables the fixed chart frontend. When `Enable_Chart_Summary` is also active, live charts use the compact top-left panel instead of live `Comment()` text, while Strategy Tester keeps the text fallback. Pandora trade markers draw local and broker-executed entries. | Keep enabled while monitoring manually. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Trailing mode: `OFF` keeps fixed TP/SL; `PANDORA_RISK_TRAILING_STEP_TP` trails SL in TP-like steps and uses no hard TP price. | Start with `OFF`; use `STEP_TP` only after tester validation. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Lot calculation mode: fixed lot, percentage-based, or currency-based. | Fixed lot for stable behavior; budget-based only with risk calibration. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Size parameter used by the selected lot mode. | Keep small for first live runs and scale gradually. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Max allowed box range in points. `0` disables filter. | Use a symbol-specific cap to avoid oversized range days. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Distance mode for offset/SL/TP: raw points or `%` of current box range. | Prefer `POINTS` initially; use `%` for volatility-adaptive behavior. |
| `Pandora_Box_Offset_Points` | `1.0` | Breakout buffer distance from box high/low (interpreted by points value mode). | Keep non-zero to reduce false breakouts. |
| `Pandora_Points_SL` | `100.0` | Pandora stop distance (also base spacing reference for Pandora order construction). | Must stay `> 0`; tune by symbol volatility. |
| `Pandora_Points_TP` | `100.0` | Pandora take-profit distance. In step trailing mode TP price is not set. | Use positive values unless strategy explicitly relies on trailing-only exits. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controls `counted` metric: `OFF` counts `SL`/`TP`/`BE`, `ON_SL` counts `SL`+`BE`, `ON_TP` counts `TP`+`BE`. | Use `OFF` for full analytics, filtered modes for targeted diagnostics. |
| `Pandora_Box_Max_Entries` | `2` | Deterministic local-entry budget per Pandora day/window (`0` = unlimited). Broker-blocked and broker-rejected local entries still count. | Keep low (`1-2`) unless broader protections are strict. |

## Runtime Identity, Order Comments, And Status Panel

These fields and labels are not Pandora entry rules, but they are required for safe production operation:

| Item | What it means | Validation |
|---|---|---|
| `EA_Instance_Id` | Optional stable id for this chart EA instance. Leave empty to let the EA persist one locally; set manually only when you intentionally want the same chart instance identity after reinstall/migration. | Two charts in the same terminal should display different runtime magic values after backend validation. |
| `Custom_Magic` | Tester-friendly magic override. In live mode, the backend-issued instance trade magic is authoritative after license verification. | Do not rely on random live magic. If live backend magic is missing or invalid, initialization fails closed. |
| `pandora_box_pos_n` comments | New broker comments for Pandora/grid positions. `n` counts position-opening levels, not virtual grid levels. Hedge orders reserve a deterministic `pandora_box_pos_n` outside normal level numbering. | Open a demo/tester position and confirm the broker comment uses the lowercase format. |
| Local rejected entries | A local Pandora entry can remain active even when the broker send is blocked or rejected. Keep the rejection reason as local state (`local_rejected`) and do not assume broker history contains a matching position. | Force spread/stops/volume/margin rejection in tester and confirm the local entry remains alive until local SL/TP/BE closes it. |
| Pandora broker stop status | `Stops broker amplios` means broker protection is wider than the exact local target; `Stops broker objetivo` means broker-side protection matches the local target. `Stops broker fallidos` is non-fatal for the local lifecycle. | With `Pandora_Box_Set_Broker_SLTP = true`, confirm local SL/TP closes remain exact even while broker stops are pending/wide/failed. |
| MT5 Algo Trading status | When MT5 Algo Trading, EA trading, or account expert trading is disabled, the EA keeps rates/UI fresh but skips signal/order/close/modify/force-close actions. Broker-side SL/TP remains the only active protection while disabled. | Toggle Algo Trading off/on on a demo chart and confirm no repeated trade errors occur while disabled. |
| Error label | The chart panel and Strategy Tester comment show `Error: OK`, `Error: ACTIVE ...`, or `Last error: ...` for order-send failures, guardrail blocks, broker disabled/close-only, margin/no-money, SL/TP failures, close failures, and platform-disabled state. | Treat the label as informational only; it does not change trading decisions. |

## Quick Setup Profiles

### Profile A: Conservative Intraday
- `Pandora_Box_Time_Range = "08:00-09:30"`
- `Pandora_Box_Max_Range_Points = 180`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_POINTS`
- `Pandora_Box_Offset_Points = 20`
- `Pandora_Points_SL = 120`
- `Pandora_Points_TP = 120`
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_OFF`
- `Pandora_Box_Stop_On_First_Win = true`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_OFF`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BOTH_DIRECTION`

### Profile B: Trend-Biased Session
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_BOX_PERCENT`
- `Pandora_Box_Offset_Points = 10` (10% of box range)
- `Pandora_Points_SL = 40` (40% of box range)
- `Pandora_Points_TP = 70` (70% of box range)
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_ON_SL`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (or `BEARISH_DIRECTION`)

## Validation Checklist Before Live Run
- Confirm `Pandora_Box_Time_Range` format is valid (`HH:MM-HH:MM`), using `start < end` for same-day boxes or `start > end` for overnight boxes.
- If `Pandora_Box_Entry_Type = ENTRY_BODY_TYPE`, confirm `Pandora_Box_Entry_Body_Timeframe` matches the candle close you want to validate.
- Confirm `Pandora_Points_SL > 0` for the selected points mode.
- If `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_BOX_PERCENT`, verify percent values are realistic for your symbol.
- If using `Pandora_Box_Max_Range_Points`, ensure the cap matches symbol volatility.
- Confirm `Pandora_Box_Max_Entries` (opened budget) and `Pandora_Box_Entry_Count_Mode` (analytics counter) are not conflated.
- Confirm session filters are configured when `Pandora_Box_Use_Session_Filter = true`.
- Decide whether broker-side protection is required (`Pandora_Box_Set_Broker_SLTP = true`).
- For production multi-chart use, confirm every attached chart shows a distinct backend-approved magic and that each chart ignores positions from other symbols/charts.
- Toggle MT5 Algo Trading off and confirm the panel/tester comment shows disabled/platform status while broker actions stop.
- Confirm new positions use comments like `pandora_box_pos_1`.
- Confirm the error label reads `Error: OK` during normal operation and becomes `Error: ACTIVE ...` or `Last error: ...` after a safe forced rejection test.
- Check chart status text for `PANDORA INVALID WINDOW`, `PANDORA INVALID BOX`, `PANDORA WAIT_CLOSE`, and `PANDORA DONE`.

## Manual And Tester Regression Checklist

Run these scenarios manually in Strategy Tester visual mode or on a demo chart when changing Pandora lifecycle, broker sends, stop safety, or chart markers. Use "Every tick based on real ticks" when spread, stop/freeze distance, or tick-level local SL/TP timing matters. Do not treat this as a headless MT5 matrix test requirement.

| Scenario | Inputs/setup | Expected logs/status | Expected chart label | Expected budget/statistics |
|---|---|---|---|---|
| High spread blocks broker send | `Pandora_Box_Max_Entries = 1`, valid box, breakout tick, and `Max_Spread` below observed spread. | `PANDORA_ENTRY_OPEN`, then active/last error reason such as `PANDORA_BROKER_SPREAD_BLOCK` or `GUARDRAIL_BLOCK`; no repeated send attempt for the same local entry. | Closed marker like `... (Posicion local - ERR_Spread)`. | `open=1/1`; next breakout on the same day does not create a second local entry until the first local entry closes. Broker history has no matching position. |
| Invalid broker stops | `Pandora_Box_Set_Broker_SLTP = true`, SL/TP distances that are unsafe for current broker stops/freeze constraints, otherwise valid breakout. | If send succeeds, stop sync status can be `Stops broker amplios`, `Stops broker pendientes`, or `Stops broker fallidos`; local lifecycle continues. If send fails, reason should include `ERR_Stops`. | Executed path: `... (Posicion ejecutada)`. Rejected path: `... (Posicion local - ERR_Stops)`. | Exact local SL/TP remains the statistics source. Broker stops can be wider temporarily and should tighten to `Stops broker objetivo` when legal. |
| Invalid volume or no money | Set lot mode/size above symbol/account limits or margin availability. Keep `Debug_Stop_On_Negative_Equity` behavior in mind during tester runs. | Broker rejection/guard reason includes `ERR_Volumen` or `ERR_Margen`; no repeated send attempt after the local entry is active. | `... (Posicion local - ERR_Volumen)` or `... (Posicion local - ERR_Margen)`. | Local entry consumes `Pandora_Box_Max_Entries`; broker history has no matching position; local close outcome still updates local counters. |
| Broker success | Normal lot, legal stops, acceptable spread, valid breakout. | `PANDORA_ENTRY_OPEN`; broker status becomes executed; panel error returns to `Error: OK` after successful send/sync. | `... (Posicion ejecutada)`. | Local entry and broker position are aligned. Broker history contains the position/deal, while Pandora open/close/count metrics still come from local lifecycle. |
| Local-only SL close | Force a blocked/rejected local entry, then move price to exact local SL. | `PANDORA_ENTRY_CLOSE` with SL-like outcome; no broker close is required when ticket is `0`. | Negative marker like `... (Posicion local - ERR_Spread)` or the actual reject reason. | `closed_entries` increments; `counted_entries` follows `Pandora_Box_Entry_Count_Mode`; local loss is separate from broker history. |
| Local-only TP close | Force a blocked/rejected local entry, then move price to exact local TP. | `PANDORA_ENTRY_CLOSE` with TP-like outcome; `Pandora_Box_Stop_On_First_Win = true` can finish the day. | Positive marker like `... (Posicion local - ERR_Spread)` or the actual reject reason. | `closed_entries` increments; `PANDORA DONE` appears when budget/first-win rules require it; broker history has no matching profit. |
| Broker stop tightening | Successful broker entry where initial exact SL/TP is unsafe but wider broker protection is legal. Keep price moving until exact local targets become legal for broker modification. | Stop status starts as `Stops broker amplios` or pending, then becomes `Stops broker objetivo` after safe sync. Failed modify attempts should be non-fatal and throttled. | `... (Posicion ejecutada)`. | Local SL/TP does not move just because broker stops are wider. Statistics use exact local close price, not the temporary wider broker protection. |

## Notes
- `Pandora_Box_Enable` and visualization colors/styles are code-level fields (not MT5 `input` fields) in this branch.
- If you need those values editable from the Inputs panel, promote them to `input` variables in `ea_inputs.mqh`.
