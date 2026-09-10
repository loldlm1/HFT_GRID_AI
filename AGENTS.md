# HFT Grid AI - Project Instructions

## Start Here

Entrypoint: `HFT_Grid_AI.mq5`, version `1.30`, schema `13`, source
`PIVOT_FRACTAL_V2`: H1/M10/Micro collector, structural H1 1R broker lane,
separate offline research tools.

- [Status, plan and evidence](docs/README.md).
- [Runtime contract](docs/architecture/market-data-broker-executor.md): read before MQL5 changes.
- [Environment/validation](docs/environment/mt5-agentic-workflows.md): paths, MCP and checks.
- [V13 research](tools/deterministic_signal_ml/README.md).
- [Exness preparation/import/comparison](tools/exness_tick_history/README.md).

## Skills And Execution

- Use `$production-engineering-stack:mql5-production-engineering` for MQL5/MT5.
- Use `$production-engineering-stack:python-django-production-engineering` for
  Python tools; there is no Django app here.
- Use `$codex-agentic-stack:token-saver-orchestrator` for RTK-first checks;
  retain exact failure diagnostics when needed.
- Use `planner` for saved/phased/sprint plans, `create-plan` for chat plans.
  Skills do not change native `/plan` mode.
- Use `openai-docs` with official search/fetch for Codex configuration. Resolve
  installed helpers dynamically; never copy skills/hooks here or edit plugin caches.
- Planning/review is not execution permission. Preserve accepted scope/decisions
  across interruptions; record required question blockers in Planner state.
- One agent/writer per worktree; delegation requires authorization. Preserve
  unexpected edits, stop to reconcile ownership, and stage only reviewed paths.
- Validate/commit each sprint before advancing: one commit and recorded rollback
  parent. Do not amend or rewrite history.

## Critical Runtime Boundaries

- Defaults: `Macro_Timeframe=PERIOD_H1`, `Deep_Timeframe=PERIOD_M10`,
  `Micro_Timeframe=PERIOD_M3`. Validate explicit supported periods with normalized
  seconds and strict `Micro < Deep < Macro` ordering.
- Public groups contain only time (`Broker_Session` and these three periods),
  execution (`Lot_Type`, `Lot_Strategy_Size`), export
  (`Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`), and debug
  (`Enable_Logs`, `Enable_File_Logs`). Reference-balance lot mode defaults to
  `0.01` percent of fixed `1,000,000`, never live balance.
- Never restore removed inputs/features: licensing, account/protection controls,
  trading hours, spread/direction/concurrency selectors, multi-leg risk, partial TP,
  daily limits, lot sequences, Bands/re-entry/model policies or compatibility aliases.
- Broker time owns causality, sessions and lifecycles. Pivots use previous completed
  broker candles (shift 1), never future/current sources, wall-clock aggregates or
  synthetic bars. Analysis time/Exness DST are export-only, not causal sort keys.
- H1/deep identities are direction-independent first-consumption keys. Bid triggers
  support buys/resistance sells; PP arms on strict departure, triggers on return.
  Buys execute at Ask; sells at Bid.
- Process H1 terminal transitions before same-tick deep discovery. Export,
  features, virtual/deep state and offline models can never authorize, deny,
  delay, resize, duplicate, close or modify the real broker order.
- Only structural H1 1R may `OrderSend`: one FOK request per consumed origin.
  Freshly recheck session, symbol/hedging mode, permissions,
  quotes, geometry, stops/freeze, volume, margin/profit calculations and `OrderCheck`.
  Use `HFT_GRID_AI_PIVOT_FRACTAL_V13` ownership; never adopt older-engine positions.
- Broker SL/TP stay immutable; TP is one fresh-quote price-distance R from the
  structural stop. No trailing, break-even, partial close, resize or
  `TRADE_ACTION_SLTP`. One accepted request owns one exact calibration parity shadow.
- Eight H1 lanes: STRUCTURAL/MIDPOINT_50 times 1R/2R/3R/5R. Midpoints enter at
  executable halfway touch, armed while any structural lane survives bar rollover;
  untouched rows become NOT_TRIGGERED when the last structural lane exits.
