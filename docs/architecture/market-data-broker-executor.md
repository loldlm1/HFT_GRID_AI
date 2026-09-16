# H1/M10 Pivot Collector And Broker Executor

## Purpose

The EA owns one deterministic market-data boundary: classic pivot ladders from
previous completed broker candles, immutable H1 and nested M10 research facts,
and one structural H1 `1R` broker lane. It is not a generic strategy, grid,
licensing, risk-dashboard, model-serving, or multi-leg execution framework.

The EA property version is `1.40`; the export schema is separately versioned as
`14`, with signal source `PIVOT_FRACTAL_V2`. See the [current index](../README.md)
for source/compile pins and open operational gates.

## Public Inputs

| Group | Inputs and defaults |
| --- | --- |
| `+= Market Data Time =+` | `Broker_Session=FIXED_TIME_SESSIONS`, `Macro_Timeframe=PERIOD_H1`, `Deep_Timeframe=PERIOD_M10`, `Micro_Timeframe=PERIOD_M3` |
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
broker tick
-> reconcile the one real structural H1 1R lane
-> refresh causal Macro context on bar change or bounded data retry
-> resolve H1 virtual first touches and midpoint state
-> discover H1 live-Bid pivot identities
-> capture Macro/Deep features against each origin's touched pivot
-> perform fresh broker checks and submit at most one FOK structural request
-> resolve/censor active deep parent links
-> freeze eligible active H1 parents in both directions
-> refresh the causal Deep window while eligible parents exist
-> discover one shared M10 event per consumed deep identity
-> capture one Deep/Micro snapshot and shared deep 1R/2R/3R geometry
-> serialize strict V14 facts
```

H1 terminal transitions are processed before same-tick M10 discovery. Research
state never authorizes, denies, delays, resizes, duplicates, closes, or modifies
the real broker order.

## Timeframes And Windows

`Macro_Timeframe`, `Deep_Timeframe`, and `Micro_Timeframe` are explicit supported
periods. Initialization validates normalized `PeriodSeconds` ordering:
`Micro < Deep < Macro`; defaults are `M3 < M10 < H1`. The EA uses broker-native
active bars and the previous completed source candle (`shift 1`). A current bar
whose open is later than the observed tick is not causal. Weekend/session gaps
do not create synthetic windows.

Each H1 and M10 window retains raw and trade-tick-normalized
`PP`, `S1..S3`, and `R1..R3` with strict ladder ordering. Window identity and
trigger ordering are independent of analysis-time display/DST fields.

`FIXED_TIME_SESSIONS` preserves analysis timestamps. `EXNESS_SESSION` retains
broker timestamps and applies the implemented symbol/calendar winter analysis
adjustment of `-60` minutes. Neither changes source ticks, broker bars, scheduling,
triggers or orders. The existing custom-symbol session choices are in the current
index; they do not change the public input default.

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
price from the touched pivot toward its next outward structural stop; its clock
starts only on the first executable midpoint touch. The shared midpoint remains
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

## Deep M10 Evidence

Deep capture is research-only and requires at least one entered eligible H1
virtual lane or confirmed broker fill, in either direction. No event is collected
without an active Macro parent. The event identity is:

```text
(symbol, Deep_Timeframe, active Deep bar open, level)
```

One event stores one Deep/Micro indicator vector, and one
event-level shared trial for each deep ratio `1R`, `2R`, and `3R`. Parent links
associate the event with every eligible H1 parent active at the trigger. A link
stores its parent identity, entry time, exact `m10_parent_age_seconds`,
`parent_direction`, `deep_direction` and `direction_relationship`
(`ALIGNED`/`OPPOSED`). Outcome `direction` owns Deep execution; outcome
`parent_direction` resolves the origin. Features are never copied into link/ratio
rows. H1/M10 identifiers denote roles; the manifest owns their actual periods.

Freeze the active-parent set immediately before discovery. Later entries or fills
are never linked retroactively; direction is an immutable trigger outcome, not a
second event identity. Invalid deep geometry remains explicit: it is never
reflected, stretched or routed to another stop.

The deep path uses the event executable quote and next outward M10 pivot as the
normalized stop. It never reaches `OrderSend`. A parent exit censors only that
link as `CENSORED_PARENT_EXIT`; a run stop uses `CENSORED_RUN_END`. The same
shared trial may resolve normally for another still-active parent. Observation
ends when no linked parent remains active.

Before broker signal cleanup, confirmed deal close time is retained on its
existing deep links. Unfinished children use that time for parent-exit censoring,
including when the run stops after closure. Missing or inconsistent close
evidence invalidates research integrity without changing broker execution.
Reconciliation may observe closure later: broker outcomes own the actual close
clock, while terminal execution checks retain reconciliation time. Observed
censor quotes remain observation evidence and produce no completed return or
binary label.

Admission reserves the complete fan-out atomically: one event, all frozen links,
three trials, and three outcomes per link. If it cannot fit, the event identity
is consumed and one `CAPACITY_REJECTED` row is emitted with no partial children.
Caps are 2048 events, 4096 links, 6144 trials, and 18432 outcomes.

Deep outcomes hold checked link/trial/event indices. A bounded pass reconciles
active counts, and stable compaction releases only whole terminal event groups,
remapping all retained indices together. Links own frozen parent membership;
there is no duplicate frozen-parent array. Cached H1/broker slots validate full
identity before use and fall back to lookup after their owning arrays move.
Both parent directions are collected in one pass before each discovery batch,
preserving H1-then-broker order and exact trigger-time ages.
Eligibility is rechecked every tick. Snapshot storage is reused only when every
metadata field and source slot still matches; departed parents are truncated
before discovery. No parent membership is cached without a current eligibility
check.

Deep quote/touch results are shared by trial only within one resolver invocation.
The scratch array resets on every invocation, including quotes in the same
serialized second, and is released on reset/failure. Each parent is checked before
using that result, so closed parents retain their separate censor path. Successful
profit calculations may be reused during that invocation; failures retain the
existing per-parent retry behavior. Compaction happens after all uses of indices.

## Broker Boundary

Only the structural H1 `1R` lane may send. The fresh pre-send path rechecks
session, symbol mode, hedging mode, permissions, Bid/Ask, stops/freeze, volume,
FOK support, margin, and `OrderCheck`. Broker SL/TP are immutable after fill;
there is no trailing, break-even, partial close, resize, or `TRADE_ACTION_SLTP`.

V14 derives magic namespace `HFT_GRID_AI_PIVOT_FRACTAL_V14`; older-engine
positions are never adopted, closed, or modified. One accepted request creates
one exact submitted-geometry parity shadow outside H1/deep target cohorts.
Its `distance_eligible` field reports the stricter research minimum as a fact;
that field may be false for a broker-accepted request and does not veto its
calibration shadow. Broker stops/freeze checks and immutable prices are unchanged.

Capture and freshly recheck point/trade tick, spread, volume min/max/step,
requested and downward-normalized volume, free margin, profit/margin calculation
results, full-fill support and request/send retcodes. Preserve ticket/fill,
protection, close and deal-history facts. Non-hedging accounts collect evidence
but cannot send. File diagnostics use captured broker event time; denied attempts
show unavailable request/volume/quote facts as `n/a`, separate from reference risk.

## Features And Duration

When export is enabled, exactly six cached handles exist: Macro/Deep/Micro Bands
and Stochastic. Fixed settings are Bands `21/0/2.0`, SMA,
`PRICE_WEIGHTED`; Stochastic `K=5`, `D=3`, slowing `3`, `MODE_SMA`,
`STO_CLOSECLOSE`. Origins own `origin_macro_*` and `origin_deep_*` on
`signal_origins.tsv`; events own `deep_deep_*` and `deep_micro_*` on
`deep_pivot_events.tsv`. Each block has a completeness flag; the snapshot flag
requires both blocks. Missing blocks remain explicit and exclude only the
corresponding model cohort. Each pair freezes at its own trigger: later Deep
events cannot populate an earlier Macro snapshot.

Handles are initialized once and safely released after partial initialization or
normal deinitialization; export-off creates no research handles or deep/export
state. `%B` uses the immutable touched pivot, remains unclipped, and exports raw,
SMA 5, SMA slope, state, Band base-line/slope and shift-0 width facts according to
the strict headers. Missing feature data marks research incompleteness only.

`h1_structural_lifecycle_seconds` is exact broker-time duration from a lane's
own entry to a confirmed close. `m10_parent_age_seconds` is exact parent entry
to M10 trigger age. Neither is rounded or capped. The downstream application
maps them to separate `<= minutes * 60` research predicates; H1 duration is
retrospective and excluded from causal/model features.

Duration starts at each lane's own executable entry, including the midpoint.
`NOT_TRIGGERED`, `INELIGIBLE` and `CENSORED_RUN_END` have null completed H1 duration.
The two inclusive minute selectors combine with AND during research; they never
delete later raw events or cap producer capture.

Confirmed broker entry and close may serialize to the same second, giving a
valid duration of zero. Reversed clocks and duration mismatches are rejected;
second-resolution fields do not establish actual subsecond latency.

## Export And Include Boundaries

V14 writes twelve files under
`Common\\Files\\PivotFractalV14\\runs\\<run_id>\\` in this order:

```text
run_manifest.tsv
pivot_windows.tsv
signal_origins.tsv
virtual_trials.tsv
virtual_outcomes.tsv
deep_pivot_events.tsv
deep_pivot_parent_links.tsv
deep_virtual_trials.tsv
deep_virtual_outcomes.tsv
execution_checks.tsv
broker_outcomes.tsv
run_summary.tsv
```

The entrypoint's ordered aggregators are
`services/trading_tools.mqh`, `services/trading_management.mqh`,
`services/trading_signals.mqh`, and `services/frontend.mqh`. Aggregators own
include order; no sibling cycles or per-tick handle creation are permitted.
The frontend is read-only and cannot influence execution. It draws at most 16
owned positions and performs no chart work in nonvisual tester runs. Avoid
per-tick handle creation, unbounded logging and full-history scans in hot paths.

The Python validator accepts strict V14 only, builds native-grain H1/deep/
broker/calibration artifacts, audits referential integrity and leakage, and
trains explicit offline H1 or deep candidates. No runtime model artifact or
execution filter is produced.

Fatal export or research-integrity failures latch the first operation, broker
clock and bounded state context. The journal diagnostic is unconditional, even
with both debug switches off; best-effort persistence uses
`Common\\Files\\PivotFractalV14\\diagnostics\\<run_id>.failure.txt` outside the
strict dataset. Secondary teardown errors cannot replace the first cause.
The EA requests one tester-only stop at the event boundary. Research is sealed
before tester scoring, including its final flush; a failed run has a zero custom
score and a `FAILED` / `CENSORED` summary when writable. An absent successful
seal also invalidates the run. Valid ineligible, no-touch and capacity-rejected
rows remain explicit outcomes. This research policy adds no live order control.
Confirmed closed broker bookkeeping is removed after handing its close clock to
existing research links, regardless of export success. A fatal research failure
releases its buffers, pending origins, H1/deep state and indicator handles once,
retaining first-error and peak evidence. Open/unresolved broker ownership stays
with normal reconciliation. Export initialization failure stops tester startup;
live broker processing continues independently with research disabled.

Rows are validated once when queued and remain immutable in their buffers.
Expected column counts use a bounded cache of the twelve exact headers. Each
256-row flush encodes rows directly into a reserved ANSI byte array with CRLF
endings and writes the exact byte count in one operation. Missing-file and
current-header checks still run before each append; short writes fail the export.
The batch buffer is local to the append and released when the call returns.

Finite numeric TSV facts use 17 significant digits to round-trip runtime doubles.
This preserves strict price comparisons such as a bid below PP even when the two
numbers would round to the same ten-decimal string. This numeric format preserves
causal comparisons and submitted prices; V14 separately versions the paired
feature and direction contract.

The bounded DuckDB parent chronology audit checks parent intervals and labels
separately from full semantic validation. Timestamp-only historical recovery
creates a distinct derivative with adjacent correction/provenance sidecars and
preserves source exports. The [parent-close acceptance record](../research/parent-close-chronology-acceptance-2026-09-09.md)
documents the corrected producer, focused tester parity and recovered-run limits.

The [research tool guide](../../tools/deterministic_signal_ml/README.md) owns
typed intake, native-grain artifacts, leakage/support rules and offline training
procedures. [Environment validation](../environment/mt5-agentic-workflows.md)
owns compile and operator acceptance procedures. No document authorizes live rollout.
