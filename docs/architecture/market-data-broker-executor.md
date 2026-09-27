# Pivot Macro Collector And Broker Executor

## Purpose

The Pivot EA owns causal Macro pivot discovery, eight virtual Macro lanes and one
structural 1R broker lane. Shared capture supplies features and dataset facts;
engine-specific code retains order ownership and lifecycle decisions.

`Pivot_Macro.mq5` is version `2.10`, engine `PIVOT_MACRO_V2`, common schema `1`.
The [shared contract](model-feature-dataset.md) owns headers, features and clocks;
the [current index](../README.md) owns source/compile pins and acceptance gates.

The separate `Candle_Pattern_Discovery.mq5` is version `2.10`, engine
`CANDLE_PATTERN_ATR_V3`. It shares capture services but retains Micro patterns,
ATR stops, both broker directions, one confirmed-SL re-entry and per-entry
Macro-duration expiry. Its engine policy is in the shared contract. Historical
Candle and Pivot readers retain their original identities.

## Public Inputs

The active [entry-quality/lifecycle plan](../../mql5-entry-quality-lifecycle-plan.md)
delivers both new engine identities. The
[dataset contract](model-feature-dataset.md#registered-entry-quality-profiles)
owns their admission formula and deadline precedence. Candle now enforces the
fixed gate for fresh originals/re-entries and their virtual lanes. It retains
actual fills separately and never applies the gate to an expiry close. Its new
magic namespace is `0x434e4433` plus the symbol fingerprint. Pivot applies the
same admission gate to fresh structural/broker entries and midpoint touches.

| Group | Inputs and defaults |
| --- | --- |
| `+= Market Data Time =+` | `Broker_Session=FIXED_TIME_SESSIONS`, `Macro_Timeframe=PERIOD_H1`, `Micro_Timeframe=PERIOD_M3` |
| `+= Broker Execution =+` | `Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`, `Lot_Strategy_Size=0.01` |
| `+= Signal Statistics Export =+` | `Enable_Signal_Feature_Export=false`, `Signal_Feature_Run_Id=""` |
| `+= Developer Debug Settings =+` | `Enable_Logs=false`, `Enable_File_Logs=false` |

`Lot_Strategy_Size` selects requested lots in fixed mode or percentage risk from
the fixed `1,000,000` reference in reference-balance mode. The default `0.01`
percent means a `100` account-currency reference budget, not live-balance risk.
Pivot formulas, feature parameters and protection rules are not public controls.

Do not restore licensing, account settings, configurable protection, user trading
hours, spread thresholds, direction/concurrency selectors, multi-leg risk,
partial TP, daily limits, lot sequences, runtime model/pattern controls, Bands
policies, retries or compatibility aliases. The collector runs continuously;
actual broker trading sessions still gate the real order.

## Runtime Ownership

```text
broker tick -> observe shared Macro context and closed/live M1 structure
-> reconcile the real structural Macro 1R lane
-> refresh causal Macro context on bar change or bounded data retry
-> resolve virtual first touches and midpoint state
-> discover direction-independent live-Bid pivot identities
-> freeze one Macro/Micro feature snapshot per origin
-> perform fresh broker checks and submit at most one FOK request
-> serialize common facts through the Pivot adapter
```

Research state never authorizes, denies, resizes, duplicates, closes or modifies
the real broker order. Feature gaps and dataset errors cannot veto an entry.

## Timeframes And Windows

`Macro_Timeframe` and `Micro_Timeframe` are explicit supported native periods,
validated through `PeriodSeconds` with `Micro < Macro`; defaults are M3 < H1.
Generic M10 remains supported. Pivot permits MN1; Candle excludes monthly roles.
The fixed M1 structure source is independent of these configurable roles.

Pivots use the previous completed native broker candle, shift 1. A future active
bar does not invalidate an already causal engine window. Missing data retries
are bounded; no synthetic bars or wall-clock aggregation replaces broker bars.
Windows preserve raw and trade-tick-normalized PP, S1..S3 and R1..R3 ladders.

`FIXED_TIME_SESSIONS` preserves analysis timestamps. Explicit `EXNESS_SESSION`
requires prepared UTC/Shift=0 sources and uses shared `EXNESS_NEW_YORK_V1` for
all symbols, including metals. Winter analysis time is raw minus 60 minutes;
summer equals raw. Analysis time never governs triggers, expiry or order sorting.
Old V14 exports retain their original clock interpretation in their old reader.

## Pivot Identity And Triggers

Identity is `(symbol, timeframe, active bar open, level)` and is consumed on the
first eligible live-Bid trigger. Direction is an outcome, not an identity field.

- `S1..S3`: buy when `Bid <= level`.
- `R1..R3`: sell when `Bid >= level`.
- PP: first strict Bid side arms support/resistance, then a return touch triggers.
- Equality at PP remains neutral until a strict departure.

Same-batch order is buy-armed `PP`, `S1`, `S2`, `S3` downward and sell-armed
`PP`, `R1`, `R2`, `R3` upward. Buy triggers use Bid and executable entry uses
fresh Ask; sell trigger and entry use Bid.

H1 consumption is final even if its broker route is denied or the send fails.
Buy stops map `PP -> S1`, `S1 -> S2`, `S2 -> S3`, then one extrapolated boundary
below S3; sells are symmetric through R3. The pre-send TP is exactly one fresh
executable quote's price-distance R from that structural stop.

## H1 Lanes

Every export-enabled consumed origin declares exactly eight virtual lanes:

```text
STRUCTURAL x 1R, 2R, 3R, 5R
MIDPOINT_50 x 1R, 2R, 3R, 5R
```

Structural lanes enter at the H1 trigger. The midpoint is the exact halfway
price from the touched pivot toward its next outward structural stop. Bid owns
the trigger in both directions; buys then enter at Ask and sells at Bid. The
entry clock starts at that observed touch. The shared midpoint remains
armed while any structural lane from the origin is active, including after H1
bar rollover. If the final structural lane exits first, untouched midpoint lanes
are `NOT_TRIGGERED`; they are not losses. Once touched, midpoint ratios resolve
independently from their shared entry.

There are no Bands-width policies, retry/re-entry generations, continuation
rows, or retry-cap transitions. Stops use the next outward pivot, with the
existing S3/R3 extrapolation. Virtual buys enter at Ask and resolve on Bid;
virtual sells enter at Bid and resolve on Ask. Stops normalize outward to the
trade-tick grid and exact integer-R targets are rebuilt from normalized risk.
Invalid geometry, distance, money, no-touch, and run-end states are explicit.

The H1/parity active-state cap is `2048`. Run termination censors unresolved
entered lanes and never reports them as SL losses. R5 has no special midpoint
controller role; any surviving structural lane keeps the shared pending entry armed.

## Broker Boundary

Only the structural H1 `1R` lane may open a broker position. The fresh pre-send path rechecks
session, symbol mode, hedging mode, permissions, Bid/Ask, stops/freeze, volume,
FOK support, margin, and `OrderCheck`. Broker SL/TP are immutable after fill;
there is no trailing, break-even, partial close, resize, or `TRADE_ACTION_SLTP`.

Pivot derives symbol-scoped magic from `HFT_GRID_AI_PIVOT_MACRO_V2`; older-engine
positions are never adopted, closed, or modified. One accepted request creates
one exact submitted-geometry parity shadow outside virtual/broker target cohorts.
Its admission evidence copies the accepted request and cannot be independently
re-vetoed by research. V2 admitted entries require the fixed three-spread minimum.
V1's older independent research distance flag remains a historical contract.

Each entered Pivot lane expires at its own raw entry milliseconds plus the native
Macro duration. Broker deadlines use confirmed fills; parity uses the request;
midpoints use their own later touch. Before the deadline TP/SL wins, while a close
at or after it is TIME_EXIT with its original native reason retained separately.
One-second timer callbacks perform lifecycle work only, without discovery, new
midpoint activation or feature capture. No fresh quote means no invented exit.

Expiry reconciles before sending a ticket-bound FOK close. One request remains
in flight until its terminal order/deal is known; definitive refusals retry no
more than once per raw second, and 30 seconds of unresolved ownership latch a
diagnostic. Close requests do not run entry admission or change original SL/TP.
Close reconciliation selects the owned position's history, capped at 64 deals.
New entry state, close ownership and research delivery remain independent.

A delayed close can precede the next observed quote. A research-only queue holds
up to 2048 immutable closed records until that quote reaches the deal clock;
execution releases the confirmed closed position immediately. The queue performs
no orders. An unavailable observation at run end fails research explicitly.
It never backdates observation or changes actual close/duration facts.

Capture and freshly recheck point/trade tick, spread, volume min/max/step,
requested and downward-normalized volume, free margin, profit/margin calculation
results, full-fill support and request/send retcodes. Preserve ticket/fill,
protection, close and deal-history facts. Non-hedging accounts collect evidence
but cannot send. File diagnostics use captured broker event time; denied attempts
show unavailable request/volume/quote facts as `n/a`, separate from reference risk.

## Features And Dataset

The [shared contract](model-feature-dataset.md) defines six shifts of native
Stochastic K/D, ordinary weighted-price percent B/SMA5 and ATR13/SMA5 for both
roles, plus Macro pivot zones and confirmed/forming M1 structure. Shift 0 freezes
at observation. Each historical percent B value uses its own candle's weighted
price. Warmup is bounded to 4,096 prior closed M1 bars; runtime catch-up is 256
bars per callback. A live projection never commits a forming reversal.

Research owns six Macro/Micro handles plus M1 Stochastic; Micro M1 reuses its
Stochastic handle. Candle's execution ATR remains independently owned. Export
off creates no research handles or active research states. Partial availability
is explicit per family; no per-tick handle creation or chart work occurs.
Request the bounded indicator buffer before checking calculated-bar readiness:
nonvisual testing computes on demand, so a readiness-only early return can latch
startup unavailability. Keep warmup/count/value checks and never backfill snapshots.

Pivot emits ten TSVs, Candle eleven, in
`Common/Files/MQL5ModelDatasetV1/runs/<run_id>/`. Common facts separate signal,
attempt, feature snapshot, trial, execution check and outcome grains. Pivot
extensions retain origin/consumption geometry and all eight lane policies.
Its broker IDs are opaque strings, not native order/deal ticket integers.

Tick and deal milliseconds accompany existing second-based runtime scheduling.
Second-only facts are explicitly marked SECOND; missing clocks remain null.
Completed duration is exact entry-to-close milliseconds. No-touch, ineligible
and run-censored records have no completed exit/duration/return/binary label.
Actual broker close time and the later observation remain distinct. Parity is
always excluded from target cohorts, including when its independent shadow wins.
Submitted geometry, costs, fill deviation, request/check evidence and terminal
reasons remain available. Unknown virtual costs/net are null.

Only the new strict [reader](../../tools/model_dataset/README.md) accepts this
family. Historical [V14 tooling](../../tools/deterministic_signal_ml/README.md)
and [Candle tooling](../../tools/candle_pattern_ml/README.md) retain their own
headers, fixtures and datasets; there is no conversion or dual writer.

## Performance Contract

Every engine or feature declares the callbacks that advance closed state,
project live state, capture features and write rows. Record the work bound per
callback/bar/snapshot, readiness retries and ownership of execution resources.
Timers retain broker reconciliation and expiry responsibilities.

Retained application state depends on active lifecycles and fixed windows.
Declare handle, active-record, cache and pending-work caps; reuse inactive slots
and release completed state. Current bounds are seven shared handles, a separate
Candle execution ATR, 4096/256 structure bars, 2048 Pivot trial states, and
Candle's 2048 broker / 6144 virtual states with 64 deals per selected position.
Writer limits remain 256 rows / 1 MiB per table; completed rows stay on disk.

Reuse generated field IDs, clock offsets and shared providers. Avoid per-tick
handle creation, full-history containers, field-name searches and large state
copies on callbacks without a transition. Retain transactional copies where
mutation or failure recovery requires them. Cache only proven immutable facts;
declare invalidation for symbol, role, parameters, source readiness/history,
bar/quote identity and failures. A timestamp alone is not a snapshot cache key.

Optimization preserves callback/row order, exact prices/clocks, shift-0 values,
labels, explicit gaps/censors and broker decisions. Require matched export-on/off
broker results, exact dataset/feature comparisons and failure/seal checks.
Measure release builds after warmup with at least three alternating short/medium
pairs, early/late workloads and growing history. Normalize work by ticks,
captures, active occupancy, selected deals and bytes. Report native retained
history separately from application state; neither stable RSS nor elapsed days
alone proves bounded cost. Shared changes validate both existing engines.
The [runbook](../environment/mt5-agentic-workflows.md#model-runtime-benchmarks)
owns resource guards, measurement details and promotion criteria.

## Failure And Include Boundaries

The entrypoint keeps ordered aggregators `services/trading_tools.mqh`,
`services/trading_management.mqh`, `services/trading_signals.mqh` and
`services/frontend.mqh`. Shared capture receives explicit configuration and
imports pure pivot calculations; it never imports engine inputs or broker state.
The Pivot adapter owns pending origins/parity links and the engine owns virtual
and broker state. No active Deep input, discovery, fan-out, handle or output
exists. The frontend stays read-only, limits owned positions to 16 and performs
no chart work in nonvisual tester runs.

Each table buffers at most 256 rows or 1 MiB of encoded bytes. Oversized rows
are split into bounded writes with unchanged UTF-8/CRLF bytes; only complete
rows increment counts. Generated table-qualified field IDs and clock offsets
preserve the schema while rejecting wrong-table/type access. Headers and writes are checked;
run IDs are fresh, and successful intake requires an unchanged complete seal.
The first fatal research cause is retained, persisted outside the dataset when
possible, and invalidates any earlier seal with FAILED.txt. Research resources
are released once; unresolved broker ownership stays with reconciliation.
Only the tester is stopped. Normal feature gaps are not fatal export failures.
Finalization seals FAILED/CENSORED when writable and scores failed research zero.

The [environment guide](../environment/mt5-agentic-workflows.md) owns native
compilation and operator acceptance. Earlier V14 source/details are recoverable
at `f5920fb:docs/architecture/market-data-broker-executor.md`; dated acceptance and
recovered-run evidence remain reachable through the index. Nothing here grants
live deployment authority.
