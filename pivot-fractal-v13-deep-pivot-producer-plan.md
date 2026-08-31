# Plan: Pivot Fractal V13 Deep M10 Producer And H1 Lifecycle Evidence

**Generated**: 2026-08-30
**Status**: Active implementation; Sprints 1-7 complete, Sprint 8 pending
**Estimated Complexity**: High
**Risk class**: High - changes virtual signal geometry, lifecycle state, broker
execution identity, strict export schema, and offline research artifacts. The one
real broker lane must remain structural 1R only.
**Planning baseline**: `bot/pivot_points_fractal` at `d7508f0`
**Downstream dependency**: the Django V13 alignment plan at
`/home/loldlm/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v13-django-research-progression-plan.md`
must not perform its destructive cutover until this plan publishes an accepted
V13 producer handoff with contract and registry hashes.

## Execution Ledger

| Sprint | Commit | Rollback point | Status |
| --- | --- | --- | --- |
| 1 | `8b2069b` | `d7508f0` | Complete |
| 2 | `f05678b` | `8b2069b` | Complete |
| 3 | `84bfb36` | `f05678b` | Complete |
| 4 | `af08a2f` | `84bfb36` | Complete |
| 5 | `1597448` | `af08a2f` | Complete |
| 6 | `a684db5` | `1597448` | Complete |
| 7 | containing documentation commit | `a684db5` | Complete |
| 8 | pending | Sprint 7 commit | Pending compile and human acceptance |

## Overview

Replace the active V12 producer/tooling contract with strict V13 while preserving
the broker-safety kernel and the separation between counterfactual virtual
evidence and broker-confirmed facts.

V13 removes the three Bands-width policies (`13%`, `21%`, and `34%`) and all
policy re-entry generations. Each H1 origin declares only the structural and
50%-midpoint virtual entry lanes, with H1 targets `1R`, `2R`, `3R`, and `5R`.
The broker lane remains one structural `1R` market order, and each accepted
request retains one exact broker-parity shadow outside the H1 matrix for
virtual-versus-broker calibration. A new configurable `Deep_Timeframe` defaults
to `PERIOD_M10` and must be strictly between the configured Micro and Macro
timeframes.

While at least one eligible H1 parent lane is active, the producer observes
same-direction M10 pivot events. A market M10 event is captured once with one
fresh configured-Micro Bands/Stochastic snapshot (`M3` with the accepted
defaults). Explicit parent-link rows associate that event with every H1 lane
active at the trigger, including a broker lane when a real fill exists. Deep
virtual outcomes are limited to `1R`, `2R`, and `3R`. No deep broker order,
runtime model, or execution filter is introduced.

The producer exports terminal duration in authoritative broker-time seconds. The
Django presentation layer exposes `h1_structural_lifecycle_minutes` and
`m10_parent_age_minutes` as exact minute predicates; V13 does not impose a
capture or lifecycle ceiling.

## Scope

- **In scope**:
  - Strict schema `13`, a new `PivotFractalV13` storage root, and a normalized
    12-file TSV contract.
  - `Deep_Timeframe=PERIOD_M10` input validation with
    `Micro_Timeframe < Deep_Timeframe < Macro_Timeframe`.
  - H1 virtual `STRUCTURAL` and `MIDPOINT_50` entry lanes across `1R`, `2R`,
    `3R`, and `5R`, with no re-entry state.
  - The exact halfway geometry between a touched H1 pivot and its next outward
    pivot; midpoint lifecycle time starts at midpoint entry.
  - Causal M10 pivot windows, shared M10 event capture, M3 trigger snapshots,
    H1 parent links, lane-specific parent exit censoring, and deep virtual
    `1R/2R/3R` outcomes.
  - H1 and broker lifecycle duration fields, deterministic same-tick ordering,
    bounded active state, strict headers/manifest/summary, typed registry,
    builder, audit, and offline training updates.
  - One accepted-request broker-parity shadow per successful structural 1R send,
    kept outside H1/deep candidate cohorts and without retries.
  - Active architecture, workflow, environment, research-boundary, and
    downstream handoff documentation.
- **Out of scope**:
  - Any deep M10 broker execution, second risk lane, midpoint broker order,
    runtime model loading, online learning, automatic execution filtering,
    pattern playback, or Django changes in this repository.
  - A maximum 30/60/120-minute capture window, wall-clock aggregation, or
    automatic expiry based on a research filter.
  - Bands-width `13%/21%/34%` policies, their three extra re-entry generations,
    compatibility aliases, dual V12/V13 writes, or active V12 acceptance.
  - New MQL5 test harnesses, custom test EAs/scripts, agentic CI, or automated
    Strategy Tester orchestration.
  - Deletion of archived V12 plans, acceptance records, historical migration
    evidence, or operator-retained raw datasets.

## Fixed Decisions

- **Contract identity**: `schema_version=13`, feature set
  `schema_v13_hft_deep_pivot_features`, storage root
  `Common\\Files\\PivotFractalV13\\runs\\<run_id>\\`. The signal-engine
  family remains `PIVOT_FRACTAL_V2`; the broker magic derives from a new V13
  namespace so an older V2/V12 position is never adopted by the new EA.
- **Exact files and grains**: files are ordered as
  `run_manifest.tsv`, `pivot_windows.tsv`, `signal_origins.tsv`,
  `virtual_trials.tsv`, `virtual_outcomes.tsv`, `deep_pivot_events.tsv`,
  `deep_pivot_parent_links.tsv`, `deep_virtual_trials.tsv`,
  `deep_virtual_outcomes.tsv`, `execution_checks.tsv`, `broker_outcomes.tsv`,
  and `run_summary.tsv`. H1 origins and H1 lanes never share a row with an M10
  event. The event row owns the M3 snapshot; parent-link rows own association
  and censoring facts.
- **H1 lanes**: each consumed H1 origin may declare
  `STRUCTURAL` and `MIDPOINT_50` lanes for `1R`, `2R`, `3R`, and `5R`.
  Structural entry starts at the H1 trigger. Midpoint entry starts only when
  the executable quote touches/crosses the exact halfway level. The shared
  midpoint entry remains armed while at least one structural lane from that
  origin is active, even if the source H1 pivot window has rolled; it is not
  controlled by R5 specifically. If the final structural lane exits before the
  midpoint touch, all pending midpoint ratios close as `NOT_TRIGGERED`, not as
  losses. Once touched, all four midpoint ratios share that one entry timestamp
  and run independently of the structural lanes.
- **Midpoint geometry**: for a buy, midpoint is
  `pivot + 0.5 * (next_outward_pivot - pivot)` toward the next lower support;
  for a sell, it is the equivalent halfway price toward the next higher
  resistance. The next outward S3/R3 extrapolation uses the existing structural
  boundary rule. The stop remains the next outward pivot; target geometry is
  rebuilt from the actual lane entry for exact integer R.
