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
  `2.0`, `PRICE_CLOSE`) and the retry window.
- A sell campaign arms when the current micro close is at or above `R1-R3` and
  the upper band. A buy campaign uses `S1-S3` and the lower band.
- Sells follow the highest Bid and enter after a downward retracement. Buys
  follow the lowest Ask and enter after an upward retracement.
- Only one pending campaign exists. A newly touched pivot replaces it, while
  already-open hedging positions remain independent.
- The same pivot is not armed twice in one micro candle while its position is
  active or after that level completes positively; another pivot can still arm.

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

## Safety Notes

- MT5 account mode must be `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
- Local SL/trailing protection requires the EA, terminal and broker connection
  to remain available. Algo Trading or broker outages can delay a local close.
- Spread, margin, session, daily-limit, drawdown, market-status and license
  guards remain authoritative for new entries.
- Use Strategy Tester `Every tick based on real ticks` and a demo hedging chart
  before live use.

See `docs/guides/pivot-hft-strategy-inputs.md` for input definitions and the
manual validation checklist.
