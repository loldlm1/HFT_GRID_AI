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
  `2.0`, `PRICE_CLOSE`) and micro-candle processing. Entry filtering reads the
  bands from the previous closed micro candle (`shift=1`); a micro transition
  does not terminate an otherwise valid retry chain.
- A sell campaign arms when the current micro close is at or above `R1-R3` and
  the upper band. A buy campaign uses `S1-S3` and the lower band.
- With positive retracement points, sells follow the highest Bid and enter
  after a downward retracement; buys follow the lowest Ask and enter after an
  upward retracement. `Pivot_HFT_Retracement_Points = 0.0` makes the touched
  pivot an immediate market-entry intent under the same execution guards.
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
- A pending campaign or eligible closed-position retry may cross micro candles
  while session resources and its original macro pivot set remain valid.
  Session/resource shutdown and pivot-set rollover or price change are terminal.
  Under the one-campaign rule, latest-level replacement explicitly terminates
  the superseded campaign instead of leaving an orphan retry.
- An eligible non-positive local close preserves the admitted campaign sequence,
  increments its internal retry ordinal, and seeds a fresh directional extreme
  from the current entry-side quote. It does not require another pivot touch or
  live Bollinger-side admission. `Pivot_HFT_Start_Real_Retry=0` disables
  re-entry; `1` makes retry `1` and every later retry real; `N >= 2` runs
  retries `1..N-1` as local broker-like positions, then opens retry `N` and
  every later retry in the market. The input selects a source boundary, not a
  maximum retry count.
- If the required history is unavailable or unsynchronized, new campaigns fail
  closed until the level reconstruction succeeds.

## Position Lifecycle

The initial entry is always a market order with no server-side SL or TP. Real
retries use the same broker path; earlier retries selected by
`Pivot_HFT_Start_Real_Retry` are complete virtual positions. Every real or
virtual fill anchors one immutable local exit geometry snapshot. The first
favorable step moves the local stop to break-even; later steps advance it
monotonically. When enabled, the fixed local TP is checked before advancing
trailing on the same favorable tick. A locally closed position with net result
`<= 0` remains eligible across micro candles while its session resources and
original pivot price/set remain valid. The admission remains latched, so price
may be inside the bands or across the original pivot when the fresh retry
retracement starts. Temporary lifecycle, protection, daily, market, indicator
or quote guards emit a bounded `REARM_DEFERRED` state without changing the next
retry number or source. Session close, pivot rollover/change, replacement,
external/protection close, or retry input `0` are terminal outcomes. With start
value `0`, an otherwise eligible loss emits `RETRY_DISABLED` and completes the
level. There is no retry maximum or cooldown.
A profitable outer-level close consumes the same-side inner ladder from that
fill candle: for example, R2 consumes R1+R2 and S3 consumes S1+S2+S3.

Local risk always reuses the existing previous-closed-bar Bollinger snapshot;
it creates no second indicator handle:

```text
band_width_points = (upper_band - lower_band) / SYMBOL_POINT
initial_sl_points = band_width_points * bands_width_percent / 100
step_points       = initial_sl_points * tp_step_sl_ratio
fixed_tp_points   = initial_sl_points * fixed_tp_sl_ratio
```

Before every market send, Pivot HFT refreshes broker constraints and evaluates
the immutable requested local SL against a conservative close-side floor:

```text
broker_floor_points = EffectiveBrokerDistancePoints(constraints, 0.0, 1.0)
required_initial_sl_points = current_spread_points + broker_floor_points
```

If `initial_sl_points` is below that requirement, the EA emits
`ENTRY_RISK_DISTANCE_BLOCKED`, sends no order, consumes no daily signal start,
and returns the admitted campaign to tracking. It never widens the configured
SL automatically. After a verified fill, one fresh tick rechecks the actual
buffer from Bid to local SL for BUY, or local SL to Ask for SELL. A buffer below
the stored broker floor emits `FILL_ENTRY_DISTANCE_INVALID` and closes through
the normal local lifecycle with close trigger `ENTRY_SAFETY`.

- `Pivot_HFT_Local_SL_Bands_Width_Percent` defaults to `25.0` and always
  resolves the initial SL from full band width.
- `Pivot_HFT_TP_Step_SL_Ratio` defaults to `1.0`, must be positive, and derives
  the trailing interval from immutable initial SL.
- `Pivot_HFT_Fixed_TP_SL_Ratio = 0.0` disables fixed TP; a positive value
  enables that initial-SL multiple.
- `Pivot_HFT_Start_Real_Retry` defaults to `1`. The initial broker entry is
  retry number `0`; `0` disables rearm, `1` routes retry `1` and later to the
  broker, and `N >= 2` simulates retries `1..N-1` before routing retry `N` and
  later to the broker. Negative values fail startup.

With fixed Bollinger deviation `2.0`, full width is approximately `4 sigma`, so
`25%` is approximately a `1 sigma` volatility scale. This is not a probability
claim. Lot size remains fixed, so volatility-normalized exits do not create
constant monetary risk.

