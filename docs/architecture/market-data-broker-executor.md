# Pivot Fractal Market Data Collector And Broker Executor

## Purpose

The EA owns one fixed strategy boundary: cache classic pivots from completed
broker candles, record deterministic first-touch and broker facts, and
optionally execute one market position for each admissible pivot identity. It
is not a generic strategy framework, licensing platform, risk dashboard,
session scheduler, or multi-leg grid engine.

## Runtime Sequence

```text
broker tick
-> refresh previous completed M1 Bid close when the M1 bar changes
-> refresh only changed or retry-due M15/M30/H1/H4/D1 windows
-> discover and consume all newly crossed pivot identities
-> sort same-tick candidates deterministically
-> capture one trigger-time feature snapshot
-> build the immutable route
-> observation-time broker snapshot
-> fresh pre-send broker eligibility and OrderCheck
-> OrderSend with broker structural SL and terminal pivot TP
-> ticket-first reconciliation
-> monotonic pivot-level SL progression
-> broker-confirmed outcome and optional V9 persistence
```

Broker checks and execution remain active when persistence is disabled.
`Enable_Signal_Feature_Export` controls V9 files and context indicator handles;
it never authorizes or denies a trade.

## Pivot Window Ownership

`PIVOT_FRACTAL_V1` owns fixed `M15`, `M30`, `H1`, `H4`, and `D1` windows.
For each timeframe:

- `iTime(symbol, timeframe, 0)` identifies the active lifecycle window.
- `CopyRates(symbol, timeframe, 1, 1, ...)` supplies the immediately previous
  completed source candle.
- A changed active bar expires every untriggered identity from the old window
  and creates a new pending window.
- Pending market-data reads retry at a bounded one-second cadence. Invalid
  source ranges or collapsed normalized ladders remain invalid for that window.
- Weekend and broker-session gaps follow the actual series; no elapsed-seconds
  candle synthesis is allowed.

At a broker `09:30` transition, for example, `M15` and `M30` may refresh from
their just-completed candles while the existing `H1`, `H4`, and `D1` windows
retain their cached ladders until their own bar transitions.

## Classic Pivot Calculation

For source high `H`, low `L`, close `C`, and range `D = H - L`:

```text
PP = (H + L + C) / 3
R1 = 2 * PP - L          S1 = 2 * PP - H
R2 = PP + D              S2 = PP - D
R3 = H + 2 * (PP - L)    S3 = L - 2 * (H - PP)
```

The calculator retains raw values and one tick-normalized trade ladder. A
window is tradable only when finite positive source data produces the strict
order `S3 < S2 < S1 < PP < R1 < R2 < R3` after normalization.

## First-Touch Identity And Price Semantics

Identity is exactly `(symbol, pivot timeframe, active bar open, level)`.
Direction is an outcome of first touch and is not part of the key.

```text
previous completed M1 Bid close > level and live Bid <= level -> BUY
previous completed M1 Bid close < level and live Bid >= level -> SELL
previous completed M1 Bid close = level                       -> neutral
```

The live comparison is inclusive, so exact touches and gap-throughs count. All
newly crossed identities are consumed and recorded before send attempts. They
are ordered by distance from the previous M1 close, then fixed timeframe order
`M15,M30,H1,H4,D1`, then `S3..R3` level order.

One identity gets at most one signal and one send attempt, including when route
construction, broker checks, `OrderCheck`, or `OrderSend` fails. Equal prices
from different timeframes remain separate identities. Buy requests use current
Ask and sell requests use current Bid; trigger Bid, trigger Ask, intended pivot,
request price, and broker fill remain distinct facts.

## Entry And Trailing Matrix

`BE` means the captured entry pivot, not guaranteed monetary break-even.

| Direction | Entry | Initial broker SL | Milestones and SL changes | Terminal broker TP |
| --- | --- | --- | --- | --- |
| Buy | `PP` | `S1` | `R1 -> PP (BE)`, `R2 -> R1` | `R3` |
| Sell | `PP` | `R1` | `S1 -> PP (BE)`, `S2 -> S1` | `S3` |
| Buy | `S1` | `S2` | `PP -> no change`, `R1 -> PP`, `R2 -> R1` | `R3` |
| Sell | `R1` | `R2` | `PP -> no change`, `S1 -> PP`, `S2 -> S1` | `S3` |
| Buy | `S2` | `S3` | `S1 -> S2 (BE)`, `PP -> S1` | `R1` |
| Sell | `R2` | `R3` | `R1 -> R2 (BE)`, `PP -> R1` | `S1` |
| Buy | `S3` | `S3 - (S2 - S3)` | `S2 -> S3 (BE)`, `S1 -> S2` | `PP` |
| Sell | `R3` | `R3 + (R3 - R2)` | `R2 -> R3 (BE)`, `R1 -> R2` | `PP` |
| Buy reversal | `R1` | `PP` | `R2 -> R1 (BE)` | `R3` |
| Sell reversal | `S1` | `PP` | `S2 -> S1 (BE)` | `S3` |
| Buy reversal | `R2` | `R1` | none | `R3` |
| Sell reversal | `S2` | `S1` | none | `S3` |
| Buy | `R3` | none | deny `NO_FORWARD_LEVEL` | none |
| Sell | `S3` | none | deny `NO_FORWARD_LEVEL` | none |

