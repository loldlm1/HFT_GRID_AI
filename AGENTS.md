# HFT Grid AI - Agent Brief

This repository is an always-on Macro/Micro pivot-band market-data collector
with one small broker execution path. Keep active code and documentation
focused on that contract; historical plans and evidence remain under their
archive directories.

## Entrypoint And Active Work

- Entrypoint: `HFT_Grid_AI.mq5`.
- Active plan: none. The completed V11 dataset type-registry correction is
  archived under
  `docs/plans/archive/v11-dataset-column-type-registry-2026-08-07/`.
- Architecture: `docs/architecture/market-data-broker-executor.md`.
- Environment runbook: `docs/environment/mt5-agentic-workflows.md`.
- Statistics workflow: `docs/workflows/pivot-fractal-statistics-flow.md`.
- Research boundary: `docs/workflows/pivot-fractal-offline-research-boundaries.md`.

## Skill Stack

Use only skills that match the task and are installed under
`/home/loldlm/.codex/skills`:

- `mql5-production-engineering` for `.mq5`/`.mqh`, broker execution,
  MetaEditor, and Strategy Tester work.
- `token-saver-orchestrator` for RTK-first inspection and compact command
  evidence.

Do not list or invoke unavailable skills as project requirements.

## Public Input Contract

The active EA exposes only these groups:

| Group | Inputs |
| --- | --- |
| `+= Market Data Time =+` | `Broker_Session`, `Macro_Timeframe`, `Micro_Timeframe` |
| `+= Broker Execution =+` | `Lot_Type`, `Lot_Strategy_Size` |
| `+= Signal Statistics Export =+` | `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id` |
| `+= Developer Debug Settings =+` | `Enable_Logs`, `Enable_File_Logs` |

Defaults are `Macro_Timeframe=PERIOD_H1`, `Micro_Timeframe=PERIOD_M3`,
`Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`, and
`Lot_Strategy_Size=0.01`. Timeframes must be explicit and supported, distinct,
and Micro must be shorter than Macro.

Do not restore licensing, account settings, configurable protection,
user-defined sessions, spread thresholds, direction/concurrency selectors,
multi-leg risk, partial TP, daily limits, lot sequences, runtime model/pattern
controls, or compatibility aliases for removed inputs.

## Runtime Contract

```text
broker tick
-> reconcile the one real structural 1R broker lane
-> resolve active virtual trial TP/SL first touches and bounded re-entries
-> refresh one causal Macro pivot window when its broker bar changes or retry is due
-> calculate PP/S1..S3/R1..R3 from the previous completed Macro candle
-> arm PP from the first causal live Bid side
-> discover unconsumed live-Bid virtual-limit triggers
-> capture one shared Micro/Macro weighted-Bands snapshot per tick batch
-> derive candidate-specific Macro pivot %B
-> build immutable structural SL and fresh quote 1R TP
-> perform observation and fresh pre-send broker checks
-> submit one FOK market order with broker SL/TP
-> declare an independent sixteen-cell virtual research matrix when export is enabled
-> create one accepted-request broker-parity shadow after a successful send
-> export separate virtual, broker, calibration, and strict schema V11 facts
```

- `PIVOT_FRACTAL_V2` is the only signal source. One configured Macro timeframe
  creates classic `PP`, `S1..S3`, and `R1..R3` from broker shift `1`.
- Each valid set lives for its actual broker-native active bar. No wall-clock
  aggregation, incomplete source candle, or synthetic missing bar is allowed.
- Series visibility is subordinate to the observed tick: a current bar whose
  open is later than the tick cannot activate a window or feature snapshot.
- `S1..S3` are buy-only and trigger when live Bid is at or below the level.
  `R1..R3` are sell-only and trigger when live Bid is at or above the level.
- PP observed above arms a future support buy; PP observed below arms a future
  resistance sell. Equality remains neutral until Bid first leaves PP.
- Identity is `(symbol, Macro timeframe, active bar open, level)`. First
  trigger consumes it even when routing or broker execution is denied or
  fails. Direction is an outcome and is not part of identity.
- Downward same-tick path order is buy-armed `PP`, `S1`, `S2`, `S3`; upward
  order is sell-armed `PP`, `R1`, `R2`, `R3`.
- Buy triggers use Bid and execute at fresh Ask. Sell triggers and execution
  use Bid. Trigger, pivot, request, fill, and close prices remain distinct.
- The stable nonzero magic is derived from the V2 namespace plus symbol.
  Older-engine positions must never be adopted, closed, or modified by V2.

## Route And Sizing Contract

