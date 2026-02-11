# Pandora Box Strategy Inputs Guide

This guide documents the configurable fields under `"+= Pandora Box Strategy =+"` in `services/trading_management/ea_inputs.mqh` so users can set up the EA safely and consistently.

## How Pandora Works
- The EA builds a daily price box from `Pandora_Box_Time_Range`.
- After the window closes, it watches for breakout above/below the box with `Pandora_Box_Offset_Points`.
- On breakout, it opens a single-direction grid using `Pandora_Points_SL` / `Pandora_Points_TP` and current lot settings.
- The day stops based on `Pandora_Box_Stop_On_First_Win` and `Pandora_Box_Stop_After_Sides`.

## Input Reference

| Input | Default | What it does | Recommended usage |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Box build window. Format must be `HH:MM-HH:MM` with start `<` end (same day only). | Use liquid market windows. Keep 60-180 minutes. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Max allowed box range in points. If exceeded, box is invalid for the day. `0` disables this filter. | Start with a symbol-specific cap (for example 150-300 points) to avoid oversized days. |
| `Pandora_Box_Offset_Points` | `50.0` | Breakout buffer added above box high / below box low. | Keep non-zero to reduce false breaks; broker minimum distance is enforced. |
| `Pandora_Points_SL` | `100.0` | Stop distance in points for Pandora entries. Also used as base spacing for Pandora order construction. | Keep `> 0`. Tune per symbol volatility. |
| `Pandora_Points_TP` | `100.0` | Take-profit distance in points for Pandora entries. If `<= 0`, TP is not set for Pandora entries. | Use positive values for explicit TP control. |
| `Pandora_Box_Stop_On_First_Win` | `true` | Ends Pandora for the day after first profitable side closes. | `true` for conservative daily pacing. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Allowed breakout direction(s): `BOTH_DIRECTION`, `BULLISH_DIRECTION`, `BEARISH_DIRECTION`. | Restrict to one side when running directional bias. |
| `Pandora_Box_Stop_After_Sides` | `true` | In two-sided mode, stop after both sides are consumed. In one-sided mode, stop after the configured side is consumed. | Keep `true` unless you intentionally want repeated side attempts disabled elsewhere. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session manager gating to Pandora attempts. | Keep `true` if session windows are part of risk policy. |
| `Pandora_Box_Enable_Visualization` | `true` | Draws box and breakout lines on chart. | Keep enabled during tuning/debugging. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Sends SL/TP directly to broker at order open. If `false`, EA manages SL/TP checks internally in controller logic. | Keep `true` for broker-side protection. |
| `Enable_Chart_Levels` | `true` | Enables chart level overlays used by frontend visualization. | Keep enabled in manual monitoring; can disable for cleaner charts. |

## Quick Setup Profiles

### Profile A: Conservative Intraday
- `Pandora_Box_Time_Range = "08:00-09:30"`
- `Pandora_Box_Max_Range_Points = 180`
- `Pandora_Box_Offset_Points = 40`
- `Pandora_Points_SL = 120`
- `Pandora_Points_TP = 120`
- `Pandora_Box_Stop_On_First_Win = true`
- `Pandora_Box_Direction_Mode = BOTH_DIRECTION`

### Profile B: Trend-Biased Session
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Box_Offset_Points = 60`
- `Pandora_Points_SL = 140`
- `Pandora_Points_TP = 180`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (or `BEARISH_DIRECTION`)

## Validation Checklist Before Live Run
- Confirm time range format is valid (`HH:MM-HH:MM`) and start is earlier than end.
- Confirm `Pandora_Points_SL > 0`.
- If using max-range filter, confirm value fits symbol volatility.
- Confirm direction mode aligns with your bias.
- Confirm session filter windows are configured when `Pandora_Box_Use_Session_Filter = true`.
- Check chart status text for `PANDORA INVALID WINDOW` or `PANDORA INVALID BOX`.

## Notes
- `Pandora_Box_Enable` and visualization colors/styles are currently code-level fields (not MT5 `input` fields) in this branch.
- If you need them user-editable in the Inputs panel, promote them to `input` variables in `ea_inputs.mqh`.