Filled positions copy the complete ladder and route into ticket-owned state, so
later pivot-window refreshes cannot alter their geometry. Buy milestone reach
uses live Bid; sell milestone reach uses live Ask. A multi-level gap selects the
strongest new stop and submits at most one modification for that tick. Failed
modifications keep the confirmed broker stop and retain the stronger desired
stop for a safe retry; protection never widens or disappears.

## Before And After A Fill

Before a real position exists, local state owns the identity, trigger facts,
captured ladder/route, broker observations, and send attempt.

After a fill, the broker owns:

- order, deal, position ticket, and position identifier;
- executed volume and entry price;
- current broker-side stop loss and terminal take profit;
- open/closed state, close price/time, and realized profit.

Reconciliation selects the owned ticket first and verifies symbol, stable
pivot namespace magic, direction, and execution comment. Local state may copy
broker facts but never manufacture or overwrite them.

## Mandatory Broker Checks

The observation snapshot is telemetry. The fresh pre-send snapshot is
authority. Execution fails closed when any required condition is missing:

- `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`;
- actual broker session open and compatible symbol trade mode;
- account, expert, terminal, and MQL trading permission;
- valid current Bid/Ask and point size;
- directional entry/SL/TP geometry;
- stops and freeze distances;
- volume min/max/step and normalized volume;
- free margin, calculated margin, and successful `OrderCheck`;
- accepted `OrderSend` retcode and reconciled owned ticket.

Spread is exported as an observed cost. There is no configurable spread guard,
and the engine never changes pivot prices to make invalid geometry pass.

## Lot And Protection Contract

- `EXECUTION_LOT_FIXED_SIZE`: `Lot_Strategy_Size` is requested lots.
- `EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT`: `Lot_Strategy_Size` is the percent
  of current balance risked between the actual planned entry-side price and
  captured structural initial SL.
- Broker volume rules normalize the result without silently increasing risk to
  the minimum; invalid or unaffordable volume blocks execution.
- Every allowed route requires broker-side initial SL and terminal TP. There is
  no partial close, fixed-R target, virtual-only protection, or multi-leg state.

## Time Ownership

Broker time owns pivot bars, M1 context, first-touch order, actual sessions,
durations, orders, trailing, and reconciliation. Analysis time is derived only
for exported research facts.

| Mode | Broker time | Analysis time | Execution effect |
| --- | --- | --- | --- |
| `FIXED_TIME_SESSIONS` | preserved | unchanged | none |
| `EXNESS_SESSION`, DST active | preserved | unchanged | none |
| `EXNESS_SESSION`, winter | preserved | broker time minus 60 minutes | none |

Exness metal prefixes use UK DST dates; other symbols use US DST dates. Every
time-bearing V9 row retains broker time, analysis time, and offset. Causal
sorting uses broker time plus stable identities, never analysis time alone.

## V9 Data Ownership

The sole active export contract contains:

- `run_manifest.tsv`
- `pivot_windows.tsv`
- `pivot_levels.tsv`
- `signal_attempts.tsv`
- `signal_features.tsv`
- `execution_checks.tsv`
- `trailing_events.tsv`
- `signal_outcomes.tsv`
- `run_summary.tsv`

Each complete attempt has exactly six feature rows for `M1`, `M15`, `M30`,
`H1`, `H4`, and `D1`. Each row contains Stoch Structure slots `0..2` and raw
`%B` shifts `0..5`; shift `0` uses trigger Bid. Missing feature facts invalidate
the exported run but do not change execution. Outcomes require broker-confirmed
entry and close evidence.

Current DuckDB/Parquet, audit, and XGBoost code is offline-only. It cannot load
into MT5, approve a runtime artifact, filter an attempt, or alter broker state.
Older export revisions require their historical repository revision and are not
adapted or relabeled by current tooling.

## Frontend Boundary

The frontend is optional inspection output: at most 16 active positions, each
with intended entry, current broker SL, terminal pivot TP, and a compact
timeframe/level/direction label. It has no buttons or execution controls.
Nonvisual Strategy Tester runs skip all chart-object work.

## Non-Goals And Rollout

- No license, entitlement, public account, or public magic settings.
- No user trading-hours, configurable pivot formulas/timeframes, synthetic
  bars, spread threshold, drawdown/daily limit, direction, or concurrency rule.
- No pending limit orders, `R4/S4`, partial TP, or multi-leg lifecycle.
- No runtime model scoring, filtering, pattern playback, or online learning.
- No live rollout approval.

Any future runtime handoff requires older-engine positions flat for the symbol,
a hedging account, and one EA instance per account and symbol.