- **H1 trial matrix**: policy identity is `(origin_id, entry_policy,
  tp_r_multiple)`; `tp_r_multiple` is one of `1, 2, 3, 5`. `reentry_index`,
  volatility SL policies, continuation rows, and retry caps are removed from
  active V13 state and headers. Invalid geometry/distance/money remains an
  explicit ineligible row.
- **Broker lane**: only an accepted structural `1R` request can create broker
  exposure. Broker entry, close, duration, profit, and terminal status come from
  actual broker facts. One successful send creates one exact submitted-geometry
  broker-parity shadow in the H1 virtual files for calibration only; it is not
  one of the eight structural/midpoint matrix cells and never retries.
  Midpoint, H1 non-1R, and all deep lanes remain virtual.
- **M10 capture**: use the same causal pivot formula and Bid-side trigger rules
  on `Deep_Timeframe`. Capture only while at least one eligible H1 parent lane
  is active and only in the matching direction. Process H1 terminal transitions
  before same-tick M10 discovery. Freeze the active-parent set immediately
  before deep discovery: a newly entered virtual lane or confirmed broker fill
  may link only after its own entry/fill timestamp exists, and links are never
  added retroactively. Do not hard-code R5 as the controller; the active-lane
  set determines the capture lifetime.
- **Event sharing**: one M10 event identity is
  `(symbol, Deep_Timeframe, active_deep_bar_open, level_id)` within a run.
  Direction is the immutable trigger outcome, not part of identity, matching
  the H1 consumed-pivot rule; the first eligible trigger consumes the event and
  an opposite-direction duplicate cannot be emitted later. The event has one
  configured-Micro feature snapshot. It is linked to each active H1 lane through
  `deep_pivot_parent_links.tsv`; links do not recapture or duplicate indicator
  features.
- **Deep outcomes**: each event declares deep virtual `1R`, `2R`, and `3R`
  trials with no re-entry. Trial geometry is shared at `(event, deep R)`, while
  `deep_virtual_outcomes.tsv` owns one resolution at
  `(parent_link_id, deep_trial_id)`. This is evidence fan-out, not separate M10
  signals or feature recapture. The event enters once at its observed executable
  quote, uses the next outward M10 pivot (including the existing S3/R3
  extrapolation) as its structural stop, normalizes the stop outward to the
  trade-tick grid, and rebuilds exact `1R/2R/3R` targets from the shared risk
  ticks. Existing virtual Bid/Ask resolution and minimum-distance guards apply;
  invalid geometry is explicit and is never reflected, stretched, or routed.
  The shared market path remains observable after the source M10 window expires
  while at least one linked H1 parent is active. A parent/ratio outcome whose
  parent exits first is `CENSORED_PARENT_EXIT`, never `SL_FIRST`; the same shared
  trial may resolve normally for another still-active parent. If all parents exit
  before a trial resolves, every unresolved parent/ratio outcome is censored at
  its own parent exit. Run-end censoring is distinct.
- **Bounded admission**: H1/parity state and deep event/link/trial/outcome state
  use explicit compile-time caps with separate high-water counters. Before a
  deep event is admitted, reserve atomically for one event, the frozen active-
  parent link count, three shared trials, and three outcomes per link. If the
  complete fan-out cannot fit, consume the deep pivot identity and emit one
  explicit `CAPACITY_REJECTED` event/summary fact with no partial links or
  outcomes. Capacity pressure never changes H1/broker lifecycles and is never a
  TP/SL loss. Terminal rows are flushed and released from active memory as soon
  as their remaining references are complete.
- **Duration semantics**: store exact non-negative broker-time seconds. H1
  virtual outcome rows and confirmed broker outcome rows expose their own
  `h1_structural_lifecycle_seconds`; parent links expose
  `m10_parent_age_seconds` and reference exactly one terminal H1 parent. Django
  maps these to public `<=`-only minute selectors using exact multiplication
  (`<= 30` means `<= 1800` seconds), with no source rounding and no implicit
  cap. H1 lifecycle seconds are populated only after an entered virtual lane or
  broker position has a confirmed close; they remain null for `NOT_TRIGGERED`,
  `INELIGIBLE`, and `CENSORED_RUN_END` rows because those rows do not prove a
  complete lifecycle. The final H1 duration is retrospective; the M10 parent age
  is known at trigger time. A midpoint parent's duration starts at its midpoint
  entry, not at the original H1 pivot touch.
- **M3 feature semantics**: at each M10 event, capture the existing fixed Bands
  and Stochastic feature families on configured `Micro_Timeframe` once; this is
  M3 under the accepted defaults, but the manifest must expose the actual source
  timeframe and downstream presentation must not relabel a non-M3 source as M3.
  The immutable touched M10 pivot is the `%B` numerator; shift `0` is developing
  and shifts `1..5` are completed. Missing data marks research incompleteness only.
- **Execution boundary**: virtual/deep rows can never authorize, deny, delay,
  resize, duplicate, close, or modify the one broker order. Export state is
  disabled when `Enable_Signal_Feature_Export=false`, including deep buffers and
  event files.

## Evidence Model

| Grain | Authoritative identity | Main facts | Terminal rule |
| --- | --- | --- | --- |
| H1 origin | `(symbol, macro timeframe, active bar, level)` | Pivot, H1 features, trigger | Origin/window facts remain immutable |
| H1 lane | `(origin, entry policy, H1 R)` | Structural/midpoint entry and geometry | TP/SL, ineligible, not-triggered, or censor |
| Broker lane | Accepted structural 1R request | Actual fill/close and money | Broker history only |
| Broker parity | Accepted structural 1R request | Exact submitted entry/SL/TP/volume virtual shadow | Calibration only; no retry or candidate mixing |
| M10 event | `(symbol, deep bar, level)` | Immutable direction, one M10 trigger, and one M3 snapshot | First eligible trigger consumes the shared event |
| Parent link | `(event, H1 parent lane)` | Parent identity, age, and active interval | References one terminal virtual/broker parent |
| Deep trial | `(event, deep R)` | Shared M10 geometry and 1R/2R/3R declaration | No retry and no feature duplication |
| Deep outcome | `(parent link, deep trial)` | Link-scoped first touch or censor evidence | TP/SL, parent-exit censor, run-end censor, or ineligible |
| Capacity rejection | Consumed M10 event identity | Required/reserved counts and cap high-water facts | No partial fan-out and no target label |

## Assumptions

- `Micro_Timeframe` remains the existing configurable source with `PERIOD_M3` as
  its default; `Deep_Timeframe` is the only new timeframe input. Every run pins
  both actual values, and the default research path is M3/M10/H1.
- The M10 deep structural stop uses the same next-outward-pivot and virtual
  normalization rules already accepted for H1, applied to the causal M10 window.
  Any different deep stop policy would change targets and requires a contract
  decision before Sprint 1, not an implementation-time guess.