- Buy stops: `PP -> S1`, `S1 -> S2`, `S2 -> S3`, and
  `S3 -> S3 - (S2 - S3)`.
- Sell stops: `PP -> R1`, `R1 -> R2`, `R2 -> R3`, and
  `R3 -> R3 + (R3 - R2)`.
- The authoritative pre-send buy TP is `Ask + (Ask - SL)`; the sell TP is
  `Bid - (SL - Bid)`. Normalized reward and risk price distances must be 1:1.
- `EXECUTION_LOT_REFERENCE_BALANCE_PERCENT` uses the fixed internal reference
  `1,000,000`, not live account balance. The default `0.01` percent requests a
  `100` account-currency risk budget before broker volume normalization.
- Volume normalizes downward. A broker minimum that would exceed the budget,
  unsupported FOK full-fill policy, invalid geometry, or failed profit/margin
  calculation blocks the send.
- Quote expected stop/profit money can differ despite exact price-distance 1R.
  Budget utilization, broker slippage, costs, and realized R remain separate.
- Broker SL and TP are immutable after fill. There is no trailing, break-even,
  partial close, position resize, or `TRADE_ACTION_SLTP` path.

## Virtual Trial Matrix Contract

- Export-enabled consumed origins declare sixteen index-0 virtual trials:
  `STRUCTURAL`, `MICRO_BW_13`, `MICRO_BW_21`, and `MICRO_BW_34`, each paired
  with `1R`, `2R`, `3R`, and `5R`.
- The structural policy uses the existing next-pivot stop and never re-enters.
  Volatility policies freeze the trigger Micro shift-0 full Bands width and use
  `0.13`, `0.21`, or `0.34` of it for every generation in that chain.
- A gap-through origin still declares all sixteen cells. If its next-pivot
  structural stop is equal to or on the wrong side of the fresh executable
  entry, the four structural cells are explicit `INELIGIBLE_GEOMETRY` rows;
  the stop is never reflected across entry and volatility cells remain
  independent.
- Virtual buys enter at observed Ask and resolve on Bid. Virtual sells enter at
  observed Bid and resolve on Ask. Stops normalize outward to the trade-tick
  grid, and TP is rebuilt from normalized risk ticks for exact integer R.
- Every matrix risk distance must be at least spread plus
  `max(stops level, freeze level)` plus one trade tick. Invalid cells are
  exported explicitly and never stretched, omitted, or routed to the broker.
- Each volatility `(SL policy, TP multiple)` chain re-enters only after its own
  `SL_FIRST`, at the next observed executable quote, with indices `0..3`.
  A TP completes only that chain; it never reopens.
- Inner-level retries require both entry and proposed SL to remain at least one
  trade tick inside the next outward pivot. Gap-through, expired-window,
  capacity, and retry-cap stops are explicit terminal facts. `S3`/`R3` use the
  same three-retry cap without an outer pivot boundary.
- Virtual state is bounded to `2048` active matrix/parity trials. Active trials
  may resolve after window expiry, but no new retry may be created then. Run
  termination censors remaining trials rather than relabeling them as losses;
  a naturally completed tester interval remains run-level `NATURAL`.
- Matrix trials, retries, and parity shadows are research-only. They cannot
  authorize, deny, delay, resize, duplicate, close, or modify the one real
  structural 1R broker order.

## Broker Safety Kernel

Every attempt captures broker facts when observed. Checks run again immediately
before a send; only the fresh result may authorize `OrderSend`.

Required facts and guards include:

- actual broker session and symbol trade mode;
- hedging margin mode and account/terminal/MQL trading permissions;
- current Bid, Ask, point size, and observed spread;
- structural entry/SL/TP geometry, stops level, and freeze level;
- volume min/max/step, requested/normalized volume, FOK support, free margin,
  and `OrderCheck`;
- send retcode/comment and symbol/magic/ticket reconciliation.

Spread and live account balance are telemetry, not configurable authorization
thresholds. Pivot prices are never moved to force broker geometry to pass.
Broker facts own ticket, volume, entry, immutable SL/TP, close state, and
realized profit after a fill.

## Deterministic Time

- `FIXED_TIME_SESSIONS`: analysis time equals broker time and offset is `0`.
- `EXNESS_SESSION`: winter timestamps shift by `-60` minutes on the documented
  DST calendar so research uses a stable session clock. Exness metal prefixes
  `XAU`, `XAG`, `XPT`, and `XPD` use UK DST; other symbols use US DST.
- Broker time remains causal for bars, identity, trigger order, sessions,
  durations, orders, and reconciliation.
- Analysis time is export-only for research calendar features and grouping.
  Never sort causal events by analysis time alone.

## Feature And Schema Contract

