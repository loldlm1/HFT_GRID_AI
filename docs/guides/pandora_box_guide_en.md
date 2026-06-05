# **Pandora Box: Installation Guide and User Manual**

## 1. Introduction
Welcome to the official installation and usage guide for **Pandora Box**, an EA (Expert Advisor) for MetaTrader 5 focused on breakout-based execution with controlled risk and licensing checks.

---

## 2. Installation Video

Before proceeding, we recommend watching the following installation video, which explains step-by-step how to set up **Pandora Box** on your platform:

[[youtube:https://youtu.be/UtQj0znIjoY]]

---

## 3. Installation Guide

Follow these detailed steps to install and configure **Pandora Box** in MetaTrader 5:

### 1. **Download Pandora Box EA**
   - Download the **Pandora Box EA** file from our official website or the provided source.

### 2. **Copy Pandora Box EA**
   - Once downloaded, copy the file to your clipboard.

### 3. **Open MetaTrader 5 (MT5)**
   - Open your **MetaTrader 5** platform.

### 4. **Open Data Folders**
   - Click on "File" in the top bar of MetaTrader 5 and select "Open Data Folder."

### 5. **Access MQL5**
   - In the pop-up window, open the **MQL5** folder.

### 6. **Access Experts**
   - Within the **MQL5** folder, open the **Experts** folder.

### 7. **Paste Pandora Box EA**
   - Paste the **Pandora Box EA** file that you previously copied into this folder.

### 8. **Close Data Folders**
   - Close the Data Folder window.

### 9. **Update Expert Advisors**
   - Go back to MetaTrader 5's Navigator, right-click, and select "Refresh" under the **Expert Advisors** section.

### 10. **Enable WebRequest for Online License Validation**
   - In MT5, go to **Tools -> Options -> Expert Advisors**.
   - Enable **Allow WebRequest for listed URL**.
   - Add this exact URL to the allowed list: `https://tradingsniperpanel.com`.

### 11. **Drag Pandora Box EA to the Chart**
   - Find **Pandora Box EA** in the list of Expert Advisors and drag it onto the preferred chart.

### 12. **Enter License**
   - You will be prompted to enter a license key. Paste it exactly as provided.

### 13. **Ready to Trade**
   - **Pandora Box** is installed and ready to start trading.

---

## 4. User Guide: Configurable Parameters

**Pandora Box** uses configurable inputs to control box construction, breakouts, risk behavior, and execution.

### **How Pandora Box Works**
- The EA builds a daily price box from `Pandora_Box_Time_Range`.
- Same-day ranges use `start < end`; overnight ranges use `start > end`, belong to the day they close, and start from the last known closed D1 candle day. Identical start/end values are invalid.
- After the window closes, it computes breakout prices using `Pandora_Box_Offset_Points`.
- `Pandora_Box_Entry_Type = ENTRY_WICK_TYPE` keeps the current tick/current-price breakout behavior. `ENTRY_BODY_TYPE` waits for the selected body timeframe's last closed candle to close outside the offset breakout level.
- Body entries use inclusive checks (`close_1 >= breakout_high_price` bullish, `close_1 <= breakout_low_price` bearish) and consume each qualifying closed candle once per direction, even if a later guard blocks the order.
- If the selected trigger breaks above/below and all local admission guards pass (direction, session, daily limits, concurrency), Pandora reserves the entry budget. The active local entry is anchored to broker-realistic execution: real broker fill first, otherwise current executable Bid/Ask after spread is inside range.
- Re-entry on each side is re-armed only after `close_1` returns inside the raw box. Wick mode uses the Pandora box timeframe; body mode uses `Pandora_Box_Entry_Body_Timeframe`.
- `Pandora_Box_Max_Entries` controls the Pandora entry budget (`0` means unlimited). A high-spread breakout can reserve the budget while waiting for spread to return inside range.
- If the budget is reached while local entries remain open, status shows `PANDORA WAIT_CLOSE`; after local closure, it transitions to `PANDORA DONE`.
- `Pandora_Box_Entry_Count_Mode` only controls the `counted` analytics counter; it does not replace the opened-entry budget.
- `Pandora_Box_Set_Broker_SLTP` is an extra broker-side protection layer. Exact Pandora SL/TP remains local and is calculated from the active broker-realistic entry.
- Broker SL/TP can be wider temporarily when broker stops/freeze rules require it, then tightened later when the server permits the exact local targets.
- If spread is above range at breakout, Pandora waits before creating the active local entry. If invalid stops, volume, margin, or another operable broker rule blocks the send after a broker-realistic anchor exists, Pandora keeps the local entry alive as `local_rejected` until local SL/TP/BE/trailing logic closes it. Market closed/disabled states are not simulated as normal trades.
- A successful retry replaces any previous simulated local anchor with the real broker fill, recalculates local SL/TP/trailing, and redraws the marker from the real entry.
- Chart trade markers draw active broker-realistic entries. Executed broker entries use labels such as `20$ (Posicion ejecutada)`; blocked/rejected entries use labels such as `10$ (Posicion local - ERR_Stops)`, `ERR_Volumen`, or `ERR_Margen`.

### **Runtime Identity, Order Comments, and Status Panel**
- In live mode, Pandora Box uses the backend-approved instance trade magic after license verification. `Custom_Magic` remains useful for Strategy Tester, but live trading does not rely on random magic.
- `EA_Instance_Id` can be left empty so the EA persists a chart-instance id locally. Set it manually only when you intentionally need the same instance identity after reinstall or migration.
- Attach each production chart as its own EA instance. Two charts in the same terminal should show different runtime magic values and should not manage each other's positions.
- New broker comments use the lowercase format `pandora_box_pos_n`, such as `pandora_box_pos_1`.
- Local-rejected entries are local EA state, not broker positions. Keep the rejection reason in local reporting and do not infer broker execution from a local marker.
- If MT5 Algo Trading, EA trading, or account expert trading is disabled, the EA shows disabled/platform status and skips broker actions until permissions return. Broker-side SL/TP remains the only active protection while disabled.
- The panel and Strategy Tester comment show `Error: OK`, `Error: ACTIVE ...`, or `Last error: ...`. This label is informational only and does not change trading decisions.

---

### **Input Parameters**

| **Parameter** | **Default Value** | **Description** | **Recommended Usage** |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Box construction window. Format: `HH:MM-HH:MM`; use `start < end` for same-day windows or `start > end` for overnight windows such as `23:00-00:10`. | Use liquid market windows (60-180 minutes). |
| `Pandora_Box_Stop_On_First_Win` | `true` | Ends Pandora for the day after first profitable closure. | Keep `true` for conservative pacing. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Allowed breakout side(s): both, bullish only, or bearish only. | Restrict to one side only with directional conviction. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session-time filters to Pandora attempts. | Keep `true` when session policy is part of risk management. |
| `Pandora_Box_Enable_Visualization` | `true` | Draws the Pandora chart frontend: current box/breakout guides plus up to 8 day-zones (current day + previous 7 trading days). Invalid historical days keep the same DimGray fill and show a simple label. | Keep enabled during setup/tuning. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Adds broker-side SL/TP protection when opening/modifying positions. Exact Pandora SL/TP is still enforced locally from the active broker-realistic entry; broker stops can be wider temporarily and tightened later. | Keep `true` for extra server-side protection, but validate source-of-truth SL/TP behavior in tester. |
| `Pandora_Box_Entry_Type` | `ENTRY_WICK_TYPE` | Entry trigger style. `ENTRY_WICK_TYPE` uses live tick/current-price breakout; `ENTRY_BODY_TYPE` requires a closed candle outside the offset breakout level. | Keep `WICK` for legacy behavior; use `BODY` to reduce wick-only breaks. |
| `Pandora_Box_Entry_Body_Timeframe` | `PERIOD_M5` | Standard MT5 timeframe used by `ENTRY_BODY_TYPE` for closed-candle breakout and rearm checks. `PERIOD_CURRENT` resolves through the Pandora/strategy timeframe fallback. | Start with `PERIOD_M5` for deterministic body confirmation. |
| `Enable_Chart_Levels` | `true` | Enables the fixed frontend overlays. With `Enable_Chart_Summary` also active, live charts show the compact top-left panel instead of live `Comment()` text; Strategy Tester still uses comment fallback. Pandora trade markers draw local and broker-executed entries. | Keep enabled for manual monitoring. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Trailing behavior: `OFF` or `PANDORA_RISK_TRAILING_STEP_TP`. | Start with `OFF`; use `STEP_TP` after tester validation. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Lot mode: fixed lot, percentage-based, or currency-based. | Use fixed lot initially; budget modes require calibration. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Size input consumed by the selected lot mode. | Start small and increase gradually. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Maximum allowed box range in points (`0` disables filter). | Set a cap to skip oversized days. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Interprets offset/SL/TP as points or `%` of box range. | Prefer points first; use `%` for adaptive scaling. |
| `Pandora_Box_Offset_Points` | `1.0` | Breakout buffer distance from box high/low. | Keep non-zero to reduce false breaks. |
| `Pandora_Points_SL` | `100.0` | Stop distance for Pandora entries. | Must be `> 0`; tune by symbol. |
| `Pandora_Points_TP` | `100.0` | Take-profit distance for Pandora entries. | Keep positive unless trailing-only exit is intended. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controls `counted` analytics: all (`SL/TP/BE`), `SL+BE`, or `TP+BE`. | Use `OFF` for full diagnostics. |
| `Pandora_Box_Max_Entries` | `2` | Broker-realistic Pandora-entry budget per day/window (`0` = unlimited). Pending spread admission and broker-blocked/rejected entries still count. | Keep low (`1-2`) unless broader protections are strict. |

---

## 5. Quick Setup Profiles

### **Profile A: Conservative Intraday**
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

### **Profile B: Trend Session**
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

---

## 6. Validation Checklist Before Live Run
Before running **Pandora Box** on a live account, verify:

- The time range format is valid (`HH:MM-HH:MM`), using `start < end` for same-day boxes or `start > end` for overnight boxes.
- `Pandora_Points_SL > 0`.
- If using `%` mode, offset/SL/TP percentages are realistic for the symbol.
- Direction mode matches your market bias.
- `Pandora_Box_Max_Entries` matches the intended Pandora entry budget.
- Local-rejected scenarios are understood: stops/volume/margin rejection can still leave one broker-realistic local entry alive until local SL/TP/BE/trailing closes it.
- Broker-side SL/TP is validated as extra protection only; local exact SL/TP remains based on the active broker fill or simulated anchor even when broker stops are temporarily wider.
- Session filters are configured if `Pandora_Box_Use_Session_Filter = true`.
- `Allow WebRequest for listed URL` is enabled with `https://tradingsniperpanel.com`.
- Each production chart shows its own backend-approved runtime magic and ignores positions from other charts/symbols.
- New orders show comments like `pandora_box_pos_1`.
- MT5 Algo Trading off shows disabled/platform status and stops new order, close, partial close, hedge, and SL/TP modification attempts.
- The panel/tester comment shows `Error: OK` in normal operation and a useful active/last error after a safe rejection test.
- Chart status does not show `PANDORA INVALID WINDOW` or `PANDORA INVALID BOX`.

---

## 7. License and WebRequest Troubleshooting
If WebRequest is not configured, online license verification can fail and the EA can remove itself after initialization/refresh checks.

### Common symptoms
- License validation fails immediately after attaching the EA.
- The EA stops running and logs a license connection/validation error.

### Fix path (MT5)
1. Open **Tools -> Options -> Expert Advisors**.
2. Enable **Allow WebRequest for listed URL**.
3. Add exactly: `https://tradingsniperpanel.com`.
4. Reattach the EA and enter the license key again.
