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
- Only one pending campaign exists. A newly touched pivot replaces it, while
  already-open hedging positions remain independent.
- At startup and session entry, the active macro set is rebuilt from its open
  through every closed micro candle, including candles outside entry sessions.
- A first touch in the open micro candle is provisional. When that candle
  closes, the level is burned for the rest of the macro set; retries remain
  possible only inside the original open micro candle.
- If the required history is unavailable or unsynchronized, new campaigns fail
  closed until the level reconstruction succeeds.

## Position Lifecycle

Entries are market orders with no server-side SL or TP. The actual broker fill
anchors the local SL and trailing step. The first favorable step moves the local
stop to break-even; later steps advance it monotonically. A locally closed
position with net result `<= 0` can re-arm only while its original micro candle
is still open and the same pivot/Bollinger condition remains valid.
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
  startup the Journal prints the resolved absolute path and the run id.
- Every audit row carries `run`, `symbol` and runtime `magic`. Important event
  families include `LEVEL_SCAN_*`, `LEVEL_TOUCH_PROVISIONAL`, `LEVEL_BURNED`,
  `CAMPAIGN_*`, `ENTRY_*`, `ORDER_SEND_RESULT`, `FILL_*`, local SL/trailing,
  position finalization, protection closes and debug stops.
- Rotate or clear `query_debug.txt` before a focused tester session so chart,
  broker history and one run id can be correlated without stale evidence.
- Chart objects use the `PIVOT_HFT_` prefix. The campaign pivot, tracked
  extreme and retracement trigger are separate lines; each live ticket has
  deterministic `POSITION_<ticket>_ENTRY` and `POSITION_<ticket>_STOP` lines.
  First-test segments and completed campaign/ticket objects are removed by the
  owning visual cleanup path.

## Safety Notes

- MT5 account mode must be `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
- Local SL/trailing protection requires the EA, terminal and broker connection
  to remain available. Algo Trading or broker outages can delay a local close.
- Spread, margin, session, daily-limit, drawdown, market-status and license
  guards remain authoritative for new entries.
- Entry indicators are activated only while a configured session window is
  open. Non-visual tester runs skip chart objects/comments, while open-position
  local protection continues outside the entry window.
- Use Strategy Tester `Every tick based on real ticks` and a demo hedging chart
  before live use. Manual real-tick evidence is a release prerequisite; a clean
  compile alone does not authorize live deployment.

See `docs/guides/pivot-hft-strategy-inputs.md` for input definitions and the
manual validation checklist.