- Research context uses fixed built-in Bands parameters: period `21`, shift
  `0`, deviation `2.0`, SMA, and `PRICE_WEIGHTED`.
- Exactly two cached handles exist when export is enabled: one Macro and one
  Micro. They are created at initialization and released at deinitialization.
- Micro `%B 0..5` describes the trigger market. Shift `0` uses trigger Bid
  against developing bands; shifts `1..5` use matching completed weighted
  prices and bands.
- Macro pivot `%B 0..5` projects the immutable touched pivot price through
  Macro band envelopes. Values are not clipped.
- Micro bandwidth uses shift `0`; the Macro source bandwidth is cached from
  shift `1` when the Macro window is created. Raw and normalized widths are
  exported; normalized widths are model features.
- Feature availability never authorizes or denies execution. Missing feature
  data makes the research row incomplete.
- Schema V11 owns exactly eight TSV files under
  `Common\Files\PivotFractalV11\runs\<run_id>\`: manifest, windows, origins,
  virtual trials, virtual outcomes, execution checks, broker outcomes, and
  summary.
- Virtual outcomes contain first-touch status, nominal R, and counterfactual
  `OrderCalcProfit` gross only. Broker outcomes alone own actual fills,
  slippage, gross profit, commission, swap, fee, net profit, and realized R.
- An accepted real request creates one parity shadow from the exact submitted
  entry, SL, TP, and normalized volume. It is outside the matrix/retry/ML
  cohorts and exists only to measure virtual-versus-broker agreement. The
  trigger must belong to its Macro origin, but synchronous send completion may
  cross the exact origin boundary; parity keeps the accepted send time and
  exports `origin_window_active_at_entry=0` for that explicit case. Parity
  threshold candidates resolve only in an actual trade session. If broker
  history closes first, the unresolved shadow is explicitly censored as
  `BROKER_TERMINAL_BEFORE_OBSERVED_TOUCH` before broker-outcome linking.
- The primary virtual binary cohort contains feature-complete eligible
  `TP_FIRST`/`SL_FIRST` matrix rows. The broker TP/SL cohort and parity
  calibration remain separate; ineligible and censored rows are never losses.
- Current Python tooling accepts strict V11 only, builds long/wide/chain/
  calibration DuckDB and Parquet artifacts, audits origin and row support, and
  trains offline XGBoost trial candidates with per-origin sample weights. It
  has no runtime export, filter mode, online learning, or pattern playback.

## Include Pipeline

The entrypoint owns one ordered aggregator chain:

```text
services/trading_tools.mqh
services/trading_management.mqh
services/trading_signals.mqh
services/frontend.mqh
```

- Aggregators own include order; do not add sibling re-includes or cycles.
- Keep source limited to one cached Macro pivot window, two Bands handles,
  virtual trigger/context collection, bounded V11 trial state, broker
  execution/reconciliation, V11 telemetry, and bounded inspection.
- The frontend draws at most 16 active positions with broker entry, immutable
  SL, immutable TP, and pivot identity. It cannot influence execution;
  nonvisual tester runs do no chart work.

## Validation And Commit Policy

- Do not add MQL5 test harnesses, custom test modules, test EAs/scripts,
  agentic MQL5 CI, or new test infrastructure.
- Every implementation sprint requires static logic review: exact
  identifier/reference sweeps, include tracing, safety-boundary inspection,
  and `git diff --check`. Existing Python contract tests may be maintained when
  schema tooling changes.
- Substantial multi-sprint MQL5 plans use one final real MetaEditor compile;
  intermediate sprints do not compile unless a human changes the plan.
- Final compilation must report `0 errors, 0 warnings`; `/s` is syntax-only and
  does not prove `.ex5` regeneration.
- Final integration requires human Strategy Tester/chart verification. Python
  fixtures and compilation cannot replace broker-window, order-lifecycle, DST,
  export, performance, and visual acceptance.
- Complete and validate one sprint, create exactly one sprint-specific commit,
  record its rollback point, then advance.
- Preserve archived plans/research, old datasets, and generated artifacts.

## Style And Performance

- 2-space indentation; `snake_case` variables; `CamelCase` functions;
  `ALL_CAPS` enums and constants.
- Avoid `auto`, lambdas, range-for, per-tick handle creation, full-history
  scans, unbounded logging, and repeated market-data calls without a reason.
- Check indicator, market-data, file, array, and trade operations. Release
  handles, files, and chart objects during deinitialization.

## Rollout Restriction

This implementation does not authorize live rollout. Before any future
deployment, every older-engine position for the symbol must be flat, the
account must support hedging, and only one EA instance may run per account and
symbol.