- No V13 run exists at the planning baseline. V12 raw runs and generated
  artifacts remain operator-owned historical evidence and are never rewritten as
  V13.
- Final Strategy Tester/chart acceptance is human-operated. Static review,
  Python fixtures, and compilation cannot prove broker-tick lifecycle behavior.

## Named Resources

- **Project instructions**: `AGENTS.md` and the ordered include chain in
  `HFT_Grid_AI.mq5`.
- **Inputs/timeframe validation**:
  `services/trading_management/ea_inputs.mqh`,
  `services/trading_management/pivot_fractal_engine_config.mqh`,
  `services/core/enums.mqh`, and
  `services/utils/market_data_time.mqh`.
- **Pivot/window ownership**:
  `services/indicators/pivot_points_calculator.mqh`,
  `services/trading_signals/pivot_fractal_engine_state.mqh`,
  `services/trading_signals/pivot_fractal_signal_detection.mqh`, and the new
  bounded `services/trading_signals/deep_pivot_signal_struct.mqh` and
  `services/trading_signals/deep_pivot_lifecycle.mqh`.
- **H1 state and broker lifecycle**:
  `services/trading_signals/pivot_signal_struct.mqh`,
  `pivot_signal_state.mqh`, `pivot_signal_lifecycle.mqh`,
  `pivot_trial_matrix_struct.mqh`, `pivot_trial_matrix_state.mqh`,
  `pivot_trial_matrix_geometry.mqh`, `pivot_trial_matrix_lifecycle.mqh`,
  `execution_controller.mqh`, and `execution_broker_reconciliation.mqh`.
- **Feature capture/export**:
  `services/trading_signals/pivot_context_features.mqh`,
  `services/trading_management/indicator_definitions_loader.mqh`,
  `services/trading_signals/pivot_fractal_statistics_export.mqh`,
  `services/trading_signals/execution_controller.mqh`, and
  `services/trading_signals/pivot_fractal_engine_state.mqh`.
- **Entrypoint/aggregators**: `HFT_Grid_AI.mq5`,
  `services/trading_tools.mqh`, `services/trading_management.mqh`,
  `services/trading_signals.mqh`, and `services/frontend.mqh`.
- **Offline contract/tooling**:
  `tools/deterministic_signal_ml/schema_contract.py`, `build_dataset.py`,
  `pivot_fractal_audit.py`, `model_config.py`, `feature_encoder.py`,
  `report_writer.py`, `train_model.py`, `validation_splits.py`, and
  `tools/deterministic_signal_ml/tests/`.
- **Active documentation**: `README.md`, `docs/architecture/market-data-broker-executor.md`,
  `docs/environment/mt5-agentic-workflows.md`,
  `docs/workflows/pivot-fractal-statistics-flow.md`,
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`,
  `docs/research/README.md`, and the new V13 handoff/acceptance records.
- **Compile/test resources**: MetaEditor MCP (`get_workspace_info`, then
  `compile_file`), `tools/mt5/compile_mt5.py` only as the documented fallback,
  `logs/compile/agentic-build.log`, MT5 Strategy Tester, and an operator-owned
  Common Files run folder.
- **Official documentation**:
  - `https://www.mql5.com/en/docs/series/copyrates`
  - `https://www.mql5.com/en/docs/series/itime`
  - `https://www.mql5.com/en/docs/indicators/ibands`
  - `https://www.mql5.com/en/docs/indicators/istochastic`
  - `https://www.mql5.com/en/docs/trading/ordercalcprofit`

## Prerequisites

- Reconfirm the clean producer baseline, branch, MetaEditor workspace roots, and
  Common Files location. Preserve unrelated changes and all archived evidence.
- Keep the current V12 acceptance/fixture available only as historical reference;
  no V12 file may be emitted by the active V13 writer.
- Keep a disposable Python environment for the offline contract suite and one
  operator-controlled real-tick run for final V13 acceptance.
- Define and document the V13 magic namespace before any tester or broker chart
  run; verify all older-engine positions are flat before any future deployment.
- Do not begin the downstream Django destructive cutover until the final V13
  handoff includes schema, header, validator, registry, and fixture hashes.

## Sprint 1: Freeze The Strict V13 Contract And Evidence Grains

**Goal**: Make the new schema, lane identities, time semantics, and deep-event
relationships executable in the offline validator before changing MQL5 runtime state.
**Dependencies**: prerequisites only.
**Tracked scope**: `tools/deterministic_signal_ml/schema_contract.py`, the V13
fixture/provenance tree, and `tools/deterministic_signal_ml/tests/`.
**Commit**: `feat: define strict pivot v13 deep evidence contract`
**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Exact file/header/order, type-registry, identity, duration, censoring, and
  V12-rejection mutations fail closed.

**Rollback point**: `d7508f0` (reconfirm before execution).

### Task 1.1: Define V13 identifiers, files, and typed columns

- **Location**: `tools/deterministic_signal_ml/schema_contract.py` and the V13
  fixture tree.
- **Description**: Replace active V12 constants with schema 13, feature-set,
  storage-root, 12-file order, exact null token, and explicit table headers.
  Add event, parent-link, deep-trial, and deep-outcome columns without JSON
  lists or implicit dynamic columns.
- **Dependencies**: none.
- **Acceptance criteria**:
  - Every V13 column has one owner and one type.
  - H1 features occur only on `signal_origins.tsv`; M3 deep features occur only
    on `deep_pivot_events.tsv`.
  - V12 headers, feature set, and root are rejected rather than converted.
- **Validation**: exact header/type tests and mutation fixtures.
- **Rollback**: revert Sprint 1; no runtime/database state exists.

### Task 1.2: Encode lane, midpoint, ratio, duration, and censoring invariants

- **Location**: `schema_contract.py` and contract tests.
- **Description**: Define `STRUCTURAL`/`MIDPOINT_50`, H1 `1/2/3/5`, deep
  `1/2/3`, no-reentry rules, exact halfway geometry fields, lane-specific
  `h1_structural_lifecycle_seconds`, `m10_parent_age_seconds`, parent-link
  identity, link-and-ratio deep outcome statuses, and event/link/trial
  referential checks.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - A midpoint not touched is `NOT_TRIGGERED`; an unresolved deep link at parent
    exit is censored and never a loss.
  - One event can link to multiple active lanes and three shared deep trials
    without duplicating its configured-Micro feature vector.
  - Every deep outcome identifies exactly one parent link and one deep trial, so
    a 1R result cannot overwrite or imply the 2R/3R result for that parent.
  - Completed H1 exits own lifecycle seconds; no-touch, ineligible, and run-end-
    censored rows keep the duration null and retain their explicit status.
  - Capacity mutation fixtures prove whole-event admission or one explicit
    `CAPACITY_REJECTED` event; orphan/partial links and outcomes fail validation.
  - Same-timestamp parent exit precedes M10 discovery in the oracle rules.
