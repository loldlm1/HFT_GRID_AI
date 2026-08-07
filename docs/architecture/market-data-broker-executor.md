# Macro/Micro Pivot Market Data Collector And Broker Executor

## Purpose

The EA owns one fixed strategy boundary: create one classic pivot ladder from
the previous completed Macro broker candle, capture deterministic trigger-time
band facts, and optionally execute one market position per consumed pivot
identity. It is not a generic strategy framework, licensing platform, risk
dashboard, session scheduler, pending-order engine, or multi-leg grid system.

## Runtime Sequence

```text
broker tick
-> refresh one changed or retry-due Macro window
-> calculate seven classic pivot levels from Macro shift 1
-> cache Macro shift-1 weighted Bands and PP role state
-> discover and consume live-Bid virtual-limit triggers
-> capture one Micro/Macro context snapshot for the tick batch
-> derive each candidate's Macro pivot %B
-> build structural SL and observation-time 1R geometry
-> repeat quote, volume, broker, margin, and OrderCheck facts pre-send
-> OrderSend one FOK market request with immutable broker SL/TP
-> reconcile entry and close by owned broker ticket
-> record optional strict schema V10 facts
```

Broker checks and execution remain active when persistence is disabled.
`Enable_Signal_Feature_Export` controls V10 files and the two Bands handles; it
never authorizes or denies a trade.

## Timeframe And Window Ownership

`PIVOT_FRACTAL_V2` owns one configurable Macro and one configurable Micro
timeframe. Defaults are `H1` and `M3`. Inputs fail initialization unless both
are explicit supported MetaTrader timeframes, distinct, and Micro is shorter
than Macro.

For the Macro timeframe:

- `iTime(symbol, Macro_Timeframe, 0)` identifies the active lifecycle window.
- `CopyRates(symbol, Macro_Timeframe, 1, 1, ...)` supplies the immediately
  previous completed source candle.
- A changed active bar expires every untriggered identity from the old window
  and creates one new pending window.
- Pending source or Bands reads retry at a bounded cadence. Invalid source
  ranges, collapsed normalized ladders, unavailable bands, and zero-width
  bands remain explicit facts.
- Weekend and broker-session gaps follow the actual series. No elapsed-time
  arithmetic creates synthetic candles.
- A bar or band snapshot whose open is later than the observed tick is not
  causal and cannot activate.

## Classic Pivot Calculation

For source high `H`, low `L`, close `C`, and range `D = H - L`:

```text
PP = (H + L + C) / 3
R1 = 2 * PP - L          S1 = 2 * PP - H
R2 = PP + D              S2 = PP - D
R3 = H + 2 * (PP - L)    S3 = L - 2 * (H - PP)
```

The calculator retains raw values and one tick-normalized trade ladder. A
window is valid only when finite positive source data produces the strict
order `S3 < S2 < S1 < PP < R1 < R2 < R3` after normalization.

## Identity, PP Arming, And Trigger Semantics

Identity is exactly `(symbol, Macro timeframe, active bar open, level)`.
Direction is an outcome and is not part of the key.

```text
live Bid <= S1/S2/S3 -> BUY support trigger
live Bid >= R1/R2/R3 -> SELL resistance trigger
```

PP requires a fixed role for each Macro window:

- first causal Bid above PP arms PP as support; a later `Bid <= PP` triggers a
  buy;
- first causal Bid below PP arms PP as resistance; a later `Bid >= PP`
  triggers a sell;
- equality records the first observation but remains neutral until Bid first
  leaves strictly above or below, at which point the return direction is armed;
- PP never flips role after arming.

Inclusive comparisons mean exact touches and gap-throughs count. A support or
resistance already marketable at the first causal tick may trigger immediately.
All candidates are consumed before route or broker evaluation, so a denied or
failed attempt cannot trigger again.

Downward candidate order is buy-armed `PP`, `S1`, `S2`, `S3`. Upward order is
sell-armed `PP`, `R1`, `R2`, `R3`. Every candidate in the same observed batch
copies the same frozen window and shared band snapshot.

Buy triggers use Bid but requests use fresh Ask. Sell triggers and requests use
Bid. Trigger Bid/Ask, pivot price, request quote, broker fill, immutable
terminal prices, and close price remain separate facts.

## Immutable Route Matrix

| Level | Role | Structural SL | Fresh quote TP |
| --- | --- | --- | --- |
| `PP` | Buy when armed as support | `S1` | `Ask + (Ask - S1)` |
| `S1` | Buy support | `S2` | `Ask + (Ask - S2)` |
| `S2` | Buy support | `S3` | `Ask + (Ask - S3)` |
| `S3` | Buy support | `S3 - (S2 - S3)` | `Ask + (Ask - SL)` |
| `PP` | Sell when armed as resistance | `R1` | `Bid - (R1 - Bid)` |
| `R1` | Sell resistance | `R2` | `Bid - (R2 - Bid)` |
| `R2` | Sell resistance | `R3` | `Bid - (R3 - Bid)` |
| `R3` | Sell resistance | `R3 + (R3 - R2)` | `Bid - (SL - Bid)` |

Observation geometry is telemetry. The authoritative entry, risk distance, and
TP are rebuilt from a fresh pre-send quote and normalized to symbol price
rules. Reward and risk distance in points must remain exactly 1:1 within the
project tolerance. The pivot ladder is never moved to force valid geometry.

After a fill, broker SL and TP are immutable. The EA submits no stop
modification, trailing, break-even, partial-close, or resize request.

## Weighted Bands Feature Ownership

The runtime creates two cached built-in `iBands` handles only when V10 export
is enabled:

