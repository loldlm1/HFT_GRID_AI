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
- When the selected trigger passes local admission guards, Pandora reserves the Pandora entry budget. The active local entry is anchored to broker-realistic execution conditions: real broker fill first, otherwise current executable Bid/Ask after spread is inside range.
- `Pandora_First_Entry_Mode` is an integer depth input. `0` keeps the default behavior: the first real entry is admitted at the Pandora breakout.
- `Pandora_First_Entry_Mode = -1` opens the first entry locally only, from the current executable Bid/Ask, and never calls `OrderSend`.
- `Pandora_First_Entry_Mode = 1`, `2`, or higher tests same-direction deep entries. The EA observes the breakout locally first; if observation TP hits before the requested deep SL level, the opportunity is discarded as a local win. If the deep level hits first, the EA admits the real market entry through the existing broker-realistic path. Values above `20` clamp to `20`.
- Deep-entry observation uses a fixed TP invalidation level. In fixed-TP mode it uses `Pandora_Points_TP`; in `PANDORA_RISK_TRAILING_STEP_TP` mode it uses the same resolved distance as `Pandora_Points_SL`. Step trailing starts only after a real broker market entry is admitted.
- `Pandora_XBoost_Mode = PANDORA_XBOOST_TRAINING` keeps XBoost broker execution disabled and builds local idempotent statistics from the Pandora root and derived local branches.
- `Pandora_XBoost_Mode = PANDORA_XBOOST_INFERENCE` loads those statistics and may select one READY XBoost branch for real broker execution at a time. If no candidate qualifies, the branch remains local-only and still contributes statistics.
- XBoost is rooted in the first Pandora signal of the day. Use `Pandora_Box_Max_Entries = 1` when you want exactly one Pandora root and let `Pandora_XBoost_Max_Depth` control the maximum sequential XBoost broker decisions/trades derived from that root.
- XBoost never opens simultaneous real long and short positions. A new real XBoost branch can be selected only after the previous selected XBoost signal has closed.
- XBoost uses the existing Pandora fixed TP, BE, and step trailing rules; it does not add a separate trailing engine.
- `Pandora_Box_Use_Session_Filter` gates Pandora entry attempts only; it does not decide whether the box construction window is valid.
- Runtime performance gates are internal only. In Strategy Tester, idle chart/comment refresh is throttled by new chart bars, while active Pandora observations, broker retries, positions, closes, force-close states, and work-window transitions continue to use tick-level lifecycle checks.
- If `Pandora_Box_Max_Range_Points > 0`, the day is invalid when the box range exceeds that limit.
- Direction filtering is controlled by `Pandora_Box_Direction_Mode`.
- After each close, re-entry on that direction requires `close_1` to return inside the raw box before a new entry is allowed. Wick mode uses the Pandora box timeframe; body mode uses `Pandora_Box_Entry_Body_Timeframe`.
- `Pandora_Box_Max_Entries` is a broker-realistic Pandora-entry budget (`0` means unlimited). A breakout can reserve the budget while waiting for spread to return inside range, preventing duplicate re-entry ambiguity.
- When budget is reached and local entries are still open, status becomes `PANDORA WAIT_CLOSE`; it becomes `PANDORA DONE` after those budgeted local entries are closed by local SL/TP, BE, trailing, or broker close.
- `Pandora_Box_Entry_Count_Mode` affects the `counted` analytics counter only (`SL`/`TP`/`BE` counting), not the opened-entry budget.
- `Pandora_Box_Stop_On_First_Win = true` finishes the day after the first profitable Pandora closure.
- `Pandora_Points_Value_Mode` decides whether offset/SL/TP values are raw points or percentages of the current box range.
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP` disables fixed TP and advances SL in milestones.
- `Pandora_Box_Set_Broker_SLTP` adds broker-side SL/TP protection after a broker fill when possible, but exact Pandora SL/TP remains local and is calculated from the active source-of-truth entry.
- If spread is above range at breakout, Pandora waits before creating the active local entry; no marker or local SL/TP is created until spread returns inside range.
- Pandora broker-open `OrderSend` requests start with no initial SL/TP so broker stop/freeze constraints do not block the market entry. Attempt 8 becomes the final broker result if no request succeeds.
- Volume is refreshed and normalized while rebuilding every request. Local spread and margin admission guards remain definitive before a send; any retcode actually returned by `OrderSend`, including invalid volume, no money, market closed/disabled, close-only, or account/symbol restrictions, remains retryable until attempt 8 on eligible ticks.
- Pandora retries unsuccessful or unresolved broker market sends on consecutive eligible ticks, up to the configured attempt budget. Every retry rebuilds the request from the current tick, and a successful retry replaces the local anchor with the real broker fill, recalculates local SL/TP/trailing, and redraws the marker from the real entry.
- Broker SL/TP starts as pending/absent after the fill, then may become exact, wider than the configured Pandora distances, or failed while broker stops/freeze rules are enforced. The EA keeps the exact targets from the active source-of-truth entry and tries to tighten broker protection when the server permits it.
- Chart trade markers draw only active broker-realistic entries. Executed broker entries use labels such as `20$ (Posicion ejecutada)`; blocked/rejected entries use labels such as `10$ (Posicion local - ERR_Stops)`, `ERR_Volumen`, or `ERR_Margen`.

## Input Reference

| Input | Default | What it does | Recommended usage |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Daily box build window. Use `start < end` for same-day windows or `start > end` for overnight windows such as `23:00-00:10`; `start == end` is invalid. | Use liquid market windows; usually 60-180 minutes. |
| `Pandora_Box_Stop_On_First_Win` | `true` | Ends Pandora for the day after first profitable closure. | Keep `true` for conservative pacing. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Allowed side(s): `BOTH_DIRECTION`, `BULLISH_DIRECTION`, `BEARISH_DIRECTION`. | Restrict to one side only with a clear directional bias. |
| `Pandora_Box_Use_Session_Filter` | `true` | Applies session manager gating to Pandora attempts. | Keep `true` if session windows are part of risk policy. |
| `Pandora_Box_Enable_Visualization` | `true` | Draws the Pandora visual layer: current box/breakout guides plus up to 8 day-zones (current day + previous 7 trading days). Invalid historical days keep the same DimGray fill and use a simple label. | Keep enabled for setup and troubleshooting. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Adds broker-side SL/TP protection after broker fills and during later modify attempts. Opening market requests are sent without initial SL/TP; exact Pandora SL/TP is still enforced locally from the active broker-realistic entry. | Keep `true` for extra server-side protection, but validate source-of-truth SL/TP behavior in tester. |
| `Pandora_Box_Entry_Type` | `ENTRY_WICK_TYPE` | Entry trigger style. `ENTRY_WICK_TYPE` uses live tick/current-price breakout; `ENTRY_BODY_TYPE` requires a closed candle outside the offset breakout level. | Keep `WICK` for legacy behavior; use `BODY` to reduce wick-only breaks. |
| `Pandora_Box_Entry_Body_Timeframe` | `PERIOD_M5` | Standard MT5 timeframe used by `ENTRY_BODY_TYPE` for closed-candle breakout and rearm checks. `PERIOD_CURRENT` resolves through the Pandora/strategy timeframe fallback. | Start with `PERIOD_M5` for deterministic body confirmation. |
| `Enable_Chart_Levels` | `true` | Enables the fixed chart frontend. When `Enable_Chart_Summary` is also active, live charts use the compact top-left panel instead of live `Comment()` text, while Strategy Tester keeps the text fallback. Tester refresh is throttled while idle and resumes immediately for active Pandora lifecycle work. Pandora trade markers draw local and broker-executed entries. | Keep enabled while monitoring manually. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Trailing mode: `OFF` keeps fixed TP/SL; `PANDORA_RISK_TRAILING_STEP_TP` trails SL in TP-like steps and uses no hard TP price. | Start with `OFF`; use `STEP_TP` only after tester validation. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Lot calculation mode: fixed lot, percentage-based, or currency-based. | Fixed lot for stable behavior; budget-based only with risk calibration. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Size parameter used by the selected lot mode. | Keep small for first live runs and scale gradually. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Max allowed box range in points. `0` disables filter. | Use a symbol-specific cap to avoid oversized range days. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Distance mode for offset/SL/TP: raw points or `%` of current box range. | Prefer `POINTS` initially; use `%` for volatility-adaptive behavior. |
| `Pandora_Box_Offset_Points` | `1.0` | Breakout buffer distance from box high/low (interpreted by points value mode). | Keep non-zero to reduce false breakouts. |
| `Pandora_Points_SL` | `100.0` | Pandora stop distance (also base spacing reference for Pandora order construction). | Must stay `> 0`; tune by symbol volatility. |
| `Pandora_Points_TP` | `100.0` | Pandora take-profit distance. In step trailing mode TP price is not set for real entries, and deep-entry observation invalidation uses `Pandora_Points_SL` instead. | Use positive values unless strategy explicitly relies on trailing-only exits. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controls `counted` metric: `OFF` counts `SL`/`TP`/`BE`, `ON_SL` counts `SL`+`BE`, `ON_TP` counts `TP`+`BE`. | Use `OFF` for full analytics, filtered modes for targeted diagnostics. |
| `Pandora_Box_Max_Entries` | `2` | Broker-realistic Pandora-entry budget per day/window (`0` = unlimited). Pending spread admission and broker-blocked/rejected entries still count. | Keep low (`1-2`) unless broader protections are strict. |
| `Pandora_First_Entry_Mode` | `0` | First entry depth: `-1` local-only/no broker market, `0` breakout default, `1` SL1, `2` SL2, `N` up to `20` for deeper same-direction SL levels. | Keep `0` for live default; use `1+` only for focused Strategy Tester research. |
| `Pandora_XBoost_Mode` | `PANDORA_XBOOST_DISABLED` | XBoost mode. `DISABLED` preserves current Pandora behavior, `TRAINING` records local tree statistics only, and `INFERENCE` uses loaded stats to allow READY branches through the existing broker path. | Train first, then validate out-of-sample before live inference. |
| `Pandora_XBoost_Strategy_Id` | `"default"` | User-managed preset id included in XBoost file names and strategy keys. The runtime key also includes symbol, timeframe, entry type, trailing mode, points mode, box window, and max depth. | Use a unique id per preset so incompatible stats are not mixed. |
| `Pandora_XBoost_Max_Depth` | `3` | Maximum XBoost progression depth and maximum sequential XBoost real broker decisions/trades derived from one Pandora root day. Supported experimental range is `0-3`; practical inference values are usually `1-3`. | Start with `3` for research; lower it when you want fewer possible real trades. |

## Runtime Identity, Order Comments, And Status Panel

These fields and labels are not Pandora entry rules, but they are required for safe production operation:

| Item | What it means | Validation |
|---|---|---|
| `EA_Instance_Id` | Optional stable id for this chart EA instance. Leave empty to let the EA persist one locally; set manually only when you intentionally want the same chart instance identity after reinstall/migration. | Two charts in the same terminal should display different runtime magic values after backend validation. |
| `Custom_Magic` | Tester-friendly magic override. In live mode, the backend-issued instance trade magic is authoritative after license verification. | Do not rely on random live magic. If live backend magic is missing or invalid, initialization fails closed. |
| `pandora_box_pos_n` comments | New broker comments for Pandora/grid positions. `n` counts position-opening levels, not virtual grid levels. Hedge orders reserve a deterministic `pandora_box_pos_n` outside normal level numbering. | Open a demo/tester position and confirm the broker comment uses the lowercase format. |
| Local rejected entries | A local Pandora entry can remain active when an operable broker send is blocked or rejected after a broker-realistic anchor exists. Keep the rejection reason as local state (`local_rejected`) and do not assume broker history contains a matching position. | Force stops/volume/margin rejection in tester and confirm the local entry remains alive until local SL/TP/BE/trailing closes it. |
| Broker retry entries | Retry pending means the local entry already exists and the EA is trying to attach real broker execution on consecutive eligible ticks. `OrderSend` is the broker source of truth, and no broker retcode is final before the attempt budget is exhausted. | Confirm every retry uses the current tick price, retry success rebases local entry price/time and attempt 8 becomes final when no broker position exists. |
| XBoost stats files | XBoost stores CSV files in the terminal files area with names like `pandora_xboost_v1_<strategy>_<symbol>_<period>_stats.csv` and `_samples.csv`. Sample ids are loaded once and skipped when a repeated tester run sees the same day/node/outcome again. | Run the same training range twice and confirm sample counts do not duplicate. Delete or archive these files to reset training data for a preset. |
| `pandora_xb_pos_n` comments | Broker comments for XBoost-selected real positions. `n` follows the sequential XBoost broker decision index for the root day. | In inference, confirm there is never more than one active XBoost broker position and comments advance only after closed selected signals. |
| XBoost panel lines | The panel/tester comment shows `XBOOST <mode> root=<side> day=<date> d=<depth> broker=<n>/<max>` plus up to three `XB#` candidate rows with id, status, samples, expectancy R, and edge R. | Use the panel to anticipate the next branches that may open real positions; it is display-only and does not affect trading decisions. |
| Pandora broker stop status | `Stops broker pendientes` means broker protection is not yet attached or could not be tightened on the latest legal attempt; `Stops broker amplios` means broker protection is wider than the exact source-of-truth local target; `Stops broker objetivo` means broker-side protection matches that target. `Stops broker fallidos` is non-fatal for the local lifecycle. | With `Pandora_Box_Set_Broker_SLTP = true`, confirm local SL/TP closes remain aligned to the active fill/simulated anchor while broker stops are pending/wide/failed. |
| MT5 Algo Trading status | When MT5 Algo Trading, EA trading, or account expert trading is disabled, the EA keeps rates/UI fresh but skips signal/order/close/modify/force-close actions. Broker-side SL/TP remains the only active protection while disabled. | Toggle Algo Trading off/on on a demo chart and confirm no repeated trade errors occur while disabled. |
| Error label | The chart panel and Strategy Tester comment show `Error: OK`, `Error: ACTIVE ...`, or `Last error: ...` for order-send failures, guardrail blocks, broker disabled/close-only, margin/no-money, SL/TP failures, close failures, and platform-disabled state. | Treat the label as informational only; it does not change trading decisions. |