- **Validation**: focused formula, ordering, referential, and terminal-state
  mutation tests.
- **Rollback**: revert the contract and fixture changes together.

### Task 1.3: Freeze the V13 type registry and research-safe feature boundary

- **Location**: `schema_contract.py`, `build_dataset.py` registry declarations,
  and tests.
- **Description**: Separate causal H1/M3 feature columns from retrospective
  terminal fields. Keep duration and terminal facts outside model features;
  define deep event features as a separate evidence grain with explicit parent
  weighting requirements.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance criteria**:
  - Registry is exhaustive/disjoint and reports exact counts.
  - No lifecycle duration, terminal status, outcome, broker money, or censor field
    can enter a model feature set.
- **Validation**: registry hash test and leakage assertions.
- **Rollback**: revert Sprint 1.

### Sprint 1 Gate

- [x] All Sprint 1 tasks complete.
- [x] V13 fixture, mutations, exact headers, registry, and V12 rejection pass.
- [x] No `.mq5`/`.mqh`, broker behavior, or generated run changed.
- [x] `git diff --check` and identifier review pass.
- [x] Exactly one Sprint 1 commit is created and its rollback SHA is recorded.
- [x] Sprint 2 does not start before this gate is complete.

## Sprint 2: Simplify H1 Virtual Lanes And Add The 50% Midpoint

**Goal**: Replace the V12 matrix/retry lifecycle with deterministic structural and
midpoint H1 lanes while leaving the one real structural 1R broker path intact.
**Dependencies**: Sprint 1 gate.
**Tracked scope**: `services/trading_management/ea_inputs.mqh`,
`pivot_fractal_engine_config.mqh`, `pivot_signal_struct.mqh`,
`pivot_signal_state.mqh`, `pivot_trial_matrix_struct.mqh`,
`pivot_trial_matrix_state.mqh`, `pivot_trial_matrix_geometry.mqh`,
`pivot_trial_matrix_lifecycle.mqh`, `pivot_fractal_signal_detection.mqh`,
`pivot_signal_lifecycle.mqh`, and broker magic helpers.
**Commit**: `refactor: simplify h1 virtual lanes and add midpoint`
**Demo/Validation**:

- Static call-graph and state-transition review.
- Exact sweeps prove no active `MICRO_BW_13`, `MICRO_BW_21`,
  `MICRO_BW_34`, re-entry-generation, continuation, or retry-cap path remains.
- `git diff --check`; no intermediate MetaEditor compile.

**Rollback point**: Sprint 1 commit.

### Task 2.1: Replace policy/retry identities with H1 entry lanes

- **Location**: `pivot_fractal_engine_config.mqh`, matrix structs/state/lifecycle.
- **Description**: Add the two entry-policy identities and H1 target choices;
  remove Bands-width stop policies, re-entry indices, continuation state, and
  retry transitions. Rebuild bounded active-state accounting for eight H1 lane
  declarations per origin, with explicit ineligible statuses. Keep the existing
  accepted-request parity role outside that eight-cell matrix with no retry
  fields or policy identity.
- **Dependencies**: Sprint 1.
- **Acceptance criteria**:
  - Each origin declares structural/midpoint x `1R/2R/3R/5R` exactly once.
  - No policy reopens after SL; no virtual retry can create a new signal.
  - Structural stop geometry remains the existing next-pivot rule.
  - A successful broker send creates at most one parity shadow and an origin
    without an accepted request creates none.
- **Validation**: identifier sweep, state-machine walk-through, and geometry
  review.
- **Rollback**: restore the pre-Sprint-2 matrix lifecycle.

### Task 2.2: Implement midpoint touch and lane-specific lifecycle clocks

- **Location**: `pivot_trial_matrix_geometry.mqh`, signal detection/state, and
  outcome structures.
- **Description**: Calculate the exact halfway price toward the next outward
  pivot, arm it without treating the original H1 trigger as its entry, and
  record lane entry/terminal timestamps and `h1_structural_lifecycle_seconds`.
  Keep the shared midpoint armed while any structural lane from the origin is
  active, then finalize all untouched midpoint ratios as `NOT_TRIGGERED` when
  that active set becomes empty. Preserve quote-side, gap, distance, and exact-R
  normalization rules.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Midpoint uses the correct buy/sell direction and S3/R3 boundary.
  - No-touch, invalid geometry, and run-end states are explicit and not losses.
  - H1 bar rollover alone neither triggers nor cancels a pending midpoint; the
    origin's active structural-lane set owns that boundary without an R5 special
    case.
  - Structural and midpoint lanes can have different lifecycle durations.
- **Validation**: pure geometry walk-through, boundary review, and static
  terminal-state inspection.
- **Rollback**: revert midpoint state and geometry changes.

### Task 2.3: Isolate V13 broker identity and preserve one real lane

- **Location**: `execution_controller.mqh`, `execution_broker_reconciliation.mqh`,
  `pivot_signal_lifecycle.mqh`, and magic helpers.
- **Description**: Derive a V13 namespace magic, reject/adopt no older-engine
  positions, keep broker SL/TP immutable, and ensure midpoint/non-1R/deep lanes
  never reach `OrderSend`. Preserve creation of one parity shadow from the exact
  accepted structural 1R request without allowing that shadow to influence
  routing or H1/deep candidate outcomes.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Only structural 1R broker requests pass the send boundary.
  - Existing broker checks, FOK, volume, margin, and reconciliation ownership
    remain unchanged except for the V13 identity namespace.
- **Validation**: broker safety-boundary diff review and exact send-call sweep.
- **Rollback**: restore the prior magic and lane gate before any live use.

### Sprint 2 Gate

- [x] H1 lane matrix and midpoint geometry are complete.
- [x] Bands policies and all retry/re-entry code are absent from active paths.
- [x] Broker path remains one structural 1R lane with a distinct V13 magic.
- [x] Static safety and `git diff --check` pass.
- [x] Exactly one Sprint 2 commit is created and rollback recorded.

## Sprint 3: Add The Causal M10 Pivot Window And Shared Event State

**Goal**: Add configurable M10 pivot observation with strict timeframe ordering and
no per-ratio signal duplication.
**Dependencies**: Sprint 2 gate.
**Tracked scope**: `ea_inputs.mqh`, `market_data_time.mqh`,
`pivot_points_calculator.mqh`, `pivot_fractal_engine_state.mqh`,
`pivot_fractal_signal_detection.mqh`, new `deep_pivot_signal_struct.mqh`,
new `deep_pivot_lifecycle.mqh`, and `trading_signals.mqh` include ordering.
**Commit**: `feat: add causal m10 deep pivot lifecycle`
**Demo/Validation**:

