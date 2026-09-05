# HFT Grid AI - Agent Brief

This repository is an always-on H1/M10/Micro pivot market-data collector with
one small structural broker execution path. Keep active code and documentation
focused on that contract. Historical plans, handoffs, datasets, and acceptance
evidence remain immutable under their existing archive or research locations.

## Entrypoint And Active Work

- Entrypoint: `HFT_Grid_AI.mq5`.
- Active implementation plan: none.
- Completed V13 plan:
  `docs/plans/archive/pivot-fractal-v13-deep-pivot-producer-2026-08-31/`.
- Architecture: `docs/architecture/market-data-broker-executor.md`.
- Environment: `docs/environment/mt5-agentic-workflows.md`.
- Statistics: `docs/workflows/pivot-fractal-statistics-flow.md`.
- Research boundary:
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`.
- V13 handoff: `docs/research/pivot-fractal-v13-producer-handoff.md`.
- V13 acceptance:
  `docs/research/pivot-fractal-v13-producer-acceptance-2026-08-31.md`.
- Outstanding operational gate: human chart-object/rendering verification before
  any deployment-oriented claim.

The V12 plan and acceptance records are historical only. Active code and
tooling must not emit, accept, convert, or dual-write V12.

## Skill Stack

Use only installed capabilities that match the task:

- `$production-engineering-stack:mql5-production-engineering` for `.mq5`/`.mqh`,
  broker execution, handles, MetaEditor, and Strategy Tester work.
- `$codex-agentic-stack:token-saver-orchestrator` for RTK-first inspection and
  compact validation evidence.
- `$production-engineering-stack:python-django-production-engineering` for the
  Python validator, DuckDB/Parquet builder, audit, offline trainer, and only
  explicitly authorized downstream Django work.
- `$production-engineering-stack:postgres-production-engineering` and
  `$production-engineering-stack:devops-release-production-engineering` only when
  an authorized downstream task reaches those boundaries.
- Use `$planner` only when explicitly invoked for a saved sprint plan;
  `create-plan` provides concise chat planning. Resume authorized execution from
  its existing checkpoint. Archived plans do not start a new execution.
- Use `$openai-docs` for current Codex/model configuration, with an official
  search and page fetch. Offline Python training does not create an OpenAI agent
  runtime or trigger the AI-agent application skill.

The installed plugins own their skills and lifecycle hooks. Do not duplicate
them in this repository or edit their native caches. Resolve tools and helper
paths from the installed capability instead of pinning user-specific skill paths.
Source inspection remains useful when optional MetaTrader MCP servers are offline;
report compilation/tester checks as unrun when their runner is unavailable.

For any future compile, call the MetaEditor MCP `get_workspace_info` before any
other compiler operation, then use `compile_file` for the EA. Discover the current
tool names and schemas at runtime. Automatic tool approval does not authorize
trading or account changes. Keep credentials and private account or terminal data
out of logs and commits.

## Session And Artifact Ownership

Use one writing session per worktree and separate worktrees for concurrent
writers. Coordinate shared global Codex config/plugin changes with their owner.
Preserve unexpected edits, inspect the current branch, and stage only reviewed
paths. Keep checkpoints in ignored `.codex-hook-state/` and disposable output in
ignored `.codex-artifacts/` or the existing ignored `logs/` and `artifacts/` paths.
Accepted plans and concise evidence remain source-controlled; private datasets,
terminal logs, credentials, and `.ex5` output remain local. See
`docs/environment/mt5-agentic-workflows.md` for the documentation validation gate.

## Public Input Contract

| Group | Inputs |
| --- | --- |
| `+= Market Data Time =+` | `Broker_Session`, `Macro_Timeframe`, `Deep_Timeframe`, `Micro_Timeframe` |
| `+= Broker Execution =+` | `Lot_Type`, `Lot_Strategy_Size` |
| `+= Signal Statistics Export =+` | `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id` |
| `+= Developer Debug Settings =+` | `Enable_Logs`, `Enable_File_Logs` |

Defaults are `Macro_Timeframe=PERIOD_H1`, `Deep_Timeframe=PERIOD_M10`,
`Micro_Timeframe=PERIOD_M3`,
`Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`, and
`Lot_Strategy_Size=0.01`. Validate explicit supported periods using normalized
seconds, with strict `Micro < Deep < Macro` ordering.

Do not restore licensing, account settings, configurable protection,
user-defined sessions, spread thresholds, direction/concurrency selectors,
multi-leg risk, partial TP, daily limits, lot sequences, runtime model/pattern
controls, old Bands policies, retries, or compatibility aliases.

## Runtime Contract

```text
broker tick
-> reconcile the one real structural H1 1R broker lane
-> resolve H1 virtual first touches and midpoint pending state
-> resolve or censor existing parent-scoped deep outcomes
-> refresh causal Macro and Deep pivot windows when their broker bars change
-> calculate PP/S1..S3/R1..R3 from each previous completed candle
-> arm and consume untriggered H1 live-Bid identities
-> capture one shared H1-origin Micro/Macro indicator snapshot
-> build immutable structural route and fresh-quote 1R broker geometry
-> perform observation and fresh pre-send broker checks
-> submit at most one FOK structural 1R market order
-> declare eight structural/midpoint H1 virtual lanes when export is enabled
-> create one accepted-request broker-parity shadow after a successful send
-> freeze entered same-direction H1 virtual and confirmed broker parents
-> discover one shared causal M10 event per deep pivot identity
-> capture one configured-Micro feature vector for that event
-> declare shared deep 1R/2R/3R trials and link-scoped outcomes
-> export strict schema V13 facts at their native evidence grains
```

- `PIVOT_FRACTAL_V2` remains the only signal source.
- Macro and Deep ladders use classic pivots from broker shift `1`.
- No incomplete candle, future current bar, wall-clock aggregate, or synthetic
  missing bar may activate a window or snapshot.
- H1 and Deep identities are direction-independent first-consumption keys.
- H1 terminal transitions precede same-tick deep discovery.
- Export and all virtual/deep state can never authorize, deny, delay, resize,
  duplicate, close, or modify the real broker order.

## H1 Trigger And Route Contract

- `S1..S3` are buy-only and trigger when live Bid is at or below the level.
- `R1..R3` are sell-only and trigger when live Bid is at or above the level.
- PP observed above arms a support buy; PP observed below arms a resistance
  sell. Equality remains neutral until the first strict departure.
- H1 identity is `(symbol, Macro timeframe, active bar open, level)`.
- Downward same-tick order is buy-armed `PP`, `S1`, `S2`, `S3`; upward order is
  sell-armed `PP`, `R1`, `R2`, `R3`.
- Buys trigger on Bid and execute at fresh Ask. Sells trigger and execute at Bid.

Stops are `PP -> S1`, `S1 -> S2`, `S2 -> S3`, and extrapolated below `S3` for
buys; the sell mapping is symmetric through `R3`. The authoritative pre-send
TP is exactly one fresh-quote price-distance R from the structural stop.

## H1 Virtual Lane Contract

Each export-enabled consumed origin declares exactly eight H1 lanes:

```text
entry_policy = STRUCTURAL, MIDPOINT_50
tp_r_multiple = 1, 2, 3, 5
```

- There is no `sl_policy`, re-entry index, preceding-loss count, continuation,
  retry cap, Bands-width geometry, or reopening after SL.
- Structural lanes enter at the observed H1 trigger and use the next outward
  pivot stop.
- `MIDPOINT_50` is the exact halfway price from the touched pivot toward that
  stop. It is not entered at the origin trigger.
- The shared midpoint remains armed while any structural lane from the origin
  is active, including after H1 bar rollover; R5 has no special controller role.
- If the final structural lane exits before midpoint touch, all four midpoint
  rows become `NOT_TRIGGERED`, never losses.
- Once touched, all four midpoint ratios share one executable entry timestamp
  and then resolve independently.
- Virtual buys enter at Ask and resolve on Bid; sells enter at Bid and resolve
  on Ask. Stops normalize outward to the trade-tick grid and TP is rebuilt from
  normalized risk ticks for exact integer R.
- Invalid geometry, distance, or money plans remain explicit ineligible rows.

The H1/parity active-state cap is `2048`. Run termination censors unresolved
entered lanes; it does not relabel them as SL losses.

## Deep M10 Contract

- `Deep_Timeframe` defaults to `PERIOD_M10` and owns one causal pivot-window
  cache with the same classic formula and Bid trigger rules as H1.
- Capture occurs only when at least one entered eligible H1 virtual lane or
  confirmed broker fill is active in the same direction.
- One event identity is `(symbol, Deep timeframe, active Deep bar, level)`.
  Direction is an immutable trigger outcome and cannot create a second event.
- Freeze the active-parent set immediately before discovery. Later entries or
  fills are never linked retroactively.
- One event owns one configured-Micro snapshot and three shared trials at
  `1R`, `2R`, and `3R`. There is no deep `5R`, retry, or broker send.
- One parent link records the H1 lane/broker identity, entry time,
  `m10_parent_age_seconds`, and direction.
- One deep outcome exists per `(parent_link_id, deep_trial_id)`. Shared event
  features and geometry must not be copied into every link/ratio row.
- Deep entry uses the event executable quote, the next outward M10 pivot as the
  normalized stop, and exact integer-R targets. Invalid geometry is explicit;
  it is never reflected, stretched, or routed.
- If a parent exits first, unresolved outcomes for that link become
  `CENSORED_PARENT_EXIT`. Run stop uses `CENSORED_RUN_END`. Neither is a loss.
- The shared path may resolve for another still-active parent after one link is
  censored. Observation stops when no linked parent remains active.

Admission reserves one event, all frozen links, three trials, and three
outcomes per link atomically. If the complete fan-out cannot fit, emit one
`CAPACITY_REJECTED` event with zero partial children. Caps are `2048` events,
`4096` links, `6144` trials, and `18432` outcomes.

## Broker Safety Kernel

Only the H1 structural `1R` lane may reach `OrderSend`. V13 uses the distinct
`HFT_GRID_AI_PIVOT_FRACTAL_V13` magic namespace; older-engine positions must
never be adopted, closed, or modified.

Every attempt captures and freshly rechecks:

- broker session, symbol trade mode, hedging mode, and trading permissions;
- Bid, Ask, point, trade tick, spread, stops, freeze, and route geometry;
- volume min/max/step, requested and downward-normalized volume;
- FOK full-fill support, free margin, profit/margin calculations, and
  `OrderCheck`;
- request, send, ticket, fill, immutable protection, close, and deal-history
  facts.

The reference-balance lot mode uses fixed `1,000,000`, not live balance. Broker
SL/TP remain immutable. There is no trailing, break-even, partial close, resize,
or `TRADE_ACTION_SLTP` path. One accepted request creates one exact parity
shadow outside H1/deep model cohorts.

## Deterministic Time And Duration

- Broker time owns bars, identities, trigger order, sessions, durations,
  orders, and reconciliation.
- Analysis time is export-only and retains the documented fixed/Exness DST
  mapping. Never sort causal events by analysis time alone.
- H1 virtual outcomes and confirmed broker outcomes expose exact
  `h1_structural_lifecycle_seconds` only after a completed entered lifecycle.
- `NOT_TRIGGERED`, `INELIGIBLE`, and `CENSORED_RUN_END` have null completed H1
  duration.
- Parent links expose exact `m10_parent_age_seconds` at the M10 trigger.
- Neither duration is rounded or capped. Public minute selectors downstream use
  exact `<= minutes * 60` predicates.
- H1 completed duration is retrospective evidence and cannot support a causal
  deployment claim. M10 parent age is causal trigger-time context, but remains
  virtual research evidence.

## Feature And Schema Contract

- Exactly four cached handles exist when export is enabled: Macro/Micro Bands
  and Macro/Micro Stochastic. Create at initialization and release safely after
  partial initialization or normal deinitialization.
- Bands are fixed to period `21`, shift `0`, deviation `2.0`, SMA, and
  `PRICE_WEIGHTED`. Stochastic is fixed to `5/3/3`, `MODE_SMA`, and
  `STO_CLOSECLOSE`.
- H1-origin features live once on `signal_origins.tsv`; deep configured-Micro
  features live once on `deep_pivot_events.tsv`.
- `%B` uses the immutable touched pivot. Raw, SMA 5, SMA slope, state, Band
  base-line/slope, and shift-0 width facts follow the strict V13 headers.
- Missing feature data marks research incompleteness only.

Schema V13 owns exactly twelve TSV files under
`Common\Files\PivotFractalV13\runs\<run_id>\`: manifest, windows, origins,
H1 trials/outcomes, deep events/links/trials/outcomes, execution checks, broker
outcomes, and summary.

The Python boundary accepts strict V13 only, uses an exhaustive typed registry,
builds native-grain H1/deep/broker/calibration artifacts, audits support and
leakage, and trains explicit offline H1 or deep candidates. Deep event features
join only during explicit deep training. No runtime model or execution filter
is produced.

## Include Pipeline

```text
services/trading_tools.mqh
services/trading_management.mqh
services/trading_signals.mqh
services/frontend.mqh
```

Aggregators own include order. Do not add sibling re-includes, cycles, per-tick
indicator creation, full-history scans, unbounded logging, or unrelated source
ownership. The frontend remains read-only and draws at most 16 owned positions;
nonvisual tester runs do no chart work.

## Validation And Commit Policy

- Do not add MQL5 harnesses, custom test modules, test EAs/scripts, agentic
  MQL5 CI, or new test infrastructure.
- Every sprint requires exact identifier/reference sweeps, include tracing,
  safety-boundary review, and `git diff --check`.
- Maintain existing Python contract tests when schema tooling changes.
- Substantial future multi-sprint work uses one sprint-specific commit after
  each completed gate and records its rollback SHA.
- The accepted V13 compile is pinned in the handoff. Recompile only when source,
  include, compiler, or an explicit acceptance gate changes.
- A final compile must call `get_workspace_info` before `compile_file`, report
  `0 errors, 0 warnings`, and confirm regenerated `.ex5` metadata. Use the
  documented runner only if MCP cannot execute and record the precise reason.
- New MQL5 behavior requires proportional human Strategy Tester/chart
  acceptance. Current V13 lifecycle, broker, export, and performance evidence is
  accepted; only chart-object/rendering verification remains outstanding.

## Style And Rollout

Use 2-space indentation, `snake_case` variables, `CamelCase` functions, and
`ALL_CAPS` enums/constants. Avoid `auto`, lambdas, range-for, unchecked platform
operations, and repeated market-data calls without a reason.

This work does not authorize live rollout. Older-engine positions must be flat,
the account must support hedging, and only one EA instance may run per account
and symbol before any separately approved deployment.