Real net result includes profit, swap, commission and fee for deals scoped by
position identifier, symbol and runtime magic. A virtual retry uses
`OrderCalcProfit` plus the preceding real source's observed per-lot cost
estimate. Its entry and close prices use fresh executable Ask/Bid, actual
spread, broker tick normalization and the source's signed observed slippage.
The audit preserves the immediate predecessor and original broker calibration
execution. Every modeled value is labeled `OBSERVED_ZERO`, `OBSERVED_VALUE`,
`FALLBACK_ZERO`, `FALLBACK_VALUE` or `UNAVAILABLE`; no random slippage is
generated.

## Architecture

| Layer | Key files |
| --- | --- |
| Entrypoint | `HFT_Grid_AI.mq5` |
| Inputs and sessions | `services/trading_management/ea_inputs.mqh`, `services/trading_management/session_time_filter_context.mqh` |
| Pivot data and detection | `services/trading_signals/pivot_hft_levels.mqh`, `services/trading_signals/pivot_hft_indicators.mqh`, `services/trading_signals/pivot_hft_detection.mqh` |
| Risk, execution and lifecycle | `services/trading_signals/pivot_hft_risk_geometry.mqh`, `services/trading_signals/pivot_hft_execution.mqh`, `services/trading_signals/pivot_hft_position_lifecycle.mqh` |
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
- Audit schema `2` is declared by `RUN_START|schema_version=2`. Runtime tester
  visualization uses `tester_visual_mode`, while the configured chart input
  uses `visualization_input`; event payload keys are unique within each row.
- `POSITION_FINALIZED` records the independent `close_trigger` and `net_class`,
  immutable risk geometry, trigger quote/stop/target/step, latest exit deal and
  volume-weighted actual close price. A profitable BE or trailing close is
  therefore not mislabeled as fixed TP.
- `ENTRY_TRIGGERED` identifies `IMMEDIATE` versus `RETRACEMENT` intent, and
  `WINNING_LEVELS_CONSUMED` records the directional pivot ladder closed by a
  profitable same-candle campaign.
- `ENTRY_RISK_DISTANCE_BLOCKED` records requested/required SL, spread, stops,
  freeze, buffered broker floor and tick size. `FILL_ENTRY_DISTANCE_INVALID`
  records the actual fill, fresh close-side quote, remaining buffer and the
  `ENTRY_SAFETY` close reason.
- `REARM_PENDING`, `REARM_DEFERRED`, `POSITION_REARMED`, `RETRY_DISABLED` and
  `REARM_INVALIDATED` expose one bounded retry transition with current/next
  retry, `source_execution_source`, `next_execution_source`, sequence, source
  identity and canonical reason. `CAMPAIGN_REPLACED` records old/new ownership
  and terminal reason `latest_level_replaced`.
- `VIRTUAL_FILL_REGISTERED` and `VIRTUAL_CLOSE_FILLED` record fresh Bid/Ask,
  spread, modeled/applied slippage, gross result, estimated costs and net.
  Model fields identify both the preceding execution and original broker
  calibration, including observed-zero/fallback provenance.
- Rotate or clear `query_debug.txt` before a focused tester session so chart,
  broker history and one run id can be correlated without stale evidence.
- Chart objects use the `PIVOT_HFT_` prefix. The campaign pivot, tracked
  extreme and positive-retracement trigger are separate lines; each live
  broker ticket or virtual execution id has deterministic
  `POSITION_<id>_ENTRY` and `POSITION_<id>_STOP` lines.
  An enabled fixed target adds deterministic `POSITION_<id>_TP`.
  Pending/deferred retries add deterministic `RETRY_WAIT_<id>` lines. A terminal
  invalidation or replacement remains visible briefly with its reason; first-test
  segments and completed ticket objects are removed by the owning cleanup path.
- The panel separates active `Broker`, active `Virtual` and `CloseWait`, labels
  pending/deferred/terminal retry state in words, and states the policy as
  initial broker, virtual before retry `N`, broker from retry `N`, with no
  maximum while the chain remains valid. It retains the requested-versus-required
  safety distance. A blocked intent is labeled `RISK BLOCKED`; it is not
  counted or drawn as a position.

## Safety Notes

- MT5 account mode must be `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
- Local SL, trailing and fixed TP protection require the EA, terminal and
  broker connection to remain available. Algo Trading or broker outages can
  delay a local close.
- Spread, margin, session, daily-limit, drawdown, market-status and license
  guards remain authoritative for new entries.
- Broker stops/freeze form a conservative floor for local protection only;
  server SL/TP remain zero. Valid rapid retries remain possible; the input
  changes their virtual/real source, not their count or cross-bar lifetime, and
  adds no cooldown.
- Virtual retries never call broker send/close APIs, affect account equity, or
  consume daily start/outcome counters. The first real retry still requires and
  consumes the normal daily budget.
- Entry indicators are activated only while a configured session window is
  open. Non-visual tester runs skip chart objects/comments, while open-position
  local protection continues outside the entry window.
- The focused US30 real-tick baseline from 2026-08-01 remains historical
  evidence for single-flight and bounded-log correlation. The corrected
  cross-bar retry contract still requires the manual matrix in the strategy
  guide before live use; a clean compile alone does not authorize deployment.

See `docs/guides/pivot-hft-strategy-inputs.md` for input definitions and the
manual validation checklist.

The completed implementation history is archived in
`docs/plans/archive/pivot-hft-strategy-plan.md`.