- Static include trace from `HFT_Grid_AI.mq5` through the ordered aggregators.
- Timeframe validation review proves `M3 < M10 < H1` through checked platform
  `PeriodSeconds` values (or one thin project helper), not raw enum integer
  ordering, with supported/distinct checks and no synthetic bars.
- Same-tick event-order and active-parent-capacity review; no intermediate compile.

**Rollback point**: Sprint 2 commit.

### Task 3.1: Add and validate `Deep_Timeframe`

- **Location**: `services/trading_management/ea_inputs.mqh` and timeframe helpers.
- **Description**: Add one public `Deep_Timeframe` input defaulting to
  `PERIOD_M10`; validate it is supported, distinct, and ordered by normalized
  timeframe seconds as `Micro < Deep < Macro` (never by raw enum integer value).
  Include its pinned value in the manifest/config digest.
- **Dependencies**: Sprint 2.
- **Acceptance criteria**:
  - Defaults are M3/M10/H1 and the normalized ordering check is deterministic.
  - Invalid or equal ordering fails initialization before deep state is created.
  - No unrelated public inputs return.
- **Validation**: input/reference sweep and initialization-path review.
- **Rollback**: remove only the new input and validation branch.

### Task 3.2: Own one causal M10 window cache

- **Location**: `pivot_points_calculator.mqh`, engine state, and deep lifecycle.
- **Description**: Calculate M10 PP/S1..S3/R1..R3 from the previous completed M10
  candle, honor observed tick visibility, refresh only on a new bar or bounded
  data-availability retry, and give each level one direction-independent consumed
  event identity. Reuse existing pivot math without full-history scans; the data
  refresh retry is not a virtual signal re-entry.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Incomplete/future bars cannot activate a deep window.
  - Buy/sell Bid trigger order and level consumption match the H1 causal rules.
  - Direction is stored as the event outcome and cannot create a second identity
    for the same level/window.
  - A shared event is not emitted twice for the same deep identity.
- **Validation**: formula/path review, series bounds review, and bounded-hot-path
  inspection.
- **Rollback**: revert deep window state while preserving H1 behavior.

### Task 3.3: Gate discovery on active, same-direction H1 parents

- **Location**: `deep_pivot_lifecycle.mqh`, H1 lane state, and tick orchestration.
- **Description**: Maintain an explicit active-parent registry. Process H1
  terminal transitions first, register only virtual entries and broker fills
  whose timestamps already exist, freeze that parent set, then discover M10
  events only for matching active lanes. Permit overlapping ratio/entry lanes
  without creating one M10 signal per lane or retroactively linking a later
  parent.
- **Dependencies**: Task 3.2.
- **Acceptance criteria**:
  - No parent means no deep event capture.
  - A structural lane can end while 2R/3R/5R or midpoint lanes continue.
  - R5 is not a special-case controller; the active set controls lifetime.
- **Validation**: same-tick sequence review and atomic event/link/trial/outcome
  capacity accounting at zero, exact-fit, and one-over-cap boundaries.
- **Rollback**: disable deep discovery while retaining validated H1 state.

### Sprint 3 Gate

- [x] `Deep_Timeframe` and causal M10 windows are validated.
- [x] Include order is acyclic and event discovery is active-parent/same-direction
  restricted.
- [x] No per-ratio M10 signal creation exists.
- [x] Static review and `git diff --check` pass; exactly one commit is recorded.

## Sprint 4: Capture One M3 Snapshot And Resolve Parent-Scoped Deep Lifecycles

**Goal**: Persist one M10 event/M3 vector and deterministic parent-link/deep outcome
state for all active H1 lanes.
**Dependencies**: Sprint 3 gate.
**Tracked scope**: `pivot_context_features.mqh`, indicator handle ownership,
`deep_pivot_signal_struct.mqh`, `deep_pivot_lifecycle.mqh`, H1/broker outcome
structures, and bounded active-state helpers.
**Commit**: `feat: capture m3 deep pivot evidence and parent links`
**Demo/Validation**:

- Static buffer/handle lifecycle and formula review.
- Exact checks prove one M3 snapshot per M10 event and no feature recapture for
  ratios or parent links.
- Parent-exit/run-end censoring walk-through; no intermediate compile.

**Rollback point**: Sprint 3 commit.

### Task 4.1: Reuse fixed M3 indicator handles at M10 events

- **Location**: `indicator_definitions_loader.mqh`, `pivot_context_features.mqh`,
  and feature state.
- **Description**: Reuse the existing cached Micro Bands/Stochastic handles,
  capture bounded shifts once per M10 event, validate `CopyBuffer` counts and
  current-bar visibility, and calculate `%B` against the immutable touched M10
  pivot. Do not create handles per tick/event.
- **Dependencies**: Sprint 3.
- **Acceptance criteria**:
  - Export disabled performs no deep indicator work.
  - Export enabled still owns only the four expected handles.
  - Event rows pin the configured Micro timeframe; default M3 terminology cannot
    hide a non-M3 configured source.
  - Missing configured-Micro data marks the event incomplete without changing
    trigger/routing.
- **Validation**: handle count/release sweep, buffer-index review, and formula
  walk-through.
- **Rollback**: remove deep snapshot calls; retain M10 event identity.

### Task 4.2: Create parent links without feature duplication

- **Location**: `deep_pivot_lifecycle.mqh` and parent-link structures.
- **Description**: For every eligible active broker or virtual H1 lane in the same
  direction, append one link with parent lane identity, entry time, event time,
  `m10_parent_age_seconds`, and active/terminal state. Keep the event's M3
  vector in one owned object/row.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - One event can have many links; each link has one immutable parent age.
  - A midpoint link begins only after midpoint entry.
  - Broker links exist only after a confirmed fill.
- **Validation**: identity/uniqueness review and parent-association scenarios.
- **Rollback**: revert link persistence while retaining event capture code.

### Task 4.3: Implement deep 1R/2R/3R outcomes and censoring

- **Location**: `deep_pivot_lifecycle.mqh`, deep trial/outcome structures, and
  H1 terminal orchestration.
- **Description**: Declare one shared event-level trial for each deep R, observe
  first touches with correct Bid/Ask sides, use one executable event entry and
  next-outward-M10-pivot stop for all three ratios, and finalize one outcome for
  every `(parent link, deep trial)` pair. Distinguish `TP_FIRST`, `SL_FIRST`,
  `CENSORED_PARENT_EXIT`, `CENSORED_RUN_END`, and `INELIGIBLE`; deep events are
  already triggered, so `NOT_TRIGGERED` remains an H1 midpoint state rather
  than a deep outcome state.
