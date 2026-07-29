# Market Data Collector And Broker Executor

## Purpose

The EA has one responsibility boundary: observe the fixed M1 extremum source,
record deterministic market/broker facts, and optionally execute one broker
position for each admissible intrinsic attempt. It is not a general strategy
framework, licensing platform, risk dashboard, session scheduler, or multi-leg
grid engine.

## Runtime Sequence

```text
minimal inputs
-> fixed M1 indicator hydration
-> provisional extremum observation
-> cycle/revision/attempt state
-> observation-time broker snapshot
-> optional schema v8 write
-> broker-time breakout observation
-> PRE_FILTER broker eligibility
-> tester-only pattern and ML denial
-> PRE_SEND broker eligibility and OrderCheck
-> OrderSend with broker SL and 1R TP
-> SEND_RESULT fact
-> ticket-first broker reconciliation
-> broker-confirmed outcome
```

Observation and broker checks run even when persistence is disabled.
`Enable_Signal_Feature_Export` controls file output, not whether eligibility is
evaluated.

## Extremum Ownership

- `EXTREMUM_V1` and `PERIOD_M1` are fixed constants.
- Stoch Structure slot `0` is the provisional source.
- `BOTTOM` derives `BULLISH`; `PEAK` derives `BEARISH`.
- Completed slots `1` and `2` freeze the cycle range.
- A deeper same-type source creates a revision. A type transition finalizes the
  cycle.
- Raw depth may extend below `0` or above `100`; analytics may map it to
  Fibonacci proximity without changing the runtime value.
- The same source/revision is deduplicated, while distinct attempts may coexist.

## Before And After A Fill

Before a real position exists, local state owns the attempt ID, trigger,
structural stop anchor, planned 1R target, eligibility facts, and send attempt.

After a fill, the broker owns:

- order, deal, position ticket, and position identifier;
- executed volume and entry price;
- broker-side stop loss and take profit;
- open/closed state, close price/time, and realized profit.

Reconciliation selects the owned ticket first and verifies symbol, stable
internal magic, direction, and execution comment. Local state may copy broker
facts but never manufacture or overwrite them.

## Mandatory Broker Checks

The observation check is telemetry. The fresh pre-send check is authority.
Execution fails closed when any required condition is missing:

- `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`;
- actual broker session open and compatible symbol trade mode;
- account, expert, terminal, and MQL trading permission;
- valid current bid/ask and point size;
- directional entry/SL/TP geometry;
- stops and freeze distances;
- volume min/max/step and normalized volume;
- free margin, calculated margin, and successful `OrderCheck`;
- successful `OrderSend` retcode.

Spread is exported as an observed cost. There is no configurable spread guard.

## Lot And Protection Contract

- `EXECUTION_LOT_FIXED_SIZE`: `Lot_Strategy_Size` is requested lots.
- `EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT`: `Lot_Strategy_Size` is the percent
  of current account balance risked at the structural stop.
- Broker volume rules normalize the result; invalid or unaffordable volume
  blocks execution.
- Every order requires a broker-side structural stop and a fixed 1R broker-side
  take profit. There is no partial TP, virtual-only protection, multiplier, or
  multi-leg lifecycle.

## Time Ownership

Broker time owns bars, breakout timing, actual session checks, durations,
orders, and lifecycle ordering. Analysis time is derived only when building
export, ML, audit, or pattern facts.

| Mode | Broker time | Analysis time | Execution effect |
| --- | --- | --- | --- |
| `FIXED_TIME_SESSIONS` | preserved | unchanged | none |
| `EXNESS_SESSION`, DST active | preserved | unchanged | none |
| `EXNESS_SESSION`, winter | preserved | broker time minus 60 minutes | none |

US30 therefore keeps a deterministic `13:30` analysis open across a summer
broker open at `13:30` and a winter broker open at `14:30`. Exness metal
prefixes use UK DST dates; other symbols use US DST dates. Each normalized row
retains the offset, and causal sorting uses broker time plus stable identity.

## Data Ownership

Schema v8 is the sole active export contract:

- `engine_cycles.tsv`
- `engine_revisions.tsv`
- `engine_attempts.tsv`
- `execution_checks.tsv`
- `signal_features.tsv`
- `signal_outcomes.tsv`
- `run_manifest.tsv`
- `run_summary.tsv`

Simulation labels live only with intrinsic attempts. `signal_outcomes.tsv`
requires broker-confirmed entry and close evidence. Historical schemas remain
immutable and require their historical repository revision.

## Research Filters

Broker checks run before research filters. `ML_INFERENCE_SHADOW` never changes
execution. `ML_INFERENCE_FILTER` and pattern playback are Strategy Tester-only
and may only deny an otherwise eligible send. They cannot create trades,
resize volume, alter SL/TP, or change reconciliation.

## Frontend Boundary

The frontend is optional human-inspection output: at most eight recent bullish
and eight recent bearish attempts, each with entry, SL, and TP lines. It has no
buttons or execution controls. Nonvisual tester runs skip all chart-object
work.

## Non-Goals

- No license or entitlement layer.
- No public account/magic settings.
- No user trading-hours filters or synthetic missing bars.
- No configurable spread, drawdown, daily-limit, direction, or concurrency
  rules.
- No generic strategy plug-in or multi-leg execution framework.
- No live rollout approval and no approved schema v8 runtime model.