- Freeze entered eligible same-direction virtual/confirmed broker parents before
  deep discovery; never add parents retroactively. One deep event owns one Micro
  vector, three shared 1R/2R/3R trials and link-scoped outcomes. No deep 5R or send.
- Retain actual confirmed broker close time on existing deep links before cleanup.
  Unresolved children censor at parent close, including at run end; later observed
  quotes/reconciliation do not extend the parent. Other active links may continue.
- Invalid geometry/money, capacity rejection, NOT_TRIGGERED and parent/run censors
  stay explicit; never relabel them as losses. Reserve deep fan-out atomically,
  or emit one CAPACITY_REJECTED event with no children. H1/parity cap: 2048;
  deep caps: 2048 events, 4096 links, 6144 trials, 18432 outcomes.
- Exact uncapped `h1_structural_lifecycle_seconds` requires a completed entered
  lifecycle; same-second broker entry/close may yield zero. Ineligible,
  not-triggered/run-censored durations are null. `m10_parent_age_seconds` is exact
  trigger-time age. Selectors use `<= minutes * 60`; completed H1 duration is
  retrospective, never a causal model feature.
- Export owns four cached handles: Macro/Micro Bands and Stochastic. Fixed Bands
  are 21/0/2.0, SMA, PRICE_WEIGHTED; Stochastic 5/3/3, MODE_SMA, STO_CLOSECLOSE.
  Initialize/release safely, including partial initialization; no per-tick creation.
- Twelve TSVs: `Common\Files\PivotFractalV13\runs\<run_id>\`. H1 features live
  once on origins, deep features once on events. Preserve typed headers/native
  grains; missing features affect research only. Python accepts only V13, training
  offline H1/deep candidates, no runtime artifact/filter. Keep V12 rejection tests.
- The bounded parent chronology audit is separate from full semantic acceptance.
  Recovery uses a distinct run plus retained correction/provenance sidecars,
  preserving original data and binary labels; it is not a new tester run.

## Source And Validation

Include order: `services/trading_tools.mqh`, `services/trading_management.mqh`,
`services/trading_signals.mqh`, `services/frontend.mqh`. Aggregators own order;
no sibling re-includes/cycles or unbounded history scans/logging. Frontend is
read-only: at most 16 owned positions and no nonvisual tester chart work.

Use 2 spaces, `snake_case` variables, `CamelCase` functions, `ALL_CAPS` constants.
Avoid `auto`, lambdas, range-for, unchecked calls and needless repeated queries.
Deletion requires non-use/equivalence proof, including callbacks/fixture discovery.

Every sprint: exact reference sweeps, include tracing, broker/research review and
`git diff --check`. Run existing Python tests for affected tooling/fixtures.
No new MQL5 harnesses, test EAs/scripts, CI or test infrastructure. Reuse unchanged
passing evidence; report unrun gates accurately.

Recompile for source/include/compiler changes or an explicit gate. Discover MCP
schemas: `get_workspace_info` before other MetaEditor operations, then `compile_file`.
Require `0 errors, 0 warnings` and regenerated `.ex5` metadata. Fallback only when
MCP cannot execute; record why. New behavior needs human tester/chart acceptance.

## Documentation And Artifacts

Update the seven guide/index owners in place; new docs need a distinct purpose.
Keep AGENTS within 160 lines / 8 KiB and current status only in `docs/README.md`.
Keep one current/latest plan. Retire superseded tracked docs after migrating
unique current facts and retaining Git commit/path recovery. Keep evidence needed
for current behavior, open gates or downstream contracts; preserve dated facts
and hashes, changing only navigation or explicit annotations. Never restart old plans.

Validate links/anchors, versions, requirement ownership and ignores. Keep private
data/logs/binaries/backups untracked. Use ignored `.codex-hook-state/` and
`.codex-artifacts/`; preserve operator handoffs, original/recovered data, shared
terminal folders and global Codex/plugin state.

No live rollout. Chart, broker-equivalence and recovered-run gates remain in the
index. Deployment requires older positions flat, hedging and one instance per
account/symbol. Tool approval is not trading authority.