- **Dependencies**: Task 4.2.
- **Acceptance criteria**:
  - No deep 5R row or retry row exists.
  - The shared stop/entry is normalized once, targets are exact integer R, and
    invalid distance/geometry is explicit rather than stretched or reflected.
  - A deep path cannot become a loss merely because one parent ended, and each
    parent can have different 1R/2R/3R terminal states without ambiguity.
  - If all parents end, the event stops observing at the last parent exit and
    all unresolved link/ratio outcomes are explicitly censored.
  - Completed link outcomes are released safely while shared trial geometry
    remains alive for other parents; reference counts cannot underflow or leak.
- **Validation**: first-touch/censoring state review and active-capacity bounds.
- **Rollback**: disable deep outcome resolution; preserve raw event identity.

### Sprint 4 Gate

- [x] Four cached handles remain correctly owned/released.
- [x] M10 event/configured-Micro snapshot is single-capture and parent links are
  unique.
- [x] Deep 1R/2R/3R outcomes and parent/run censoring are explicit.
- [x] No deep broker send path, deep 5R, or retry path exists.
- [x] Static review and one Sprint 4 commit/rollback point are recorded.

## Sprint 5: Emit The Strict V13 TSV Export And Reconcile All Lanes

**Goal**: Replace the active V12 exporter with deterministic V13 serialization,
summary counts, and cross-file integrity checks.
**Dependencies**: Sprint 4 gate.
**Tracked scope**: `pivot_fractal_statistics_export.mqh`,
`pivot_signal_struct.mqh`, `pivot_trial_matrix_struct.mqh`,
`pivot_fractal_engine_state.mqh`, `execution_controller.mqh`,
`pivot_signal_lifecycle.mqh`, `HFT_Grid_AI.mq5`, and active callers.
**Commit**: `feat: emit strict pivot v13 export`
**Demo/Validation**:

- Exact header/append-order comparison against `schema_contract.py`.
- Export-off/export-on broker event parity review.
- Active identifier sweep rejects `PIVOT_V12`, `PivotV12`, `PivotFractalV12`,
  old Bands policies, and re-entry symbols outside archives.
- `git diff --check`; no intermediate MetaEditor compile.

**Rollback point**: Sprint 4 commit.

### Task 5.1: Replace V12 writer identity and file lifecycle

- **Location**: `pivot_fractal_statistics_export.mqh` and `HFT_Grid_AI.mq5` callers.
- **Description**: Pin schema 13, feature set, V13 root, exact 12-file order,
  manifest keys, file open/flush/close behavior, and failure status. Remove
  dual-write and active V12 aliases.
- **Dependencies**: Sprint 4.
- **Acceptance criteria**:
  - A run is visible only when all 12 files exist and `run_summary.tsv` carries
    the completed seal/reconciliation state.
  - Partial initialization/deinitialization closes every file safely.
  - Export failure cannot authorize or alter broker execution.
- **Validation**: file lifecycle/reference sweep and header contract test.
- **Rollback**: restore the V12 writer only before any V13 production run.

### Task 5.2: Serialize H1, broker, event, link, and deep rows in causal order

- **Location**: exporter append helpers and outcome structures.
- **Description**: Append H1 lane lifecycle seconds, broker-confirmed duration,
  one accepted-request parity shadow and its calibration outcome, one M10
  event/M3 vector, parent ages/references, shared deep 1R/2R/3R trials, and one
  terminal row per parent-link/deep-trial pair. Preserve distinct trigger,
  entry, fill, terminal, and analysis timestamps.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - Every foreign key resolves within the run and every identity is unique.
  - Lifecycle seconds are non-null only for confirmed completed H1 virtual or
    broker exits; censored/no-entry rows retain null plus their terminal status.
  - Parent links never contain an event after their lane's terminal time.
  - Deep outcome cardinality reconciles to the declared eligible
    parent-link/deep-trial pairs; no ratio borrows another ratio's status.
  - Parity rows join only to the accepted broker request and remain outside H1
    matrix, deep, and model-target cohorts.
  - Censored/ineligible/not-triggered rows remain explicit and are not counted as
    binary losses.
- **Validation**: append-order walk-through and exact row-integrity checks.
- **Rollback**: revert row append changes together.

### Task 5.3: Rebuild summary/capacity/reconciliation facts

- **Location**: exporter summary and engine integrity helpers.
- **Description**: Replace V12 matrix/retry counters with H1 lane, deep event,
  parent-link, deep-trial, censor, broker, parity-calibration, and active-state
  counts. Include configuration/timeframe/namespace pins and fail the run on
  referential or capacity integrity errors.
- **Dependencies**: Task 5.2.
- **Acceptance criteria**:
  - Summary totals reconcile exactly to all 12 files.
  - Active-state capacity is bounded and reported, never silently dropping rows.
  - A capacity-rejected event reconciles as one consumed event with zero links,
    zero trials/outcomes, required/reserved counts, and no binary target.
  - Natural tester completion and run-end censoring remain distinct.
- **Validation**: summary arithmetic review and static bounded-loop inspection.
- **Rollback**: revert summary changes.

### Sprint 5 Gate

- [x] Strict V13 headers, root, manifest, row order, and summary reconcile.
- [x] No active V12 writer, Bands-width policy, or re-entry reference remains.
- [x] Broker and virtual ownership boundaries are preserved.
- [x] `git diff --check` passes; exactly one Sprint 5 commit is recorded.

## Sprint 6: Update The Typed Builder, Audit, And Offline Research Artifacts

**Goal**: Make V13 runs consumable without duplicating M3 features or leaking terminal
duration into causal/model features.
**Dependencies**: Sprint 5 gate.
**Tracked scope**: `tools/deterministic_signal_ml/build_dataset.py`,
`pivot_fractal_audit.py`, `model_config.py`, `feature_encoder.py`,
`report_writer.py`, `train_model.py`, `validation_splits.py`, tests, and README.
**Commit**: `feat: build and audit pivot v13 research artifacts`
**Demo/Validation**:

- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Build/audit the tracked V13 fixture; verify long/wide/chain/deep-parent outputs,
  exact counts, and explicit censored/ineligible partitions.
- Run the documented offline training ablations only after builder/audit pass.

**Rollback point**: Sprint 5 commit.

### Task 6.1: Replace the exhaustive V12 registry and typed loads

- **Location**: `build_dataset.py`, schema imports, and generated/report metadata.
- **Description**: Define all V13 tables/types and deterministic joins. Keep
  `signal_origins` and `deep_pivot_events` at their native grains; never copy
  event features into each parent lane or deep ratio row.
- **Dependencies**: Sprint 1 contract and Sprint 5 headers.
- **Acceptance criteria**:
  - Unknown files/columns/types fail closed.
  - Every row is typed and every join is referentially complete.
  - Parent/event counts and unique-origin counts are reported separately.
- **Validation**: fixture/mutation tests and registry hash review.
- **Rollback**: restore V12 tooling before accepting any V13 run.

### Task 6.2: Build leakage-safe H1 and deep cohorts

- **Location**: `build_dataset.py`, `pivot_fractal_audit.py`, and
  `validation_splits.py`.