## Developer-Only Broker Retry Defaults

These values are internal globals in `services/trading_management/ea_inputs.mqh`, not MT5 `input` fields. Change them in code only when adjusting broker execution policy:

| Field | Default | What it does |
|---|---:|---|
| `Pandora_Box_Broker_Retry_Attempts` | `8` | Total broker open `OrderSend` attempts for one Pandora local entry, including the first send. `1` disables retry. Retries occur on consecutive eligible ticks without a seconds-based delay, time window, or price-drift cancellation. |

## XBoost Training And Inference Workflow

Use this workflow when testing the XBoost progression tree:

1. Set `Pandora_Box_Max_Entries = 1`, choose a unique `Pandora_XBoost_Strategy_Id`, set `Pandora_XBoost_Max_Depth`, and run period A with `Pandora_XBoost_Mode = PANDORA_XBOOST_TRAINING`.
2. The training run writes idempotent local samples and aggregate stats. Re-running the exact same range is a functional check for duplicate protection, not proof of predictive edge.
3. Run the same range with `Pandora_XBoost_Mode = PANDORA_XBOOST_INFERENCE` only to confirm that loaded stats, candidate statuses, Top rows, and broker gates behave as expected.
4. For edge validation, freeze the stats from period A and run a later period B out-of-sample. Treat this as a walk-forward validation, not a same-data replay.
5. In inference, only `READY` candidates can be selected for broker execution. `WAIT`, `WATCH`, and `BLOCK` remain local-only and continue collecting stats.

