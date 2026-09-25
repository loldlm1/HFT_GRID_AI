# HFT Grid AI - Project Instructions

Current [execution plan](mql5-model-runtime-optimization-plan.md).
Retain trading rules; Candle visual review is deferred.

## Start Here

Pivot/Candle EAs: `2.00`, common schema `1`, Macro/Micro shared capture.
Engines: `PIVOT_MACRO_V1` and `CANDLE_PATTERN_ATR_V2`.

- [Status, plan and evidence](docs/README.md).
- [Runtime contract](docs/architecture/market-data-broker-executor.md): read before MQL5 changes.
- [Validation](docs/environment/mt5-agentic-workflows.md): paths, MCP and checks.
- [Producer handoff](docs/research/model-feature-producer-handoff.md).
- [Exness preparation/import/comparison](tools/exness_tick_history/README.md).

## Skills And Execution

- `planner`: proposals/saved/sprint plans; native behavior for short chat plans.
- `$codex-agentic-stack:on-demand-skills`: bounded search; one pinned MQL5/Python
  bundle under local contracts.
- `$codex-agentic-stack:understand-anything`: scoped graphs for unfamiliar work;
  reuse fresh graphs, verify source and report gaps.
- `$codex-agentic-stack:token-saver-orchestrator`: RTK-first, exact failure evidence.
- `openai-docs`: Codex. No copied skills/hooks or plugin-cache edits.
- Planning/review grants no execution. Preserve scope, answers and pending
  questions in Planner state.
- One agent/writer per worktree; delegate only if authorized. Stop on unexpected
  edits; preserve others' work and stage reviewed paths. Validate/commit each sprint
  before advancing; record rollback parents. Never amend/rewrite history.

## Response Style

- Number main reply points; use bullet details.

## Critical Runtime Boundaries

- Defaults: Macro H1 / Micro M3; validate supported periods with `Micro < Macro`.
  Fixed M1 structure is a separate source. No Deep input or active research path.
- Public groups contain only time (`Broker_Session` and these two periods),
  execution (`Lot_Type`, `Lot_Strategy_Size`), export
  (`Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`), and debug
  (`Enable_Logs`, `Enable_File_Logs`). Reference-balance lot mode defaults to
  `0.01` percent of fixed `1,000,000`, never live balance.
- Never restore removed Pivot controls: licensing, account/protection controls,
  trading hours, spread/direction/concurrency selectors, multi-leg risk, partial TP,
  daily limits, lot sequences, Bands/re-entry/model policies or compatibility aliases.
- Broker time owns causality, sessions and lifecycles. Pivots use previous completed
  broker candles (shift 1), never future/current sources, wall-clock aggregates or
  synthetic bars. Analysis time/Exness DST are export-only, not causal sort keys.
- Macro identities are direction-independent first-consumption keys. Bid triggers
  support buys/resistance sells; PP arms on strict departure, triggers on return.
  Buys execute at Ask; sells at Bid.
- Process broker terminal transitions before discovery. Export,
  features, virtual state and offline models can never authorize, deny,
  delay, resize, duplicate, close or modify the real broker order.
- Pivot: only structural Macro 1R may `OrderSend`, one FOK per consumed origin.
  Freshly recheck session, symbol/hedging mode, permissions,
  quotes, geometry, stops/freeze, volume, margin/profit calculations and `OrderCheck`.
  Use `HFT_GRID_AI_PIVOT_MACRO_V1` ownership; never adopt older-engine positions.
- Immutable broker SL/TP; TP is one fresh-quote price-distance R from the
  structural stop. No trailing, break-even, partial close, resize or
  `TRADE_ACTION_SLTP`. Each accepted request owns one exact parity regardless of research eligibility.
- Eight Pivot lanes: STRUCTURAL/MIDPOINT_50 times 1R/2R/3R/5R. Bid owns midpoint
  touch; buys enter at Ask and sells at Bid. Keep midpoints armed across rollover
  while any structural lane survives; untouched lanes then become NOT_TRIGGERED.
  Preserve exact accepted-request parity.
  Invalid geometry/money, capacity refusal and run censors never become losses.
  H1/parity active-state cap remains 2048. Deep removal never changes broker policy.