```text
iBands(symbol, timeframe, 21, 0, 2.0, PRICE_WEIGHTED)
```

Buffers are `0=BASE_LINE`, `1=UPPER_BAND`, and `2=LOWER_BAND`.
`PRICE_WEIGHTED` is `(High + Low + Close + Close) / 4`.

`%B` is never clipped:

```text
100 * (price - lower_band) / (upper_band - lower_band)
```

- Micro shift `0` uses trigger Bid against the developing Micro bands.
- Micro shifts `1..5` use each matching completed weighted price and bands.
- Macro pivot shifts `0..5` use the immutable touched pivot price as numerator
  against each Macro band envelope.
- Micro bandwidth is captured at shift `0` on the trigger tick.
- Macro bandwidth is cached at shift `1` with the Macro source window.
- Raw width is audit-only; normalized width is
  `100 * (upper - lower) / base` and is model-eligible.

Unavailable, noncausal, nonfinite, or zero-width facts make the feature
snapshot incomplete. They never alter an otherwise valid execution decision.

## Lot And Money Semantics

- `EXECUTION_LOT_FIXED_SIZE`: `Lot_Strategy_Size` is requested lots.
- `EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`: the risk budget is
  `1,000,000 * Lot_Strategy_Size / 100`, independent of live balance.
- The default `0.01` percentage requests `100` account-currency units.
- `OrderCalcProfit` derives per-lot stop risk and quote expected SL/TP money.
- Requested volume normalizes downward to broker min/max/step. The EA does not
  round up to minimum volume or exceed the reference risk budget.
- Fixed-lot and reference-risk runs, currencies, or different timeframe
  configurations are not mixed in the initial research dataset.

Price-distance 1R and money R are different facts. Instrument conversion,
volume steps, entry/exit execution, commission, swap, and fees can produce a
result other than exactly `+100` or `-100`. The exporter records quote expected
loss/profit, utilization, adverse-positive entry/exit slippage, gross/net P&L,
and R against both the budget and executable quote risk.

## Before And After A Fill

Before a real position exists, local state owns identity, trigger facts,
captured ladder, route, feature snapshot, broker observations, and send status.

After a fill, the broker owns:

- order, deal, position ticket, and position identifier;
- full executed volume and entry price;
- immutable broker-side stop loss and take profit;
- open/closed state, close deals, close price/time, and realized costs/profit.

Requests use `ORDER_FILLING_FOK`. Unsupported full-fill policy fails closed;
partial volume is not adopted. Reconciliation selects the owned ticket first
and verifies symbol, V2 magic, direction, execution comment, and broker volume.
Local state may copy broker facts but never manufacture or overwrite them.

## Mandatory Broker Checks

The observation snapshot is telemetry. The fresh pre-send snapshot is
authority. Execution fails closed when any required condition is missing:

- `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`;
- actual broker session open and compatible symbol trade mode;
- account, expert, terminal, and MQL trading permission;
- valid current Bid/Ask and point size;
- directional entry/SL/TP geometry;
- stops and freeze distances;
- volume min/max/step, FOK support, and normalized volume;
- free margin, calculated margin, and successful `OrderCheck`;
- accepted `OrderSend` retcode and reconciled owned ticket.

Spread and live account balance are exported telemetry. There is no user
threshold for either, and the engine never changes pivot prices to make an
invalid request pass.

## Time Ownership

Broker time owns pivot bars, trigger order, actual sessions, durations, orders,
and reconciliation. Analysis time is derived only for research features.

| Mode | Broker time | Analysis time | Execution effect |
| --- | --- | --- | --- |
| `FIXED_TIME_SESSIONS` | preserved | unchanged | none |
| `EXNESS_SESSION`, DST active | preserved | unchanged | none |
| `EXNESS_SESSION`, winter | preserved | broker time minus 60 minutes | none |

Exness metal prefixes use UK DST dates; other symbols use US DST dates. Every
time-bearing V10 row retains broker time, analysis time, and offset. Causal
sorting uses broker time plus stable identity, never analysis time alone.

## V10 Data Ownership

The sole active export contract contains exactly:

- `run_manifest.tsv`
- `pivot_windows.tsv`
- `signal_attempts.tsv`
- `execution_checks.tsv`
- `signal_outcomes.tsv`
- `run_summary.tsv`

The outcome table includes only broker-confirmed closed positions. A binary
target exists only for a feature-complete full close whose owned closing volume
has one consistent `BROKER_TP` or `BROKER_SL` reason. Manual, mixed, stop-out,
expert, other, denied, failed-send, and censored facts remain required for
integrity and operations but do not enter binary performance or XGBoost.

Current DuckDB/Parquet, audit, and XGBoost code is offline-only. It cannot load
into MT5, approve a runtime artifact, filter an attempt, or alter broker state.
V9 evidence requires its historical repository revision and is not converted
or relabeled by current tooling.

## Frontend Boundary

The frontend is optional inspection output: at most 16 active positions, each
with broker entry, immutable broker SL, immutable broker TP, and a compact
Macro timeframe/level/direction/pivot label. It has no execution controls.
Nonvisual Strategy Tester runs skip all chart-object work.

## Non-Goals And Rollout

- No license, entitlement, public account, or public magic settings.
- No user trading-hours, configurable Bands formulas, synthetic bars, spread
  threshold, drawdown/daily limit, direction selector, or concurrency rule.
- No pending limit orders, `R4/S4`, trailing, partial TP, or multi-leg state.
- No runtime model scoring, filtering, pattern playback, or online learning.
- No live rollout approval.

Any future runtime handoff requires older-engine positions flat for the symbol,
a hedging account, and one EA instance per account and symbol.
