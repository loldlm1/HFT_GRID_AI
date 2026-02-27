# Pandora Box Strategy Inputs Guide

This guide documents the MT5 `input` fields used by Pandora Box in `services/trading_management/ea_inputs.mqh` under both groups:
- `"+= Pandora Box Strategy +="`
- `"+= Pandora Risk Management Settings +="`

Use this as the source of truth when configuring the EA in the Inputs panel.

## How Pandora Works
- The EA parses `Pandora_Box_Time_Range` (`HH:MM-HH:MM`, same day, start `<` end) and builds a daily box (`high/low`) after the window closes.
- Breakout triggers are computed with `Pandora_Box_Offset_Points` above the box high and below the box low.
- If `Pandora_Box_Max_Range_Points > 0`, the day is invalid when the box range exceeds that limit.
- Direction filtering is controlled by `Pandora_Box_Direction_Mode`.
- After each close, re-entry on that direction requires `close_1` to return inside the box before a new entry is allowed.
- `Pandora_Box_Max_Entries` is an opened-entry budget (`0` means unlimited). When budget is reached and positions are still open, status becomes `PANDORA WAIT_CLOSE`; it becomes `PANDORA DONE` after budgeted entries are closed.
- `Pandora_Box_Entry_Count_Mode` affects the `counted` analytics counter only (`SL`/`TP`/`BE` counting), not the opened-entry budget.
- `Pandora_Box_Stop_On_First_Win = true` finishes the day after the first profitable Pandora closure.
- `Pandora_Points_Value_Mode` decides whether offset/SL/TP values are raw points or percentages of the current box range.
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP` disables fixed TP and advances SL in milestones.
- `Pandora_Box_Set_Broker_SLTP` toggles broker-side SL/TP placement vs EA-managed local checks.

## Input Reference

| Input | Default | What it does | Recommended usage |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Daily box build window. Must be `HH:MM-HH:MM`, same day, start `<` end. | Use liquid market windows; usually 60-180 minutes. |
| `Pandora_Box_Stop_On_First_Win` | `true` | Ends Pandora for the day after first profitable closure. | Keep `true` for conservative pacing. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Allowed side(s): `BOTH_DIRECTION`, `BULLISH_DIRECTION`, `BEARISH_DIRECTION`. | Restrict to one side only with a clear directional bias. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session manager gating to Pandora attempts. | Keep `true` if session windows are part of risk policy. |
| `Pandora_Box_Enable_Visualization` | `true` | Draws Pandora box and breakout lines on chart. | Keep enabled for setup and troubleshooting. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Sends SL/TP at broker when opening/modifying positions. If `false`, EA enforces SL/TP in controller logic. | Keep `true` for broker-side protection. |
| `Enable_Chart_Levels` | `true` | Enables chart overlays used by the frontend summary/levels. | Keep enabled while monitoring manually. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Trailing mode: `OFF` keeps fixed TP/SL; `PANDORA_RISK_TRAILING_STEP_TP` trails SL in TP-like steps and uses no hard TP price. | Start with `OFF`; use `STEP_TP` only after tester validation. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Lot calculation mode: fixed lot, percentage-based, or currency-based. | Fixed lot for stable behavior; budget-based only with risk calibration. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Size parameter used by the selected lot mode. | Keep small for first live runs and scale gradually. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Max allowed box range in points. `0` disables filter. | Use a symbol-specific cap to avoid oversized range days. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Distance mode for offset/SL/TP: raw points or `%` of current box range. | Prefer `POINTS` initially; use `%` for volatility-adaptive behavior. |
| `Pandora_Box_Offset_Points` | `1.0` | Breakout buffer distance from box high/low (interpreted by points value mode). | Keep non-zero to reduce false breakouts. |
| `Pandora_Points_SL` | `100.0` | Pandora stop distance (also base spacing reference for Pandora order construction). | Must stay `> 0`; tune by symbol volatility. |
| `Pandora_Points_TP` | `100.0` | Pandora take-profit distance. In step trailing mode TP price is not set. | Use positive values unless strategy explicitly relies on trailing-only exits. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controls `counted` metric: `OFF` counts `SL`/`TP`/`BE`, `ON_SL` counts `SL`+`BE`, `ON_TP` counts `TP`+`BE`. | Use `OFF` for full analytics, filtered modes for targeted diagnostics. |
| `Pandora_Box_Max_Entries` | `2` | Opened-entry budget per Pandora day/window (`0` = unlimited). | Keep low (`1-2`) unless broader protections are strict. |

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
- Confirm `Pandora_Box_Time_Range` format is valid (`HH:MM-HH:MM`) and start is earlier than end.
- Confirm `Pandora_Points_SL > 0` for the selected points mode.
- If `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_BOX_PERCENT`, verify percent values are realistic for your symbol.
- If using `Pandora_Box_Max_Range_Points`, ensure the cap matches symbol volatility.
- Confirm `Pandora_Box_Max_Entries` (opened budget) and `Pandora_Box_Entry_Count_Mode` (analytics counter) are not conflated.
- Confirm session filters are configured when `Pandora_Box_Use_Session_Filter = true`.
- Decide whether broker-side protection is required (`Pandora_Box_Set_Broker_SLTP = true`).
- Check chart status text for `PANDORA INVALID WINDOW`, `PANDORA INVALID BOX`, `PANDORA WAIT_CLOSE`, and `PANDORA DONE`.

## Notes
- `Pandora_Box_Enable` and visualization colors/styles are code-level fields (not MT5 `input` fields) in this branch.
- If you need those values editable from the Inputs panel, promote them to `input` variables in `ea_inputs.mqh`.