- **Description**: Add H1 lane, broker, deep-event, and parent-link derived
  tables plus a separate broker-parity calibration table. Join shared trials to
  link-scoped deep outcomes, apply parent-exit censoring before binary targets,
  weight deep rows by unique H1 origin, and keep
  `h1_structural_lifecycle_seconds` and terminal fields outside causal/model
  feature columns.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - A parent with many M10 events cannot inflate origin support.
  - A censored/ineligible/not-triggered row is never a target-zero loss.
  - A lifecycle-duration research cohort requires a non-null confirmed duration;
    censored/no-entry rows remain visible in separate support counts.
  - Deep `1R/2R/3R` lanes are separate; no deep 5R or retry artifact exists.
  - Broker parity remains calibration evidence and never enters H1/deep model
    target cohorts.
- **Validation**: audit invariants, support/weight checks, and leakage assertions.
- **Rollback**: revert derived-table changes.

### Task 6.3: Keep offline XGBoost explicit and separated by evidence grain

- **Location**: `model_config.py`, `feature_encoder.py`, `train_model.py`,
  `report_writer.py`, and tests.
- **Description**: Preserve offline-only training, add an explicit H1/deep
  feature-set selector, prohibit terminal duration/target columns, and record
  source grain, parent weighting, cutoff, and warnings in reports.
- **Dependencies**: Task 6.2.
- **Acceptance criteria**:
  - No runtime model artifact or execution filter is produced.
  - H1 and deep reports cannot be silently combined as one cohort.
- **Validation**: model-config rejection tests and fixture training smoke.
- **Rollback**: restore the prior offline-only model configuration.

### Sprint 6 Gate

- [x] V13 fixture builds/audits with exact typed joins and no leakage.
- [x] H1/deep/broker cohorts and origin weights reconcile.
- [x] Offline training remains explicitly separated from MT5 execution.
- [x] Focused Python suite and `git diff --check` pass; one commit/rollback point
  is recorded.

## Sprint 7: Update Active Documentation And Publish The V13 Handoff

**Goal**: Make the producer/downstream contract operationally understandable and
  auditable before final compilation.
**Dependencies**: Sprint 6 gate.
**Tracked scope**: `AGENTS.md`, `README.md`, active architecture/workflow/
environment/research docs, `docs/research/`, and `docs/plans/README.md`.
**Commit**: `docs: publish pivot v13 producer handoff`
**Demo/Validation**:

- Exact reference sweeps for V13 identifiers, file order, timeframe ordering,
  duration names, and removed V12/policy/retry names.
- `git diff --check` and documentation link/path review.
- Record the planned final compile/tester commands; do not claim runtime pass.

**Rollback point**: Sprint 6 commit.

### Task 7.1: Update active architecture and lifecycle contracts