- Candle retains independent ATR13 shift-1 stops, both broker directions, one
  confirmed-SL re-entry and per-entry Macro-duration expiry; shared capture is read-only.
- Tick/deal clocks retain actual milliseconds; native scheduling stays causal.
  Completed durations are exact; no-touch/ineligible/censored durations are null.
  Broker close time differs from later observation; retrospective facts are not
  causal features. Parity is always excluded from target cohorts.
- Shared capture: Macro/Micro native Stochastic 5/3/3 SMA CLOSE/CLOSE K/D,
  weighted-price Bands 21/0/2 percent B/SMA5, ATR13/SMA5, shifts 0..5. No bandwidth.
  Each percent B shift uses its own candle price. Freeze shift 0 at observation.
- M1 structure keeps confirmed and live forming states separately. Warmup <=4096
  prior closed bars; catch-up <=256 per callback. Project live state from a copy.
  Macro adjacent zones use signal Bid and latest/outermost tested support/resistance.
- Six shared research handles plus M1 Stochastic; reuse Micro M1's handle. Candle
  owns a separate execution ATR. No per-tick creation; release partially initialized
  resources safely. Missing features never veto broker execution.
- New exports: `Common/Files/MQL5ModelDatasetV1/runs/<run_id>/`, ten Pivot or
  eleven Candle TSVs, strict shared reader. Legacy readers/fixtures stay historical.
  Dataset contract: [shared schema](docs/architecture/model-feature-dataset.md).
- Failed research latches first diagnostics, stops only its tester and seals
  FAILED/CENSORED when writable. Release research state, preserve broker ownership.
  Shared capture receives configuration; it cannot import engine inputs/state.
- Historical recovery retains originals, labels and correction/provenance sidecars.
  Chronology is separate from semantic acceptance; recovery is not a tester run.

## Source And Validation

Include order: `services/trading_tools.mqh`, `services/trading_management.mqh`,
`services/trading_signals.mqh`, `services/frontend.mqh`. Aggregators own order;
no sibling re-includes/cycles or unbounded history scans/logging. Frontend is
read-only: at most 16 owned positions and no nonvisual tester chart work.

Use 2 spaces, `snake_case` variables, `CamelCase` functions, `ALL_CAPS` constants.
Avoid `auto`, lambdas, range-for, unchecked calls and needless repeated queries.
Deletion requires non-use/equivalence proof, including callbacks/fixture discovery.

Every sprint: exact reference sweeps, include tracing, broker/research review,
`git diff --check` and affected existing Python checks. No new MQL5 harnesses,
test EAs/scripts, CI or test infrastructure. Reuse unchanged evidence; report unrun gates.

New engines/features: [performance contract](docs/architecture/market-data-broker-executor.md#performance-contract).
Bound work/state, declare invalidation, reuse providers and prove exact behavior
and measured release gains. Shared changes validate both engines.

Recompile for source/include/compiler changes or an explicit gate. Discover MCP:
`get_workspace_info` before MetaEditor operations, then `compile_file`.
Require `0 errors, 0 warnings` and regenerated `.ex5` metadata. Fallback only when
MCP cannot execute; record why. New behavior needs human tester/chart acceptance.

## Documentation And Artifacts

Edit doc owners in place; new docs need distinct purposes.
AGENTS: max 160 lines / 8 KiB. Current status: `docs/README.md` only.
Keep one current plan. Archive superseded plans with Git commit/path recovery;
retain unique facts, current evidence, open gates and downstream contracts.
Preserve dated facts/hashes; edit only navigation or annotations. Never restart old plans.

Validate links/anchors, versions, owners and ignores. Keep private artifacts
untracked. Use ignored `.codex-hook-state/` and
`.codex-artifacts/`; preserve operator handoffs, original/recovered data, shared
terminal folders and global Codex/plugin state.

No live rollout. The index retains chart, broker/feed and recovery gates.
Deployment requires older positions flat, hedging and one instance per
account/symbol. Tool approval is not trading authority.