Initial scorer thresholds are code-level constants: depth 1 needs 30 samples, depth 2 needs 20, depth 3 needs 12, minimum expectancy is `0.05R`, minimum edge is `0.05R`, and the score applies a `0.03R` depth penalty.

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
- Confirm `Pandora_Box_Max_Entries` (reserved/opened Pandora budget) and `Pandora_Box_Entry_Count_Mode` (analytics counter) are not conflated.
- If using `Pandora_First_Entry_Mode >= 1`, confirm chart observation lines show `TP obs` and the expected `SLN entry` target before relying on the run.
- If using XBoost, confirm `Pandora_XBoost_Strategy_Id` is unique to the preset and that the stats/sample CSV files are the intended ones for the run.
- Confirm `Pandora_XBoost_Mode = PANDORA_XBOOST_TRAINING` never opens broker positions from XBoost branches.
- Confirm `Pandora_XBoost_Mode = PANDORA_XBOOST_INFERENCE` opens broker positions only for `READY` candidates and never while another XBoost broker position is active.
- Confirm `Pandora_XBoost_Max_Depth` matches the maximum sequential XBoost real broker decisions/trades you are willing to allow from one root day.
- In Strategy Tester, remember idle chart/comment updates can appear on new chart bars rather than every tick; active entries, observations, retries, and closes should still update immediately.
- Confirm session filters are configured when `Pandora_Box_Use_Session_Filter = true`.
- Decide whether broker-side protection is required (`Pandora_Box_Set_Broker_SLTP = true`).
- Confirm developer broker retry defaults match the broker/server behavior. Set `Pandora_Box_Broker_Retry_Attempts = 1` in code when you need strict one-shot broker execution.
- Confirm source-of-truth SL/TP math on the target symbol. Example: with `_Point = 0.1`, `Pandora_Points_SL = 250`, and a sell fill at `49196.3`, exact local SL should be around `49221.3`.
- For production multi-chart use, confirm every attached chart shows a distinct backend-approved magic and that each chart ignores positions from other symbols/charts.
- Toggle MT5 Algo Trading off and confirm the panel/tester comment shows disabled/platform status while broker actions stop.
- Confirm new positions use comments like `pandora_box_pos_1`.
- Confirm the error label reads `Error: OK` during normal operation and becomes `Error: ACTIVE ...` or `Last error: ...` after a safe forced rejection test.
- Check chart status text for `PANDORA INVALID WINDOW`, `PANDORA INVALID BOX`, `PANDORA WAIT_CLOSE`, and `PANDORA DONE`.

