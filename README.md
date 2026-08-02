# Pivot HFT EA

**Version:** 2.00
**Platform:** MetaTrader 5 / MQL5

Pivot HFT is a tick-driven Expert Advisor that combines classic pivot levels
from the previous closed macro candle with fixed Bollinger Bands on a micro
timeframe. It targets retail MT5 execution on hedging accounts; it does not
claim institutional HFT latency.

## Strategy

- `Pivot_HFT_Pivot_Timeframe` calculates `P`, `R1-R3` and `S1-S3` from its
  previous closed candle.
- `Pivot_HFT_Micro_Timeframe` owns the fixed Bollinger Bands (`21`, deviation
  `2.0`, `PRICE_CLOSE`) and the retry window. Entry filtering reads the bands
  from the previous closed micro candle (`shift=1`).
- A sell campaign arms when the current micro close is at or above `R1-R3` and
  the upper band. A buy campaign uses `S1-S3` and the lower band.
- Sells follow the highest Bid and enter after a downward retracement. Buys
  follow the lowest Ask and enter after an upward retracement.
- Only one pending campaign and one managed position may own the execution slot.
  A newly touched pivot can replace the campaign only during its origin micro
  candle; a running campaign keeps its level and tracked extreme across later
  micro candles.
- The chart timeframe is not a strategy clock. Bollinger, pivots, touches and
  lifecycle transitions use the configured `Pivot_HFT_Micro_Timeframe` and
  `Pivot_HFT_Pivot_Timeframe` even when the tester chart uses another period.
- At startup and session entry, the active macro set is rebuilt from its open
  through every closed micro candle, including candles outside entry sessions.
- A first touch in the open micro candle is provisional. When that candle
  closes, the level is burned for the rest of the macro set, but an already
  armed campaign is grandfathered and may keep tracking across later candles.
- A pending campaign is cancelled only by session/resource shutdown or a macro
  pivot-set rollover. A filled ticket's retry boundary is the micro candle that
  actually contains the broker fill.
- If the required history is unavailable or unsynchronized, new campaigns fail
  closed until the level reconstruction succeeds.

## Position Lifecycle

Entries are market orders with no server-side SL or TP. The actual broker fill
anchors the local SL and trailing step. The first favorable step moves the local
stop to break-even; later steps advance it monotonically. A locally closed
position with net result `<= 0` can re-arm only while its fill micro candle is
still open and the same grandfathered pivot/Bollinger condition remains valid.
External or protection-driven closes never re-arm the closed campaign.

Net result includes profit, swap, commission and fee for deals scoped by the
position identifier, symbol and runtime magic.

## Architecture

| Layer | Key files |
| --- | --- |
| Entrypoint | `HFT_Grid_AI.mq5` |
| Inputs and sessions | `services/trading_management/ea_inputs.mqh`, `services/trading_management/session_time_filter_context.mqh` |
| Pivot data and detection | `services/trading_signals/pivot_hft_levels.mqh`, `services/trading_signals/pivot_hft_indicators.mqh`, `services/trading_signals/pivot_hft_detection.mqh` |
| Execution and lifecycle | `services/trading_signals/pivot_hft_execution.mqh`, `services/trading_signals/pivot_hft_position_lifecycle.mqh` |
| Protection and status | `services/trading_signals/protection_risk_filter.mqh`, `services/trading_signals/market_status_controller.mqh` |
| Frontend | `services/frontend/pivot_hft_panel.mqh`, `services/frontend/pivot_hft_visualization.mqh` |

The shared license implementation and backend identity remain unchanged. Live
magic still comes from `LicenseGetCachedMagicNumber()` and the tester retains
the historical deterministic seed for compatibility.

## Diagnostics And Visual QA

- `Enable_Logs` controls compact Journal messages. `Enable_File_Logs` controls
  the persistent Pivot HFT lifecycle audit; the two inputs are independent.
- The audit appends to
  `TERMINAL_COMMONDATA_PATH\Files\query_debug.txt` through `FILE_COMMON`. On
  startup the Journal prints the resolved absolute path and a collision-resistant
  run id. Pivot HFT keeps a shared append handle, seeks to the current end,
  flushes each bounded event and retries one reopen after a write failure.
- Every audit row carries `run`, `symbol` and runtime `magic`. Important event
  families include `LEVEL_SCAN_*`, `LEVEL_TOUCH_PROVISIONAL`, `LEVEL_BURNED`,
  `CAMPAIGN_CARRIED_FORWARD`, `CAMPAIGN_CANCELLED`, `CAMPAIGN_*`, `ENTRY_*`,
  `ORDER_SEND_RESULT`, `FILL_*`, local SL/trailing, position finalization,
  protection closes and debug stops. Occupied-level diagnostics are emitted
  once per unique bar/direction/mask/selection signature.
- `POSITION_FINALIZED` records the independent `close_trigger` and `net_class`,
  trigger quote/stop/step, latest exit deal and volume-weighted actual close
  price. A profitable BE or trailing close is therefore not mislabeled as TP.
- Rotate or clear `query_debug.txt` before a focused tester session so chart,
  broker history and one run id can be correlated without stale evidence.
- Chart objects use the `PIVOT_HFT_` prefix. The campaign pivot, tracked
  extreme and retracement trigger are separate lines; each live ticket has
  deterministic `POSITION_<ticket>_ENTRY` and `POSITION_<ticket>_STOP` lines.
  A terminally cancelled campaign is shown as `CANCELLED` briefly for visual
  QA; first-test segments and completed ticket objects are removed by the owning
  visual cleanup path.

## Safety Notes

- MT5 account mode must be `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
- Local SL/trailing protection requires the EA, terminal and broker connection
  to remain available. Algo Trading or broker outages can delay a local close.
- Spread, margin, session, daily-limit, drawdown, market-status and license
  guards remain authoritative for new entries.
- Entry indicators are activated only while a configured session window is
  open. Non-visual tester runs skip chart objects/comments, while open-position
  local protection continues outside the entry window.
- The focused US30 real-tick baseline passed on 2026-08-01 with chart M1, micro
  M3 and pivot H1, including single-flight and bounded-log correlation. Repeat
  the broker-specific demo checks before live use; a clean compile or one tester
  baseline alone does not authorize live deployment.

See `docs/guides/pivot-hft-strategy-inputs.md` for input definitions and the
manual validation checklist.

The completed implementation history is archived in
`docs/plans/archive/pivot-hft-strategy-plan.md`.
