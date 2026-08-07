# HFT Grid AI - Agent Brief

This repository is an always-on Macro/Micro pivot-band market-data collector
with one small broker execution path. Keep active code and documentation
focused on that contract; historical plans and evidence remain under their
archive directories.

## Entrypoint And Active Work

- Entrypoint: `HFT_Grid_AI.mq5`.
- Active plan: none. The completed V2/V10 plan is archived under
  `docs/plans/archive/macro-micro-pivot-bandwidth-schema-v10-2026-08-06/`.
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
-> refresh one causal Macro pivot window when its broker bar changes or retry is due
-> calculate PP/S1..S3/R1..R3 from the previous completed Macro candle
-> arm PP from the first causal live Bid side
-> discover unconsumed live-Bid virtual-limit triggers
-> capture one shared Micro/Macro weighted-Bands snapshot per tick batch
-> derive candidate-specific Macro pivot %B
-> build immutable structural SL and fresh quote 1R TP
-> perform observation and fresh pre-send broker checks
-> submit one FOK market order with broker SL/TP
-> reconcile by broker ticket without modifying protection
-> export broker-confirmed outcome and optional strict schema V10 facts
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
- Schema V10 owns exactly six TSV files under
  `Common\Files\PivotFractalV10\runs\<run_id>\`: manifest, windows, attempts,
  execution checks, outcomes, and summary.
- Outcomes decompose entry/exit slippage, gross profit, commission, swap, fee,
  net profit, budget-relative R, and executable-risk-relative R.
- Only feature-complete, fully closed positions with one consistent
  broker-confirmed TP or SL reason enter the binary cohort. Other outcomes and
  censored attempts remain auditable and are never relabeled as losses.
- Current Python tooling validates strict V10, builds leakage-safe
  DuckDB/Parquet datasets, audits pivot behavior, and trains offline XGBoost
  candidates. It has no runtime export, shadow/filter mode, or pattern playback.

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
  virtual trigger/context collection, broker execution/reconciliation, V10
  telemetry, and bounded inspection.
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
