# HFT Grid AI - Agent Brief

This repository is an always-on M1 market-data collector with one small broker
execution path. Keep active code and documentation focused on that contract;
historical plans and evidence remain under their archive directories.

## Entrypoint And Active Work

- Entrypoint: `HFT_Grid_AI.mq5`.
- Active plan: none. Start a new explicitly invoked `$planner` plan under
  `docs/plans/` for the next substantial change.
- Architecture: `docs/architecture/market-data-broker-executor.md`.
- Environment runbook: `docs/environment/mt5-agentic-workflows.md`.
- Statistics workflow: `docs/workflows/extremum-engine-statistics-flow.md`.
- ML boundaries: `docs/workflows/deterministic-signal-ml-inference-flows.md`.

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
| `+= ML Shadow Inference =+` | `ML_Inference_Mode`, `ML_Model_Export_Id` |
| `+= Pattern Audit Playback =+` | `Enable_Pattern_Audit_Overlay`, `Pattern_Audit_Set_Id` |
| `+= Developer Debug Settings =+` | `Enable_Logs`, `Enable_File_Logs` |

Do not restore licensing, account settings, configurable protection,
user-defined sessions, spread thresholds, direction/concurrency selectors,
multi-leg risk, partial TP, daily limits, lot sequences, or compatibility
aliases for removed inputs.

## Runtime Contract

```text
fixed M1 Stoch Structure observation
-> intrinsic extremum attempt
-> observation-time broker snapshot
-> optional schema v8 persistence
-> raw broker-time breakout trigger
-> fresh broker checks
-> optional tester-only pattern/ML denial
-> one broker order with broker SL and fixed 1R TP
-> ticket-first broker reconciliation
-> broker-confirmed outcome persistence
```

- `EXTREMUM_V1` is the only source. Slot `0` is provisional; `BOTTOM` maps to
  bullish and `PEAK` maps to bearish.
- Distinct revisions may coexist, but one intrinsic attempt owns at most one
  broker position.
- Real execution requires `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`. Other account
  modes continue collecting facts and fail sends closed.
- The internal magic is stable, nonzero, and derived from the EA namespace and
  symbol. There is no public magic input.
- After a fill, broker facts own ticket, volume, entry, SL/TP, close state, and
  realized profit. Local state may reconcile but may not overwrite them.

## Broker Safety Kernel

Every attempt captures broker facts when observed. Before a send, checks run
again; only the fresh pre-send result may authorize `OrderSend`.

Required facts and guards include:

- actual broker session and symbol trade mode;
- hedging margin mode and account/terminal/MQL trading permissions;
- current bid, ask, and observed spread;
- stops level, freeze level, price geometry, and required broker-side SL/TP;
- volume min/max/step, requested/normalized volume, free margin, and
  `OrderCheck`;
- send retcode/comment and symbol/magic/ticket reconciliation.

Spread is telemetry, not a configurable denial threshold. Normalized analysis
time never changes these checks or live order timing.

## Deterministic Time

- `FIXED_TIME_SESSIONS`: analysis time equals broker time and offset is `0`.
- `EXNESS_SESSION`: winter timestamps are shifted by `-60` minutes on the
  documented DST calendar so research uses a stable session clock. For US30,
  a winter broker open at `14:30` becomes analysis time `13:30`; a summer
  broker open at `13:30` remains `13:30`.
- Exness metal prefixes `XAU`, `XAG`, `XPT`, and `XPD` use the UK DST calendar;
  other symbols use the US calendar.
- Broker time remains causal for bars, sessions, durations, order timing, and
  reconciliation. Analysis time is only for export, features, calendar
  grouping, and pattern matching.
- Rows retain broker time, analysis time, and the applied offset. Never sort
  causal events by analysis time alone.

## Include Pipeline

The entrypoint owns one ordered aggregator chain:

```text
services/trading_tools.mqh
services/trading_management.mqh
services/trading_signals.mqh
services/frontend.mqh
```

- Aggregators own include order; do not add sibling re-includes or cycles.
- Keep source limited to direct M1 observation, broker execution/reconciliation,
  schema v8 telemetry, ML/pattern research, and bounded visual inspection.
- The frontend may draw only bounded entry/SL/TP lines. It must not enable,
  disable, resize, or otherwise influence execution.
- Nonvisual Strategy Tester runs perform no chart-object work.

## Schema V8 And Research Boundaries

- Schema v8 is the only active export contract. Current tooling does not adapt
  schemas v4-v7.
- Simulated attempt results remain in `engine_attempts`; broker-confirmed
  outcomes remain in `signal_outcomes`.
- `ML_INFERENCE_SHADOW` may score and record only.
- `ML_INFERENCE_FILTER` is Strategy Tester-only and may only deny an otherwise
  broker-eligible send.
- Pattern playback is Strategy Tester-only and file-driven. It may only deny
  according to the selected audit set after broker checks pass.
- No schema v8 model is currently approved for MT5 runtime. Research artifacts
  fail closed unless a later plan supplies explicit approval and parity
  evidence.

## Validation And Commit Policy

- Do not add MQL5 test harnesses, custom test modules, test EAs/scripts,
  agentic MQL5 CI, or new test infrastructure.
- Every implementation sprint still requires static logic review: exact
  identifier/reference sweeps, include tracing, safety-boundary inspection,
  and `git diff --check`. Existing Python contract tests may be maintained in
  place when the schema tooling changes.
- For substantial multi-sprint MQL5 plans, intermediate sprints do not run
  MetaEditor syntax checks or compiles. Schedule one final real compile sprint
  unless a human explicitly changes this policy.
- The final compile must report `0 errors, 0 warnings`; `/s` is syntax-only and
  does not prove `.ex5` regeneration.
- Final integration requires human Strategy Tester/chart verification. A
  compile or Python fixture cannot replace broker-session, order lifecycle,
  DST, and visual acceptance.
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

The completed simplification does not authorize live rollout. Before any future
deployment, old-version positions for the symbol must be flat, the account must
support hedging, and only one EA instance may run per account and symbol.
