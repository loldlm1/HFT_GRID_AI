# HFT Grid AI - Agent Brief

This repository is an always-on pivot-fractal market-data collector with one
small broker execution path. Keep active code and documentation focused on that
contract; historical plans and evidence remain under their archive directories.

## Entrypoint And Active Work

- Entrypoint: `HFT_Grid_AI.mq5`.
- Active plan: none. The completed pivot-fractal/schema V9 plan is archived
  under `docs/plans/archive/pivot-fractal-engine-schema-v9-2026-07-29/`.
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
- `planner` when a human explicitly requests a saved, sprint-based plan.

Do not list or invoke unavailable skills as project requirements.

## Public Input Contract

The active EA exposes only these groups:

| Group | Inputs |
| --- | --- |
| `+= Market Data Time =+` | `Broker_Session` |
| `+= Broker Execution =+` | `Lot_Type`, `Lot_Strategy_Size` |
| `+= Signal Statistics Export =+` | `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id` |
| `+= Developer Debug Settings =+` | `Enable_Logs`, `Enable_File_Logs` |

Do not restore licensing, account settings, configurable protection,
user-defined sessions, spread thresholds, direction/concurrency selectors,
multi-leg risk, partial TP, daily limits, lot sequences, runtime model/pattern
controls, or compatibility aliases for removed inputs.

## Runtime Contract

```text
broker tick and previous completed M1 Bid close
-> refresh only causal changed or retry-due M15/M30/H1/H4/D1 pivot windows
-> discover unconsumed Bid first touches
-> capture one six-timeframe context snapshot per observed tick candidate batch
-> copy the frozen snapshot to every same-tick candidate
-> build immutable structural route
-> observation and fresh pre-send broker checks
-> one market order with broker structural SL and terminal pivot TP
-> ticket-first broker reconciliation
-> monotonic captured-level trailing
-> broker-confirmed outcome and optional schema V9 persistence
```

- `PIVOT_FRACTAL_V1` is the only signal source. It calculates classic `PP`,
  `S1..S3`, and `R1..R3` from shift `1` of fixed `M15`, `M30`, `H1`, `H4`,
  and `D1` broker series. `M1` creates no pivot levels.
- Each valid set lives for its actual broker-native active bar. No wall-clock
  aggregation, incomplete candle, or synthetic missing bar is permitted.
- Series visibility is subordinate to the observed tick: a current bar whose
  open is later than the tick cannot activate a window or replace M1 context.
- Previous completed M1 Bid close above a level plus live Bid at/below it is a
  buy touch. Previous close below plus live Bid at/above it is a sell touch.
  Equality is neutral. Buy orders execute at Ask; sell orders execute at Bid.
- Identity is `(symbol, pivot timeframe, active bar open, level)`. First touch
  consumes it even when the route or broker send is denied or fails. Direction
  is the first-touch outcome and is not part of identity.
- Filled positions retain their captured seven-level ladder and route after the
  source window expires. Local state trails and reconciles by broker ticket.
- Real execution requires `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`. Other account
  modes continue collecting facts and fail sends closed.
- The internal magic is stable, nonzero, and derived from the pivot namespace
  plus symbol. There is no public magic input.

## Broker Safety Kernel

Every attempt captures broker facts when observed. Checks run again immediately
before a send; only the fresh result may authorize `OrderSend`.

Required facts and guards include:

- actual broker session and symbol trade mode;
- hedging margin mode and account/terminal/MQL trading permissions;
- current Bid, Ask, point size, and observed spread;
- structural entry/SL/TP geometry, stops level, and freeze level;
- volume min/max/step, requested/normalized volume, free margin, and
  `OrderCheck`;
- send retcode/comment and symbol/magic/ticket reconciliation.

Spread is telemetry, not a configurable denial threshold. Pivot prices are
never moved to force broker geometry to pass. Broker facts own ticket, volume,
entry, SL/TP, close state, and realized profit after a fill.

## Trailing Contract

- Broker-side initial SL and terminal TP are mandatory for every allowed route.
- Trailing uses the immutable pivot route captured at entry. It tightens to the
  strongest reached eligible level, submits at most one modification per tick,
  and never widens or removes protection.
- Buy milestone reach uses live Bid; sell milestone reach uses live Ask.
- A stop at the logical entry pivot is structural break-even only. Spread,
  slippage, commission, and swap can still make the monetary result negative.
- Buy `R3` and sell `S3` touches are recorded and denied as
  `NO_FORWARD_LEVEL`; no `R4/S4` is calculated.

## Deterministic Time

- `FIXED_TIME_SESSIONS`: analysis time equals broker time and offset is `0`.
- `EXNESS_SESSION`: winter timestamps shift by `-60` minutes on the documented
  DST calendar so research uses a stable session clock. Exness metal prefixes
  `XAU`, `XAG`, `XPT`, and `XPD` use UK DST; other symbols use US DST.
- Broker time remains causal for bars, identity, touch order, sessions,
  durations, orders, trailing, and reconciliation.
- Analysis time is export-only for research calendar features and grouping.
  Every time-bearing row retains broker time, analysis time, and offset; never
  sort causal events by analysis time alone.

## Feature And Schema Contract

- A first touch captures exactly one context row for `M1`, `M15`, `M30`, `H1`,
  `H4`, and `D1` when export is enabled.
- Each row retains Stoch Structure classifications for slots `0..2` and raw
  Bollinger `%B` shifts `0..5`. Shift `0` uses trigger Bid against developing
  bands; shifts `1..5` use matching completed closes and bands.
- Feature availability never authorizes or denies execution. Missing feature
  data makes the exported run incomplete/invalid.
- Schema V9 owns exactly nine TSV files under
  `Common\Files\PivotFractalV9\runs\<run_id>\`: manifest, windows, levels,
  attempts, features, execution checks, trailing events, broker outcomes, and
  run summary.
- Current Python tooling validates only strict V9, builds leakage-safe
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
- Keep source limited to cached pivot windows, M1 touch/context collection,
  broker execution/reconciliation, V9 telemetry, and bounded inspection.
- `indicators/Stochastic_Structure.mq5` remains the standalone source required
  for context slots. `%B` uses cached built-in `iBands` handles.
- The frontend draws at most 16 active signals with entry/current SL/terminal
  TP lines. It cannot influence execution; nonvisual tester runs do no chart
  work.

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
  trailing, export, performance, and visual acceptance.
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