- **Location**: `AGENTS.md`, `docs/architecture/market-data-broker-executor.md`,
  `docs/workflows/pivot-fractal-statistics-flow.md`, and
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`.
- **Description**: Document the 12-file grain map, H1 lane matrix, midpoint
  clock, shared M10/M3 event, parent-link censoring, exact duration semantics,
  V13 magic boundary, and no-deep-broker rule.
- **Dependencies**: completed runtime/export tasks.
- **Acceptance criteria**: active docs do not describe V12 as supported or imply
  a 120-minute cap; archives remain explicitly historical.
- **Validation**: path/reference sweep and prose consistency review.
- **Rollback**: restore prior active docs without touching archives.

### Task 7.2: Freeze the downstream handoff and acceptance checklist

- **Location**: new `docs/research/pivot-fractal-v13-producer-handoff.md` and
  `docs/research/pivot-fractal-v13-producer-acceptance-YYYY-MM-DD.md`.
- **Description**: Record accepted producer commit, schema/feature/root pins,
  validator and registry SHA-256 values, fixture provenance, exact file/header
  hashes, compile artifact metadata, tester scenarios, and known residual risks.
- **Dependencies**: Tasks 6.1-6.3 and final acceptance evidence placeholders.
- **Acceptance criteria**: Django can vendor the handoff without guessing any
  column, grain, ratio, or censoring rule.
- **Validation**: hash/path review and handoff checklist review.
- **Rollback**: remove only the unpublished handoff draft.

### Sprint 7 Gate

- [x] Active documentation is V13-only and archived V12 evidence is preserved.
- [x] Handoff fields, hashes, and acceptance checklist are complete or explicitly
  marked pending final evidence.
- [x] Static identifier/include/safety review and `git diff --check` pass.
- [x] Exactly one Sprint 7 commit is recorded before compilation.

## Sprint 8: Final MetaEditor Compile And Human V13 Acceptance

**Goal**: Produce the first accepted V13 binary/run and publish evidence for the
downstream Django cutover.
**Dependencies**: Sprint 7 gate; no Django destructive cutover may precede this
  sprint's acceptance.
**Tracked scope**: final producer source, compile logs/artifacts, operator-owned
  tester output, V13 handoff/acceptance records, and no unrelated files.
**Commit**: `chore: accept pivot v13 producer compile and tester gate`
**Demo/Validation**:

- Call MetaEditor MCP `get_workspace_info` first, then `compile_file` for the EA;
  require `0 errors, 0 warnings` and confirm regenerated `.ex5` metadata. Use
  `tools/mt5/compile_mt5.py` only if the MCP cannot execute, recording the exact
  fallback reason.
- Run the documented strict V13 fixture build/audit and one operator-controlled
  real-tick/Strategy Tester acceptance.
- Preserve raw logs as local artifacts and record only bounded diagnostics in the
  handoff.

**Rollback point**: Sprint 7 commit plus the accepted pre-V13 binary/source SHA.

### Task 8.1: Run the single final compile and artifact check

- **Location**: MetaEditor workspace and `logs/compile/agentic-build.log`.
- **Description**: Compile the entrypoint through the preferred MCP, verify no
  warnings/errors, confirm `.ex5` timestamp/hash changed, and run final static
  identifier/include/safety sweeps.
- **Dependencies**: all prior gates.
- **Acceptance criteria**: exact compiler gate passes; no active V12/policy/retry
  references exist outside archives.
- **Validation**: MCP result, artifact metadata, `git diff --check`, and sweeps.
- **Rollback**: use the Sprint 7 source/binary before any tester run.

### Task 8.2: Perform human lifecycle and broker-safety acceptance

- **Location**: operator-controlled MT5 Strategy Tester/chart session and V13
  Common Files run folder.
- **Description**: Verify midpoint touch/no-touch, all H1 R targets, differing
  lane exits, shared M10 event/M3 snapshot, `m10_parent_age_seconds`, parent-exit
  censoring, R5-longest behavior without hard-coding, same-tick ordering, broker
  structural 1R only, and no deep order submission.
- **Dependencies**: Task 8.1.
- **Acceptance criteria**: exported rows and chart/history facts match the causal
  contract; censored rows are not losses; broker facts come from actual history.
- **Validation**: manual acceptance matrix and bounded run audit.
- **Rollback**: stop V13 tester/use and return to the accepted pre-V13 binary.

### Task 8.3: Publish final V13 handoff evidence

- **Location**: `docs/research/pivot-fractal-v13-producer-handoff.md`, final
  acceptance record, and local artifact index.
- **Description**: Add final commit, compile, fixture, registry, run, and
  residual-risk evidence; explicitly authorize the downstream plan to prepare
  but not silently skip its V12 deletion gate.
- **Dependencies**: Tasks 8.1-8.2.
- **Acceptance criteria**: every hash/path is reproducible and no private account,
  credential, or raw run data is committed.
- **Validation**: handoff review and privacy sweep.
- **Rollback**: supersede the handoff with a corrected record; do not rewrite
  historical V12 records.

### Sprint 8 Gate

- [ ] Final MetaEditor compile reports `0 errors, 0 warnings` and `.ex5` metadata
  is confirmed.
- [ ] Human tester/chart acceptance covers broker, H1, midpoint, M10, M3,
  ratio, censoring, and export-off parity cases.
- [ ] V13 fixture/build/audit evidence and handoff hashes are complete.
- [ ] Exactly one Sprint 8 commit is created and its rollback point is recorded.
- [ ] Django V13 cutover is not started until this gate is signed off.

## Testing Strategy

- **Contract/unit**: strict V13 headers, type registry, formulas, identity,
  midpoint geometry, exact-R normalization, timeframe ordering, first-touch,
  direction-independent M10 consumption, deep structural geometry, duration
  nullability, parent-link, censoring, and V12 rejection mutations in
  `tools/deterministic_signal_ml/tests/`.
- **Static MQL5 review**: include trace, exact identifier/reference sweeps,
  `CopyBuffer`/series bounds, handle release, same-tick ordering, bounded active
  state, broker send boundary, and `git diff --check` every sprint.
- **Offline integration**: fixture validation, typed DuckDB/Parquet build, audit,
  H1/deep grain joins, unique-origin weighting, leakage checks, and offline-only
  model smoke.
- **Compile**: one final real MetaEditor MCP compile; syntax-only fallback is not
  accepted as binary proof.
- **Runtime/manual**: human Strategy Tester/chart matrix for midpoint, all H1
  ratios, shared M10 events, M3 snapshots, parent-specific censoring, R5
  continuation, broker structural 1R, and export parity.
- **Non-functional**: bounded per-tick work, no per-event handle creation, bounded
  files/logging/state, atomic fan-out admission, reference-safe release,
  deterministic cleanup, and no private data in handoff.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| M10 rows are duplicated per H1 ratio | Inflated support and false confidence | One event row plus explicit parent links; unique-origin weights | Event/link count and builder audit |
| M10 direction creates a second event identity | The same pivot is counted twice after a reversal | Consume `(symbol, deep timeframe, bar, level)` once; store direction as an outcome | Opposite-direction mutation fixture |
| M10 outcome continues after a parent exits | Deep statistics mix inside/outside lifecycle | Link-specific `CENSORED_PARENT_EXIT`; stop when all parents exit | Same-tick/censoring scenarios |
| Final H1 duration leaks into a causal rule | Retrospective selection is mistaken for live evidence | Separate duration segmentation from M10 age condition; exclude duration from model features | Registry/progression leakage tests |
| Run-end age is mistaken for a completed H1 lifecycle | Incomplete parents can enter a misleading short-duration cohort | Keep lifecycle seconds null on censor/no-entry states and report them separately | Null/status and cohort-reconciliation tests |
| R5 is assumed to control every capture | Missing or overlong parent windows | Active-lane registry, no R5 special case | Multi-lane tester scenario |
| Midpoint is treated as original entry | Wrong age, SL, TP, and duration | Separate lane entry timestamp and `NOT_TRIGGERED` state | Geometry/lifecycle tests |
| Old V2/V12 position is adopted | Unauthorized modification/close | New V13 magic namespace and flat-account rollout gate | Reconciliation/magic sweep |
| Deep event is sent to broker | Unplanned exposure | Deep paths terminate at virtual exporter only | `OrderSend` call-graph review |
| Partial V13 export is ingested | Incomplete research or orphan rows | 12-file seal, strict validator, summary reconciliation | Intake/build failure tests downstream |
| Deep fan-out partially exceeds active capacity | Orphan links/outcomes and biased evidence | Atomically reserve the full event fan-out or emit `CAPACITY_REJECTED` only | Exact-fit/one-over-cap mutation and high-water audit |
| Active-state growth exhausts memory | Tester/runtime instability | Explicit cap, counters, fail-closed integrity status | Capacity audit and summary |

## Rollback Plan

- Before Sprint 8, revert only the latest sprint commit(s) to the recorded
  rollback point; no V13 production run is treated as V12-compatible.
- If the final compile or tester gate fails, stop V13 use and restore the Sprint 7
  source/binary. Do not alter archived V12 plans, acceptance records, or old runs.
- A V13 run with failed integrity remains an operator artifact and is not handed to
  Django. Correct the producer and create a new run ID; do not mutate a failed run.
- After Django consumes an accepted handoff, producer rollback requires a new
  explicitly versioned handoff and a coordinated Django decision; never silently
  emit V12 or dual-write.
- Any future live rollout still requires older-engine positions flat, hedging
  support, one EA per account/symbol, and explicit human authorization.

## Execution Order

1. Implement and validate Sprint 1 only; create its single commit and rollback
   record.
2. Advance through Sprints 2-7 one gate at a time; never compile intermediate
   MQL5 sprints unless a human changes the plan.
3. Run Sprint 8 final compile, tester acceptance, and handoff publication.
4. Give the accepted handoff to the Django V13 plan.
5. Django may then prepare its contract/migration work, but its explicit V12 data
   deletion and active-code removal gate remains separate and operator-confirmed.

## Completion Checklist

- [x] Strict V13 producer contract and 12-file fixture are accepted.
- [x] Bands-width policies and all re-entry code are removed from active paths.
- [x] Structural/midpoint H1 lanes and H1 `1R/2R/3R/5R` lifecycles are exact.
- [x] Configurable M10 windows, shared events, one M3 snapshot, parent links, and
  deep `1R/2R/3R` outcomes are exported and reconciled.
- [x] Broker remains one structural 1R lane with V13 magic isolation.
- [x] Accepted structural 1R sends retain one separate broker-parity calibration
  shadow without retries or candidate mixing.
- [x] Builder/audit/offline training are grain-aware and leakage-safe.
- [ ] Final compile, tester/chart acceptance, hashes, and handoff are recorded.
- [ ] Every sprint has exactly one commit and a recorded rollback point.