## Manual And Tester Regression Checklist

Run these scenarios manually in Strategy Tester visual mode or on a demo chart when changing Pandora lifecycle, broker sends, stop safety, or chart markers. Use "Every tick based on real ticks" when spread, stop/freeze distance, or tick-level local SL/TP timing matters. Do not treat this as a headless MT5 matrix test requirement.

| Scenario | Inputs/setup | Expected logs/status | Expected chart label | Expected budget/statistics |
|---|---|---|---|---|
| High spread blocks broker send | `Pandora_Box_Max_Entries = 1`, valid box, breakout tick, and `Max_Spread` below observed spread. | `PANDORA_ENTRY_OPEN`, then active/last error reason such as `PANDORA_BROKER_SPREAD_BLOCK`; active local admission waits until spread returns inside limits. | No local trade marker while admission is pending. If admission later creates a local-only entry, marker uses the broker-realistic anchor; if broker fills, label becomes `... (Posicion ejecutada)`. | `open=1/1`; next breakout on the same day does not create a second Pandora entry. Broker history exists only if a send/retry succeeds. |
| Broker send failure | Reproduce any unsuccessful or unresolved `OrderSend` retcode while the local entry remains active. | Each failure records diagnostics and leaves broker execution pending before attempt 8. Every eligible tick rebuilds Bid/Ask, constraints, normalized volume, stops and request. | Executed retry: `... (Posicion ejecutada)` redrawn from the real fill. Attempt-8 give-up: local marker with the last reject reason. | Retry success rebases local entry price/time and local SL/TP to the real fill. Local SL/TP evaluation resumes after broker execution succeeds or the attempt budget is exhausted. |
| Invalid broker stops | `Pandora_Box_Set_Broker_SLTP = true`, SL/TP distances that are unsafe for current broker stops/freeze constraints, otherwise valid breakout. | Opening `OrderSend` uses no initial broker SL/TP. If send succeeds, stop sync starts as `Stops broker pendientes`; later `PositionModify` attempts can move it to `Stops broker objetivo`, `Stops broker amplios`, or `Stops broker fallidos` without stopping the local lifecycle. | Executed path: `... (Posicion ejecutada)`. Stop-sync failures should only affect broker stop status/error detail. | Exact local SL/TP remains based on the real broker fill. Broker stops can be absent or wider temporarily and should tighten to `Stops broker objetivo` when legal. |
| Invalid volume or no money | Set lot mode/size above symbol/account limits or margin availability. Keep `Debug_Stop_On_Negative_Equity` behavior in mind during tester runs. | A local pre-send guard remains definitive. When the broker itself returns invalid volume or no money from `OrderSend`, Pandora retries on eligible ticks until success or attempt 8. | `... (Posicion ejecutada)` after recovery, otherwise a local marker with the final broker reason. | Local entry consumes `Pandora_Box_Max_Entries`; broker history exists only if one send succeeds; local close outcome still updates local counters. |
| Broker success | Normal lot, legal stops, acceptable spread, valid breakout. | `PANDORA_ENTRY_OPEN`; broker status becomes executed; panel error returns to `Error: OK` after successful send/sync. | `... (Posicion ejecutada)`. | Local entry and broker position are aligned. Broker history contains the position/deal, while Pandora open/close/count metrics still come from local lifecycle. |
| Local-only SL close | Force a blocked/rejected local entry, then move price to exact local SL. | `PANDORA_ENTRY_CLOSE` with SL-like outcome; no broker close is required when ticket is `0`. | Negative marker like `... (Posicion local - ERR_Spread)` or the actual reject reason. | `closed_entries` increments; `counted_entries` follows `Pandora_Box_Entry_Count_Mode`; local loss is separate from broker history. |
| Local-only TP close | Force a blocked/rejected local entry, then move price to exact local TP. | `PANDORA_ENTRY_CLOSE` with TP-like outcome; `Pandora_Box_Stop_On_First_Win = true` can finish the day. | Positive marker like `... (Posicion local - ERR_Spread)` or the actual reject reason. | `closed_entries` increments; `PANDORA DONE` appears when budget/first-win rules require it; broker history has no matching profit. |
| First entry off | `Pandora_First_Entry_Mode = -1`, valid breakout, normal prices. | `PANDORA_FIRST_ENTRY_LOCAL_ONLY`; no `OrderSend` should be attempted. | Local marker only, no broker deal. | Budget counts once and closes from local fixed SL/TP. |
| SL1 discard | `Pandora_First_Entry_Mode = 1`; price reaches breakout observation TP before SL1. | `PANDORA_FIRST_ENTRY_OBSERVATION_CLOSE` with discard reason. | Observation lines disappear after close marker. | Budget counts once; outcome is TP-like and can finish day on first win. |
| SL1 market admission | `Pandora_First_Entry_Mode = 1`; price reaches SL1 before observation TP. | `PANDORA_FIRST_ENTRY_MARKET_ADMITTED`, then normal broker send/retry logs. | Entry marker uses broker fill or executable local anchor, not breakout. | Budget counts once; real close completes the day/budget. |
| SL2 staged observation | `Pandora_First_Entry_Mode = 2`; price reaches SL1 first. | `PANDORA_FIRST_ENTRY_OBSERVE_ADVANCE`; chart target changes from `SL1 entry` to `SL2 entry`. | `TP obs` is recalculated from SL1 stage. | No budget count until SL1 TP discard or SL2 market admission. |
| SL3 staged observation | `Pandora_First_Entry_Mode = 3`; price reaches SL1, then SL2, before observation TP. | Two `PANDORA_FIRST_ENTRY_OBSERVE_ADVANCE` logs, then `PANDORA_FIRST_ENTRY_MARKET_ADMITTED` at SL3. | Chart target advances from `SL1 entry` to `SL2 entry` to `SL3 entry`. | No budget count until an observation TP discard or SL3 market admission. |
| XBoost training pass | `Pandora_Box_Max_Entries = 1`, unique `Pandora_XBoost_Strategy_Id`, `Pandora_XBoost_Mode = PANDORA_XBOOST_TRAINING`, selected depth. | `PANDORA_XBOOST_LOCAL_BRANCH` and save/load logs when enabled; no broker selected logs. | XBoost panel line shows training mode and candidate rows when stats exist. | Stats and samples CSV files are written on deinit; broker history is unchanged by XBoost. |
| XBoost duplicate replay | Re-run the exact same training range with the same strategy id and preset. | No duplicate sample growth for already seen sample ids. | Panel remains display-only. | Treat this as idempotency validation only, not predictive edge validation. |
| XBoost inference replay | Run the same range with `Pandora_XBoost_Mode = PANDORA_XBOOST_INFERENCE` using stats from the training pass. | Candidate rows show `READY`, `WAIT`, `WATCH`, or `BLOCK`; broker selected logs appear only for READY candidates. | READY selected broker entries use comments like `pandora_xb_pos_1`. | This confirms wiring and gates only; it is not a valid edge backtest because the same data trained the stats. |
| XBoost out-of-sample validation | Train period A, keep its stats files, then run later period B in inference. | Broker selections occur only for READY candidates based on period A stats. | Panel shows expected next branches before any real XBoost send. | Use this walk-forward style to evaluate edge; compare period B results against local-only candidates and normal Pandora. |
| XBoost no-candidate day | Inference mode with missing or insufficient stats for the current root/branch. | Candidate status is `WAIT`, `WATCH`, or `BLOCK`; no `PANDORA_XBOOST_BROKER_SELECTED` log. | No `pandora_xb_pos_n` broker comment should appear. | Local branches still close and record idempotent samples. |
| XBoost trailing close to next depth | Step trailing mode enabled; selected or local XBoost node trails SL into profit or BE and then closes. | Close event maps to `TBEL`/`TBES` or `TTPLn`/`TTPSn`; next-depth candidates are rebuilt. | Panel updates to the next depth candidates after close. | No next real broker branch opens until the prior selected XBoost signal is closed. |
| XBoost max-depth stop | Set `Pandora_XBoost_Max_Depth = 1`, `2`, or `3` and force enough closes to reach the limit. | No branch advances beyond the configured max depth. | Broker count never exceeds the configured max depth. | Derived local stats can continue only up to max depth, and real broker selections stop at the depth limit. |
| Broker stop tightening | Successful broker entry where no initial SL/TP was attached and exact SL/TP is unsafe at fill time. Keep price moving until exact local targets become legal for broker modification. | Stop status starts as pending/absent, then becomes `Stops broker objetivo` or `Stops broker amplios` after safe sync. Failed modify attempts should be non-fatal and throttled. | `... (Posicion ejecutada)`. | Local SL/TP does not move just because broker stops are wider or absent. Statistics use exact local close price, not the temporary broker protection state. |

## Notes
- `Pandora_Box_Enable` and visualization colors/styles are code-level fields (not MT5 `input` fields) in this branch.
- If you need those values editable from the Inputs panel, promote them to `input` variables in `ea_inputs.mqh`.
- Existing `.set` files that used the old enum labels require manual migration: old `First_Entry_Breakout` becomes `0`, old `First_Entry_Sl_1` becomes `1`, old `First_Entry_Sl_2` becomes `2`, and old `First_Entry_Off` becomes `-1`. Do not reuse old enum numeric values directly.
