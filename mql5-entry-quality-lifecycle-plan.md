# Plan: MQL5 Entry Quality, Pivot Expiry And Backend Handoff

**Generated:** 2026-09-27

**Status:** Executing Sprint 2; Sprint 1 committed as `47556f9`.

**Execution authorization:** The user explicitly authorized execution of all five sprints on 2026-09-27, including the specified checks and sprint commits. Backend implementation and live rollout remain excluded.

**Proposal:** The accepted discussion in this conversation; no separate proposal requested.

**Complexity:** High; two execution engines, historical compatibility and broker close ownership.

**Baseline:** `406a7d9`, branch `bot/pivot_points_fractal`; clean checkout at planning start.

Start with the [project index](docs/README.md),
[runtime contract](docs/architecture/market-data-broker-executor.md),
[dataset contract](docs/architecture/model-feature-dataset.md) and
[validation runbook](docs/environment/mt5-agentic-workflows.md).

## 1. Outcome And Scope

Both EAs will reject new broker and virtual entries whose executable entry-to-SL
distance is too small relative to the observed spread and broker constraints.
Pivot will additionally close unresolved broker positions and finish entered
virtual lanes at their own entry-plus-Macro deadline. Rejections, actual closes,
time exits and run censors remain distinct exported facts.

This repository delivers the MQL5 implementation, strict local-reader support,
generation evidence and an incremental backend handoff. The backend later owns
daily, node-specific `Trades_Offset` / `Trades_Limits`, discovery/WFO integration,
consumer intake and its own performance work. The previous handoff is complete
for this task; do not reopen its old execution plan or operator follow-ups.

In scope:

- Fixed entry admission for Pivot structural/broker entries, midpoint touches,
  and Candle originals/re-entries and their virtual lanes.
- Pivot broker expiry, virtual expiry and immutable execution/audit evidence.
- Versioned engine policies, unchanged historical interpretation, focused tests,
  native real-tick checks and representative one-year generation acceptance.
- Extension to at most three years only when recorded evidence justifies it.
- A new incremental backend handoff, including exact node/day selection examples.

Out of scope:

- Backend source edits, imports, migrations, inference work or deployment.
- Live rollout, account changes, historical dataset rewriting or cleanup of
  operator data, global configuration, installed skills or plugin caches.
- A ten-year run, a twenty-minute acceptance threshold or extrapolated ten-year
  certification. The user's latest instruction replaces that proposed gate.
- New public EA inputs, execution offset/limit controls, strategy optimization,
  widening existing stops, trailing, break-even, partial-close policies or re-entry
  changes beyond applying the new admission rule to existing entry attempts.
- New MQL5 harnesses, test EAs/scripts, CI, services or test infrastructure.

## 2. Accepted Decisions And Technical Choices

| ID | Decision and authority | Consequence |
| --- | --- | --- |
| D01 | User answer 1: the spread rule declines actual orders and virtual entries at entry time. | Execution owns its check independently of export; later spread changes cause no new rejection or close. |
| D02 | User answer 5: fixed `3 * spread + max(stops, freeze) + one trade tick`, using consistent units, for both EAs; no new input. | Use the exact formula below; no multiplier search or backend reinterpretation. |
| D03 | User answers 2 and follow-up: every node counts its own complete path-filtered trade sequence. | Backend filters before selection and recomputes from the full eligible stream at every depth. |
| D04 | User answer 3: counters reset each daily research window. | Offset 3 / limit 2 selects the fourth and fifth matches independently each day; no carryover. |
| D05 | User answer 4: Pivot expiry closes actual broker positions and ends virtual trades. | Add execution-owned close reconciliation and per-entry virtual deadlines. |
| D06 | Discussion: actual entry plus Macro duration; separate deadline, observation and actual close. | Use raw broker milliseconds; retain time exits and censors without fabricated TP/SL labels. |
| D07 | Discussion: offset/limit belong to backend research, with defaults 0/0. | No MQL5 quota or filtering of exports based on node settings. |
| D08 | User: previous handoff is already in use and complete. | Publish a distinct incremental handoff; preserve dated evidence and existing consumer work. |
| D09 | User's plan request: one-to-three-year validation is sufficient as needed. | Default to one representative year per engine; no mandatory full-history rerun. |
| D10 | User: avoid repeated LLM calls while slow background work runs. | Native job orchestration/waiting owns progress checks; no model-driven status polling loop. |
| D11 | Planning was initially plan-only; superseded by the user's explicit request to execute all sprints. | Execute this plan in order, validate and commit each sprint before advancing. |

Required product decisions pending: **none**. Operational prerequisites are gates
to verify during authorized execution, not claims of available/running services.

D01/D02/D05 explicitly replace the previous entry-distance and Pivot no-expiry
behavior for the new profiles. All unrelated project boundaries remain in force.

Routine technical choices for this plan:

- Preserve current public input groups, lot sizing, ATR/pivot geometry, feature
  definitions, causal source bars, eight Pivot lane declarations and capacities.
- Use explicit new engine/outcome identities and ownership namespaces; retain
  old reader profiles. Proposed release numbering is EA `2.10` for both engines.
- Reuse current fields and exact ten-/eleven-file schema-1 layouts. Profile
  metadata, rather than new generic columns, declares the fixed admission rule.
- Macro duration means the native `PeriodSeconds(Macro_Timeframe)` value already
  exported as `macro_seconds`. It is elapsed broker time, including quote gaps,
  not trading-session minutes or a move to the next candle boundary.
- Retain Pivot's supported timeframe set, including MN1; for MN1 use its native
  fixed duration, not calendar-month arithmetic. Candle still excludes MN1.
  The current shared reader omits MN1 despite Pivot accepting it: add explicit
  new-Pivot-profile handling and tests, without weakening old-profile checks.

## 3. Exact Behavior Contract

### 3.1 Entry admission

From one validated current quote/specification snapshot, in price units:

```text
spread = Ask - Bid
broker_distance = max(stops_level_points, freeze_level_points) * point
minimum_risk = 3 * spread + broker_distance + trade_tick_size
buy_risk = Ask - normalized_SL
sell_risk = normalized_SL - Bid
admit when directional_risk >= minimum_risk
```

Validate finite prices, `Ask >= Bid > 0`, positive point/tick size and nonnegative
broker levels before evaluating the inequality. Declare one consistent, tiny
floating-point comparison tolerance tied to trade tick size; test below/equal/
above boundaries independently. Apply the formula to the existing normalized
stop; do not move the SL or recompute an alternate strategy to pass the gate.
Existing geometry, TP distance, session, permission, volume, margin, FOK and
`OrderCheck` requirements remain independently necessary.

The execution path checks a fresh quote immediately before submitting an entry;
virtual paths check their own actual entry quote. A midpoint uses its touch
quote. Original/re-entry attempts are separate. Different observation/send/touch
quotes may legitimately yield different admissions; preserve those quotes and
reasons rather than forcing agreement using stale prices. A fill deviation after
an accepted request does not retroactively fail the gate or trigger another close.

Use a pure helper under `services/utils/broker_constraints_helper.mqh`; it cannot
read export readiness or mutate research state. Do not apply this entry-quality
gate to expiry close requests. A failed entry keeps its audit facts and is not an
entered trade, a loss or an offset/limit slot. Pivot identities remain consumed
after rejection; no spread-driven retry of a consumed origin is introduced.

Every accepted broker entry still owns exactly one submitted-geometry parity
shadow. Parity cannot be lost because an independent virtual quote failed the
gate; it remains excluded from target cohorts.

### 3.2 Pivot lifecycle and close ownership

```text
broker_deadline_msc = confirmed_broker_fill_msc + macro_seconds * 1000
virtual_deadline_msc = actual_virtual_entry_msc + macro_seconds * 1000
```

- Use actual confirmed broker entry facts, not discovery/request time, for the
  real position. Export any provisional request deadline distinctly through the
  existing trial/outcome distinction; never overwrite an immutable row.
- Each entered structural or midpoint lane has its own clock. An already entered
  midpoint can outlive structural lanes. Untouched midpoints become NOT_TRIGGERED
  once no structural lane survives; expiry transitions precede new touch/discovery
  processing at the same callback.
- Before the deadline, preserve existing causal TP/SL processing. At/after the
  deadline, unresolved virtual lanes record TIME_EXIT at the first valid observed
  exit-side quote. Do not invent a quote at the exact deadline. Candle keeps its
  existing deadline precedence; same-millisecond and quote-gap behavior is tested.
- Broker reconciliation consumes actual deal facts first. A broker close before
  the deadline can be TP/SL; a completed close at/after it is TIME_EXIT under the
  new horizon policy, with the actual native broker reason retained separately.
- Expiry requests close only the exact owned position ticket/identifier and its
  remaining volume using the opposing market direction, fresh quote, permissions,
  session checks and OrderCheck. SL/TP prices remain immutable.
- One close request may be in flight per position. Check retcodes and reconcile
  transactions/history before retrying; OrderSend success alone is not a fill.
  Retry confirmed refusals no more than once per broker second. Use the existing
  Candle 30-second unresolved-request diagnostic as the bounded reference, not a
  timeout that forgets ownership or permits duplicate requests.
- Freeze/session refusal, missing quotes, uncertain submission and unexpected
  partial execution retain ownership and explicit diagnostics. Do not mark CLOSED
  without verified full-close facts or fabricate a successful exit at the deadline.
- Tick, timer and transaction callbacks must not duplicate entries or closes.
  Add a one-second Pivot timer using the Candle lifecycle pattern; timers reconcile
  and attempt overdue closes without discovery, feature recapture or synthetic
  market timestamps. Initialize/release it safely on all paths.
- Reconcile expiry even with export disabled or failed. Shared capture/export
  never initiates, authorizes or blocks a close. Preserve startup refusal/adoption
  rules and the rule against touching older-engine positions.
- Parity keeps its original request quote/geometry and entry clock, with its own
  corresponding deadline. Do not move its clock to the later actual broker fill;
  submitted and realized timing remain auditable calibration facts.
- Run termination before resolution remains CENSORED_RUN_END, with null completed
  exit/duration/return. No-touch and invalid entries also retain their existing
  non-completed states. TIME_EXIT retains observed price/return and null binary
  TP/SL label. Unknown virtual costs/net remain null.

### 3.3 Version and export contract

| Producer profile | EA version | Outcome policy | Admission / expiry |
| --- | --- | --- | --- |
| Retained `PIVOT_MACRO_V1` | `2.00` | `PIVOT_MACRO_OUTCOME_V1` | Original research minimum / NONE |
| Retained `CANDLE_PATTERN_ATR_V2` | `2.00` | `CANDLE_ATR_OUTCOME_V1` | Original ATR/broker checks / ENTRY_PLUS_MACRO |
| New `PIVOT_MACRO_V2` | `2.10` | `PIVOT_MACRO_OUTCOME_V2` | SPREAD_3_STOPS_FREEZE_TICK_V1 / ENTRY_PLUS_MACRO |
| New `CANDLE_PATTERN_ATR_V3` | `2.10` | `CANDLE_ATR_OUTCOME_V2` | SPREAD_3_STOPS_FREEZE_TICK_V1 / ENTRY_PLUS_MACRO |

Keep family `MQL5_MODEL_FEATURES`, core schema `1`, extension schema `1`, current
ordered headers, file sets and storage root. The existing quote, risk, broker-level,
minimum-distance, eligibility, execution-check, deadline and outcome fields can
represent this work. New profiles require the applicable previously nullable
facts; historical profiles retain their original nullability/meaning.

Move producer-version/engine-specific manifest expectations out of the current
global `producer_version=2.00` check into explicit registered profile policy.
Keep engine/profile dispatch exact; an unknown engine must not fall through to
Pivot behavior. Add machine-readable policy identifiers, coefficients, required
fields and supported durations to the generated consumer profile descriptor.
Manifest engine/outcome identity and config fingerprint bind the fixed rule;
do not silently add unregistered manifest keys or infer policy from schema `1`.

Populate entry quote/specification/minimum-risk facts consistently for new Candle
and Pivot trials; retain actual request checks and immutable fill facts separately.
Broker rejection and virtual INELIGIBLE_DISTANCE stay separate from outcomes of
entered trades. Missing quote/specification facts remain explicitly unavailable,
not zero or invented success. Close checks distinguish expiry requests and their
reconciliation. Counts/seals still cover every required audit row.

Use new symbol-scoped ownership identities `HFT_GRID_AI_PIVOT_MACRO_V2` and
`HFT_GRID_AI_CANDLE_PATTERN_ATR_V3`, preserving stable hashing and explicit position
identity checks. Any changed wire field discovered to be indispensable requires
a documented schema-version adjustment before implementation of that field;
never change a schema-1 header in place.

## 4. Named Resources, Prerequisites And Evidence

### Source and document owners

| Responsibility | Exact owners |
| --- | --- |
| Entrypoints, timer and release identity | `Pivot_Macro.mq5`, `Candle_Pattern_Discovery.mq5` |
| Shared pure admission calculation | `services/utils/broker_constraints_helper.mqh` |
| Candle execution and export | `services/candle_pattern/{config,state,broker,engine,dataset_adapter}.mqh` |
| Pivot broker state/check/send/reconciliation | `services/trading_signals/{pivot_signal_struct,execution_broker_context,execution_controller,execution_broker_reconciliation,pivot_signal_lifecycle}.mqh` |
| New bounded Pivot close helper | `services/trading_signals/pivot_broker_expiry.mqh` (new), included once by `services/trading_signals.mqh` |
| Pivot virtual state, terminal enum and export | `services/core/enums.mqh`, `services/trading_signals/{pivot_trial_matrix_struct,pivot_trial_matrix_state,pivot_trial_matrix_geometry,pivot_trial_matrix_lifecycle,pivot_dataset_adapter}.mqh` |
| Shared descriptor, writer and capture | `tools/model_dataset/schema_contract.py`, `services/model_features/{schema,types,export}.mqh`, `services/model_features.mqh` |
| Strict reader and semantic policies | `tools/model_dataset/reader.py`, `tools/model_dataset/semantics.py`, `tools/model_dataset/engines/{pivot,candle}.py` |
| Existing Python test owners | `tools/model_dataset/tests/{fixtures,test_contract,test_extensions,test_pivot,test_candle,test_clock,test_features}.py` |
| Runtime/dataset contracts | `docs/architecture/market-data-broker-executor.md`, `docs/architecture/model-feature-dataset.md` |
| Current status and procedures | `docs/README.md`, `docs/environment/mt5-agentic-workflows.md`, `tools/model_dataset/README.md`, `AGENTS.md` |
| Existing complete producer handoff | `docs/research/model-feature-producer-handoff.md` (preserve dated pins; add navigation to the new supplement) |
| New incremental deliverable | `docs/research/entry-quality-lifecycle-backend-handoff.md` (new; producer changes and downstream requirements only) |
| Private implementation evidence | `.codex-artifacts/entry-quality-lifecycle/s1/` through `s5/`; no artifacts inside sealed run directories |

The frontend remains read-only; do not expand chart/UI scope. Review enum/reference
consumers under `services/frontend/` if a new terminal status affects existing
rendering. No new module may introduce sibling re-includes or include cycles.

Prerequisites before authorized execution:

- Recheck branch/status, actual source/EX5 hashes and absence of another writer.
  Stop on unexpected changes in this checkout. The backend has known concurrent
  edits and remains read-only; its inspected source is context, not a frozen
  implementation target or evidence of deployed compatibility.
- Retain matching old sources/binaries privately before source changes. Never
  overwrite a binary used by an operator's active tester; identify exact owned
  jobs and require an idle tester for new workloads.
- Verify existing `.venv/bin/python`, retained source history and native tool
  capabilities. Use existing environments/helpers; no dependency installation
  is required by this plan. Preserve all credentials and private run contents.
- At implementation handoff, read Planner `references/execution-state.md` relative
  to the installed skill and initialize its normal active-plan state once. That
  state is not initialized by saving this plan.

### Guidance, graph and tools

- Reuse the discussion metadata search `backend data validation ingestion pipeline
  architecture time series research`, limit 5, library revision
  `4b57740b1048475aeb21d9adfc9ecea0affa97b7`. Selected
  `data-engineering-data-pipeline` for bounded ingestion, immutable lineage and
  measured validation. No suggested framework/setup is adopted.
- Planning-specific MQL5 search: `MQL5 expert advisor trade execution position expiry
  lifecycle`, limit 5 at the same revision. No fit: results concerned Odoo, ITIL,
  customs, competitor pages and legal advice. No bundle was read; use project
  source/contracts and official MQL5 references for this concern.
- Reuse performance guidance selected by the archived runtime plan:
  `performance-profiling`, same library revision, query `profiling performance
  optimization memory growth CPU IO bottleneck benchmarking`; retained receipts
  are `.codex-artifacts/model-runtime-optimization/discovery/skill-search.json`
  and `skill-selected.json`. Only measurement principles apply; no browser tools.
- Understand-Anything `services` graph is fresh at planning source: 44 files,
  zero omitted, file-only MQL5 coverage, zero parsed edges. Artifact:
  `/home/admin/.cache/codex-skill-stack/graphs/3b77e337ea639ce9e6fedf5192c979f3d2adf8f78a5fc3a065a977215d95ff6c/knowledge-graph.json`.
  Adapter revision `6df3065f1d8ddc2ce3615314d1d493f36d6b1c80`. Manual aggregator,
  callback, execution and reader tracing supplies behavioral evidence.
- The discussion backend graph covered `backend/apps/datasets/services`: 32 parsed
  files, 407 nodes, 375 edges, zero omitted; partial scope with 427 unresolved
  imports. Artifact:
  `/home/admin/.cache/codex-skill-stack/graphs/2f8d0f4904a0aff70c049806fcc4e2c33cd4d312706461378dbc54845fad6b13/knowledge-graph.json`.
  Same adapter revision; source confirmed bounded COPY/reconciliation and entry
  derivation. Recheck freshness only if further backend inspection is needed.
- Consulted installed plugin `references/project-mcp-routing.md` and the project
  runbook. Prefer local Git/source; no GitHub writes or backend runtime queries.
  Terminal tools currently expose workspace discovery, backtest/status/wait/report/
  stop. MetaEditor compile tools were not exposed in the planning catalog: discover
  again during execution, call `get_workspace_info` before `compile_file`, and use
  the documented native compiler fallback only if MCP cannot execute, recording why.
- Native tester/compile, Python semantic suites and performance jobs were **not
  run during planning**. Historical passing results are references, not acceptance
  for changed behavior. Current planning verification covers this document only.

Official references consulted for the behavior/design:

- [Spread, stop and freeze distances](https://www.mql5.com/en/book/automation/symbols/symbols_spreads_levels): quote side and distinct broker restrictions.
- [PeriodSeconds](https://www.mql5.com/en/docs/common/periodseconds): native duration.
- [OrderSend](https://www.mql5.com/en/docs/trading/ordersend): retcodes and asynchronous execution confirmation.
- [MqlTradeRequest](https://www.mql5.com/en/docs/constants/structures/mqltraderequest): explicit position identity for hedging closes.
- [OnTimer](https://www.mql5.com/en/docs/event_handlers/ontimer): lifecycle and tester cost of timer events.

## 5. Shared Validation And Execution Rules

### V1: Source, contract and Python checks

Run affected existing checks once per changed input set. Do not rerun an unchanged
gate merely because another sprint references its receipt.

```bash
rtk git status
git diff --check
rg -n 'PIVOT_MACRO_V[12]|CANDLE_PATTERN_ATR_V[23]|PIVOT_MACRO_OUTCOME_V[12]|CANDLE_ATR_OUTCOME_V[12]|ENTRY_PLUS_MACRO|SPREAD_3_STOPS_FREEZE_TICK_V1' Pivot_Macro.mq5 Candle_Pattern_Discovery.mq5 services tools/model_dataset docs AGENTS.md
rg -n 'OrderSend|TRADE_ACTION_SLTP|CalculateStrictRiskDistancePoints|OnTimer|EventSetTimer|EventKillTimer|TIME_EXIT' Pivot_Macro.mq5 Candle_Pattern_Discovery.mq5 services
.venv/bin/python -m tools.model_dataset.schema_contract --check-mql-header services/model_features/schema.mqh
rtk test .venv/bin/python -m unittest discover -s tools/model_dataset/tests -t . -p 'test_*.py'
```

The sweeps require review, not zero matches: preserve intentional historical
identities. Trace exact include reachability and new enum consumers; review
broker/research ownership and bounded loops each sprint. Run the existing legacy
Candle/Pivot suites only if their inputs/readers/fixtures are affected; otherwise
reuse their unchanged evidence. Do not create tests that merely mirror the helper:
use independent boundary arithmetic and malformed/contradictory exported facts.

Regenerate the schema header/consumer JSON only from its descriptor when changed.
Check all live relative links/anchors, version references, ignored artifact paths
and AGENTS limits (160 lines / 8 KiB). Stage only reviewed paths.

### V2: Compile and native behavior

Compile changed source closures through the discovered MetaEditor MCP, optimized
AVX2 as currently selected. Require `0 errors, 0 warnings` and newly generated
EX5 mtime/size/SHA-256. Shared changes compile both EAs. Reuse a passing compile
only while its full source/include/compiler inputs remain unchanged.

Native cases use the actual EAs and existing tester facilities, fresh run IDs,
Every tick based on real ticks, fixed source/specifications, file logs off and
explicit settings. Start with H1/M3 gold and cover H2/H4 plus one short Macro
case for expiry, buy/sell, partial readiness and both clock policies/seasonal
boundaries. Reuse current gold/FX samples if still available; no new data download
or source-history repair is included.

- Exact equality is required for same-build repeated exports (normalize only run
  identity), same-build export-on/off broker orders/deals/statistics, untouched
  profile behavior and feature values at genuinely identical observations.
- Old-vs-new orders/outcomes intentionally differ. Explain differences through
  the new gate, expiry or their causal downstream consequences; do not demand
  byte-identical whole datasets or hide differences behind a blanket exception.
- Independently check below/equal/above admission thresholds, zero spread, tick
  size different from point, invalid quote/specification, originals/re-entries,
  midpoint touch and request-to-fill deviation. Rejection consumes no entry slot.
- Check TP/SL before deadline, exact deadline, just after, sparse quotes/weekends,
  actual fill after request, already-closed positions, duplicate callbacks,
  close refusal/in-flight uncertainty and run-end censoring. Verify new engine
  ownership and exact accepted-request parity without acting on real accounts.
- Use focused native cases where the feed exposes a boundary; deterministic
  Python fixtures cover exact/unavailable cases. Record missing native scenarios
  as unrun, never as passed. No new MQL5 fault harness is permitted.
- Strictly read every retained acceptance dataset with the registered profile:
  `.venv/bin/python -m tools.model_dataset.reader <run_dir> --report <external_receipt>`.
  Bind reports to exact file hashes and source/binary pins.
- Preserve writer fault checks on disposable runs, final-seal refusal, reused-ID
  protection, feature-gap behavior and first-failure diagnostics. Dataset failures
  do not transfer broker ownership to research.

Positive execution delay remains a legitimate simulation mode. The existing
contract records a Candle delayed-close observation limitation. Use zero delay
for the principal strict matrix and a focused nonzero-delay reconciliation case
for the new close path. Record any inherited clock limitation without falsifying
times or relaxing the reader; repair a changed path's close/observation defect
before claiming that case passes. No broad latency campaign is required.

### V3: Representative generation and efficiency

1. Pin baseline/final build, source, symbol/specification, real ticks, periods,
   execution delay, lot/account tester settings, visual/export flags and warmup.
   Reuse the retained gold source `XAUUSD_Exness_2015` after checking coverage.
2. Use one warmup and three alternating baseline/final pairs on one week and one
   month per affected engine. Separate native elapsed time from tool wait and
   report startup/preprocessing where available; exclude instrumented builds.
3. After focused gates pass, run one representative continuous year per final
   engine, initially `2015-08-10` to `2016-08-10` end-exclusive, subject to verified
   history and startup warmup. Record effective coverage, not just requested dates.
   Reuse a matching baseline receipt only if source/spec/settings/build pins match;
   otherwise run the corresponding isolated baseline year once.
4. Verify natural seal, exact counts, strict semantics, clocks, representative
   independent feature values, state reuse, buffers/handles and owned-order facts.
   Measure ticks, captures, entered/active lanes, expiries, rows/bytes, CPU, RSS/HWM,
   file descriptors, writer activity, generation time and separate reader time.
5. Inspect early/late samples and matched dense periods. Explain changes in cost
   per tick/capture/active lane/byte; fewer admitted trades or shorter lifecycles
   alone do not prove an algorithmic speedup. Preserve 2048 Pivot active/parity,
   2048 Candle broker/6144 virtual, 4096/256 structure and 256-row/1-MiB writer caps.
6. An unexplained regression above 5% outside observed variation blocks promotion.
   Attribute timer overhead and new necessary work before optimizing. Improvements
   below 5%/within noise are inconclusive; do not promise a speedup for new behavior.
7. Extend the affected engine to two or three years only if one year leaves a
   documented state-growth, resource, dense-feed or coverage concern that the longer
   interval can resolve. Do not automatically repeat all passing checks or both
   engines. Escalation beyond three years requires new scope.

There is no fixed twenty-minute target. Passing establishes correctness and
measured efficiency for tested intervals; it does not certify ten-year speed,
live broker equivalence or absence of every possible long-run leak.

### V4: Slow-job and token discipline

- Launch each tester/validator workload once. Persist exact job/PID, run ID,
  config/source/binary hashes, start time, paths and phase before waiting.
- Use the existing native tester waiter or a single native orchestration loop
  for waiting, resource checks and process sampling. Keep individual waits at
  45-60 seconds or less. The loop, not repeated LLM turns, decides whether another
  wait is needed. Emit compact progress notifications directly when supported.
- Do not use repeated model calls, agents, screenshots, searches or duplicate
  status/report reads merely to fill waiting time. Independent planned work may
  continue. Inspect completion evidence once, or earlier only for a meaningful
  failure/guard event or user steering.
- Reuse the pattern in the ignored runtime `s5/guarded-run-reference.js`, adapting
  it only in new ignored evidence. Do not re-enable the archived automatic queue
  or retain its per-wait yield-to-model behavior. If host transport forces a yield,
  resume the same native job; never use that yield to relaunch work.
- If unattended completion cannot be delivered without repeated model polling,
  retain a durable running-job handoff and wait for its completion event/operator
  return. The sprint gate stays open; no invented completion or duplicate run.
- One tester workload at a time. Before launch declare disk budget from measured
  bytes/year (at least 10 GiB or twice estimated new-output size, whichever is
  larger), at least 1.5 GiB available memory, a wall guard derived from short-run
  throughput with at least 5x headroom, and a 300-second genuine-progress stall
  guard. Store concrete limits in the case receipt. Stop only the exact owned job;
  preserve partial files and reason. A tool wait timeout is not a test failure.
- Reuse valid evidence while inputs remain unchanged. A new failure/change permits
  the smallest justified rerun. Keep raw logs private and return compact results.

## 6. Ordered Sprints

Every sprint follows one gate: complete its tasks, run affected V1/V2 checks and
specified additional validation, retain failures/unrun gates honestly, create
exactly one sprint-specific commit, record its parent and matching binary/data
rollback receipt, then advance. No amend/rebase/history rewrite. Record the actual
pre-sprint parent at execution, rather than assuming today's HEAD remains current.

### Sprint 1: Register Versioned Contracts And Preserve The Baseline

**Goal:** A strict reader/descriptor supports old and proposed new profiles while
both existing producers remain behaviorally unchanged.

**Dependencies:** Execution authorization and prerequisites.

**Commit:** `feat(dataset): register versioned entry-quality and expiry contracts`

**Task 1.1 — Baseline and contract freeze**

- Owners: current runtime/dataset contracts, `docs/README.md`, private `s1/`.
- Pin source closures, old EX5, current tests and available baseline datasets;
  capture fresh short baselines only where retained evidence cannot be reused.
- Write the exact formula, new profile table, deadline precedence, ownership,
  rejected/entered grains and field-requirement map into existing contract owners.
- Acceptance: every changed semantic has a versioned owner and an independent
  positive/negative acceptance case; no old run or dated receipt is relabeled.
- Validation: V1, descriptor review and baseline pin verification.

**Task 1.2 — Reader, generated descriptors and compatibility**

- Owners: `schema_contract.py`, `reader.py`, `semantics.py`, `engines/`, shared
  generated schema/export profile selection, existing shared Python tests.
- Add exact new profiles, per-profile producer expectations, engine-kind dispatch,
  policy metadata and new-Pivot native-duration support. Remove hard-coded
  old-engine equality/fallback assumptions only where these profiles require it.
- Extend fixtures with independent spread-boundary, deadline and malformed-policy
  facts. Preserve old fixture meanings and old profile behavior. Unknown/mixed
  tuples, false eligibility, incomplete required evidence and fake timeout prices fail.
- Acceptance: old profiles still validate; new synthetic profiles validate only
  under their own semantics; core headers/file sets remain unchanged.
- Validation: V1 and synthetic positive/negative cases; V2 if generated/shared
  MQL includes change. Current producer manifests and native behavior stay old.

**Task 1.3 — Ready incremental gate**

- Verify source changes do not switch an EA to an incompletely implemented policy.
  Store machine-readable consumer descriptor and rollback pins under private `s1/`.
- Acceptance: runnable current EAs plus a usable new strict contract; exact old
  native checks are reused or rerun according to closure changes.
- Describe new policies as pending producer integration until S2/S3 switches each
  engine; the current index must continue to identify the actually implemented build.
- Rollback: revert this sprint; restore matching old binaries if recompiled.

**Sprint 1 gate:** tasks/checks pass; one commit and parent recorded; S2 not started.

### Sprint 2: Enforce Candle Admission And Export Complete Entry Facts

**Goal:** Candle `2.10` / `CANDLE_PATTERN_ATR_V3` enforces the fixed gate while
retaining its existing ATR, directions, confirmed-SL re-entry and expiry behavior.

**Dependencies:** Sprint 1 committed.

**Commit:** `feat(candle): enforce spread-aware entry admission and audit facts`

**Task 2.1 — Shared pure helper and Candle entry integration**

- Owners: broker constraint helper, Candle `broker/config/state`, entrypoint/includes.
- Implement the fixed pure calculation and call it from fresh original/re-entry
  entry decisions and virtual construction. Preserve existing legal stop/TP checks,
  volume, margin and request checks. Existing Pivot's old helper behavior remains
  unchanged until S3; do not silently tighten its old research profile.
- Switch Candle release/engine/ownership only with its complete new behavior.
  Update affected current version/policy guidance with that switch; S5 consolidates
  the delivery rather than leaving knowingly stale runtime instructions meanwhile.
- Acceptance: failed admission sends no entry and activates no corresponding
  virtual lane; valid accepted requests retain parity. No spread check blocks a close.
- Validation: independent Python boundaries, both-EA compile, short Candle native
  buy/sell/original/re-entry cases and exact current-Pivot regression.

**Task 2.2 — Candle audit, local invariants and failure behavior**

- Owners: Candle `dataset_adapter/engine/state`, shared typed writer only as needed,
  `engines/candle.py`, existing Candle/shared contract tests.
- Fill required fresh quote, point/tick, stops/freeze, risk/minimum/eligibility facts;
  preserve request/fill distinctions and rejection reasons. Check new facts once
  at transition/serialization, using active state rather than historical scans.
- Acceptance: strict new-profile intake, old-profile compatibility, exact export-on/
  off broker facts, no fabricated values, unchanged Candle lifecycle rules.
- Validation: V1/V2, representative expiry and rejection datasets, partial feature
  readiness, disposable export failure and close-ownership review.
- Rollback: revert S2 and restore S1 Candle binary; never reinterpret new-profile runs.

**Sprint 2 gate:** Candle and affected shared/Pivot checks pass; one commit/parent
recorded; S3 not started. Any unavailable native scenario is explicitly retained.

### Sprint 3: Add Pivot Admission And Execution-Owned Expiry

**Goal:** Pivot `2.10` / `PIVOT_MACRO_V2` delivers both new policies together; no
intermediate producer claims expiry it does not implement.

**Dependencies:** Sprint 2 committed.

**Commit:** `feat(pivot): enforce entry quality and per-entry Macro expiry`

**Task 3.1 — Pivot admission and versioned ownership**

- Owners: entrypoint, execution check/controller/state, trial geometry/lifecycle,
  dataset adapter and existing pure helper.
- Recheck the fixed gate at fresh broker send and each virtual activation; retain
  final origin consumption and independent midpoint quote semantics. Export the
  specific rejection evidence. Switch profile/magic/comment identity atomically
  with tasks 3.2/3.3; prove no older-engine position is adopted or modified.
  Update affected current version/policy guidance in the same sprint.
- Acceptance: no unauthorized entry, no quota input, unchanged structural stops,
  exact accepted-request parity and explicit broker/virtual admission differences.
- Validation: V1, rejection/acceptance edge cases, native fresh-quote audit.

**Task 3.2 — Broker expiry state and callback integration**

- Owners: `pivot_signal_struct.mqh`, new `pivot_broker_expiry.mqh`, reconciliation,
  lifecycle, `services/trading_signals.mqh`, `Pivot_Macro.mq5`.
- Add confirmed-fill deadline, pending close identity, bounded retry and uncertainty
  state, updating every Reset/CopyFrom path. Reconcile actual closes before sending;
  preserve exact position ownership until closure is proved.
- Wire one-second timer initialization/deinitialization and tick/transaction
  lifecycle ordering. Preserve broker processing when research is unavailable.
- Acceptance: no premature/duplicate close or opposite new position; no synthetic
  close clock; unresolved requests remain owned; original SL/TP stay immutable.
- Validation: V1/V2; owned-position ticket checks, expiry/no-quote/refusal/duplicate
  callback cases and actual native close/retcode reconciliation. Review include order.

**Task 3.3 — Virtual expiry, terminal export and parity**

- Owners: terminal enums, trial structs/state/lifecycle, dataset adapter, strict
  Pivot validator and existing tests; inspect frontend enum consumers.
- Add distinct TIME_EXIT resolution with entry-specific milliseconds, observed
  exit quote/price R, null binary label, and correct pending-midpoint finalization.
  Export actual broker deadline/close/reason separately from submitted parity facts.
- Acceptance: structural expiry before new discovery/touch, already-entered
  midpoint continuation until its own deadline, no-touch/censors stay non-losses,
  no capacity or per-tick state-copy regression.
- Validation: V1/V2 for both engines, fixed-duration/monthly reader cases,
  before/equal/after deadline and run-end fixtures, strict native outputs,
  export-on/off exact broker results and sample independent feature checks.
- Rollback: revert the whole S3 commit and restore S2 Pivot binary; never deploy
  rollback over open new-engine positions or rewrite its generated datasets.

**Sprint 3 gate:** both engines compile cleanly and all required focused behavior
checks pass; one commit/parent recorded; S4 not started.

### Sprint 4: Validate Generation Quality And Representative Efficiency

**Goal:** Accepted final outputs and measured one-year evidence for both engines,
with only evidence-driven hardening/optimization.

**Dependencies:** Sprint 3 committed and focused gates passing.

**Commit:** `perf(models): validate bounded generation and harden lifecycle checks`

**Task 4.1 — Complete integrity and boundary coverage**

- Owners: affected existing source/test owners from S2/S3, shared `types/export`
  only for concrete missing cheap invariants, runbook and private `s4/` receipts.
- Complete V1/V2 matrix, exact-repeat/prefix checks, both clock policies, writer
  failure/reused-ID checks and deadline/admission coverage. Any producer check is
  constant/bounded per active transition or emitted row; no full-history container.
- Acceptance: no broadened broker/research authority, strict whole-run semantic
  validation and truthful rejection/censor/timeout counts for both engines.
- Validation: V1/V2; rerun only cases invalidated by a fix.

**Task 4.2 — One-year quality/performance and conditional extension**

- Owners: runbook, existing tester/reader operations, private `s4/` native receipts.
- Execute V3 using V4 native waits. Preserve generation and strict-reader timing
  separately. Attribute behavior-driven workload changes; optimize only measured
  unnecessary work while retaining newly accepted semantics.
- Acceptance: both final one-year datasets naturally seal and pass strict intake;
  no unexplained material regression or unresolved application-state growth.
  Record why any two-/three-year extension was needed or why one year sufficed.
- Validation: exact source/build/settings/source hashes, native reports, complete
  dataset counts/hashes, scoped resource/timing receipts; report coverage limits.
- Rollback: revert S4 source changes, if any, restore S3 binaries; keep all evidence
  and failed source runs. A documentation-only S4 still commits its measured results.

**Sprint 4 gate:** required generation/quality checks pass, residual performance
limits are explicit, one commit/parent recorded; S5 not started.

### Sprint 5: Publish The Incremental Backend Handoff

**Goal:** A backend maintainer can implement intake and selection from one precise
incremental handoff without reconstructing this conversation.

**Dependencies:** Sprint 4 committed and final producer evidence available.

**Commit:** `docs(research): publish entry-quality and lifecycle backend handoff`

**Task 5.1 — Versioned producer delivery and examples**

- Owners: new `docs/research/entry-quality-lifecycle-backend-handoff.md`, existing
  producer handoff navigation, runtime/dataset contracts, tools README and `s5/`.
- Publish source/EX5/profile pins, generated JSON descriptor, exact field mapping,
  formula/unit/tolerance, request/fill/deadline semantics and historical compatibility.
  Bundle tiny valid/invalid synthetic examples using existing fixtures and retained
  native acceptance run receipts, with checksums outside sealed source directories.
- Acceptance: new and old policy identities cannot be confused; no consumer
  compatibility, backend performance or live acceptance is claimed without evidence.
- Validation: regenerate/check descriptor, validate example datasets and verify
  delivered source/binary/run hashes. Reuse S4 checks while their inputs remain valid.

**Task 5.2 — Backend selection and WFO requirements**

- Record the complete downstream contract in section 7 below, exact examples and
  acceptance cases. Re-read current backend owners before naming changed modules;
  its concurrent optimization work is not reverted, duplicated or frozen by this plan.
- Acceptance: node-specific filtering/order/grain, daily reset, cutoff handling,
  immutable identities, audit counts and versioned intake are unambiguous. Backend
  implementation/tests remain explicitly owned by its later authorized plan.
- Validation: contract review against examples and known backend subset-proof
  constraints; no backend runtime writes or services started.

**Task 5.3 — Status, limitations and closeout**

- Owners: `docs/README.md`, `AGENTS.md`, runbook, existing doc owners and this plan.
- Update current versions and authorized entry/expiry boundaries concisely; preserve
  dated facts, completed old handoff and broker/feed/recovery/operator gates. Publish
  tested one-/two-/three-year coverage and the native waiting/evidence reuse rules.
- Acceptance: links/anchors and ignored artifacts are valid; no contradictory old
  policy is presented as current. Human tester/chart acceptance remains explicit;
  existing deferred Candle visual polish is not silently added to this task.
- Provide concrete native cases/reports for the human review of new behavior.
  Automated implementation and handoff delivery may be reported separately, but
  full behavior acceptance remains pending until that review passes or the user
  explicitly defers it. Do not infer a new deferral from the old visual-polish decision.
- Validation: document/static gates, source/include/schema hashes unchanged since
  the accepted final build. No recompile or long-run repeat for prose-only updates.
- Rollback: revert S5 documentation only; retain handoff receipts and actual pins.

**Sprint 5 gate:** handoff/examples/docs pass; one commit/parent recorded; final
execution handoff retains operator acceptance limits and exact rollback references.

## 7. Required Backend Handoff Content

The backend checkout is `/home/admin/python_projects/hft-grid-ai-orchestrator`.
It is read-only throughout this plan. Its root/backend AGENTS and then-current
contracts own any later implementation; the table below names inspected owners,
not permission to edit them or proof that their uncommitted changes are final.

| Backend concern | Inspected owner / required change |
| --- | --- |
| Intake versions, strict evidence and READY transition | `docs/contracts/model-feature-intake-v1.md`, `backend/apps/datasets/contracts/model_features_v1/`, `services/model_feature_intake.py`, `services/model_feature_validation.py`, `services/model_feature_projection.py` under `backend/apps/datasets/` |
| Daily window and membership | `backend/apps/research/analysis_window_contracts.py`, `backend/apps/research/services/analysis_window_contexts.py`, `docs/contracts/categorical-discovery-v1.md` |
| Discovery scoring and WFO | Current owners reachable from `backend/apps/research/services/model_discovery_evidence.py` and categorical/forward contracts; inspect current source before implementation |
| Useful historical first-N precedent | `docs/contracts/candle-pattern-discovery-v1.md` (native-Macro allowance differs from the new daily window rule) |

Mandatory downstream requirements:

1. `Trades_Offset >= 0`, `Trades_Limits >= 0`, defaults 0/0. In a daily window,
   keep ordinal `n` iff `n > offset` and `(limit == 0 or n <= offset + limit)`.
   No fixed maximum dataset size or invented finite meaning for limit zero.
2. Apply each node's full inherited+local entry-time predicates and declared
   entry category first, then number its eligible entered decisions. Same offset/
   limit settings are inherited down the path; depth changes the matching stream,
   not the parameter values. Never use outcome, duration, profit or eventual
   binary eligibility to decide entry membership or recycle a selected slot.
3. Use the existing analysis-clock policy for the half-open daily window (for
   example `[00:00,08:00)`) and its start-date label. Overnight windows belong to
   their start day. Raw entry milliseconds, producer sequence and stable identity
   determine order, including ties/DST folds. Counters reset per node/setup/day;
   no carryover or shared quota across unrelated symbols/directions/setups.
4. Count actual entered decisions, not each ratio row; group by dataset-qualified
   attempt plus entry-policy/touch identity as needed. Structural and midpoint
   entries retain distinct actual times; Candle original/re-entry parentage and
   direction category remain explicit. Preserve existing selected-parent strategy
   rules where applicable; observed-fill selection is not a counterfactual broker
   replay after skipped parents. Parity/rejections/unentered offers consume no slot.
5. Keep preselection membership/support and selected membership separately. A
   child is a subset of the parent's causal predicate universe, but its selected
   entries need not be a subset of the parent's already limited selection. Update
   the current subset proof and pruning assumptions accordingly; never prune solely
   because capped parent and child membership differ.
6. Example, offset 3/limit 2: parent matches `[1,2,3,4,5,6,7,8]` and selects `[4,5]`;
   child matches `[2,4,6,7,8]` and selects `[7,8]`. Repeat independently next day.
   Four matches yield only the fourth; three yield none. No backfill from later
   entries when a selected trade loses, times out or remains unresolved.
7. Bind parameters, ordering/reset/grain policy version, node path, engine/outcome
   tuple and cutoff to immutable research/WFO identities, membership digests and
   caches. Recompute each candidate from its complete eligible preselection stream.
   Preserve independent signal-root support instead of multiplying it by ratios.
8. TRAIN/TEST use the same causal selection policy. Freeze parameters with the
   training selection; do not tune them on TEST. Keep existing root-overlap and
   close/observation knowledge boundaries. Outcomes unavailable by a cutoff are
   excluded from that score without rewriting the earlier entry sequence. Window
   selection does not force exits at the window's end.
9. Report offered/rejected/entered/offset-skipped/limit-excluded/selected and
   TP/SL/time-exit/censored counts separately. TIME_EXIT has observed return but
   no binary TP/SL label. Censors have no fabricated completed return. Broker
   costs/net and unknown virtual costs remain separate.
10. Backend continues validating uploaded file identity, full contract/relationships,
    source hashes, stored data and READY publication. Producer checks/receipts are
    evidence, not permission to skip validation. Optimize measured stages and
    reuse only correctly bound checkpoints; do not duplicate ongoing backend work.

Include acceptance examples for 0/0, offset-only, limit-only, insufficient matches,
node depth changes, daily/overnight boundaries, entry vs discovery time, ties/DST,
re-entry parent rules, multiple ratios/parity, censored/time-exit slots and WFO
cutoffs. These are handoff criteria, not backend tests executed by this plan.

## 8. Risks, Rollback And Completion

| Risk | Mitigation and validation signal |
| --- | --- |
| Research accidentally controls broker entries/closes | Pure execution-owned helpers; export-on/off exact native broker comparison and failure-path review. |
| New gate changes sample counts or makes timing appear faster | Versioned policy and reason audits; report admission/workload counts and normalized costs. |
| Deadline close races with SL/TP or a pending request | Reconcile first, ticket-bound close, one request in flight, actual deal clocks and explicit native reason. |
| Timer overhead or state growth | One-second lifecycle-only timer, fixed active caps, no historical containers; early/late and one-year measurements. |
| Old datasets silently acquire new meaning | Exact profile/version dispatch, retained fixtures and negative mixed-profile tests; no data rewrite. |
| Quote gaps or unknown close price create fabricated results | Separate exact deadline from observed quote/fill; unresolved run end stays censored. |
| Backend child subset assumption breaks adaptive selection | Preserve preselection universe separately; concrete parent/child counterexample in handoff. |
| Slow job causes repeated inference or duplicate runs | V4 native orchestration, persistent identity, event-driven completion and no model polling loop. |
| Native failure scenario cannot be reproduced without prohibited harness | Keep deterministic reader coverage and source review; record native gate as unrun, do not invent evidence or add infrastructure. |
| Human/operational acceptance unavailable | Retain an explicit gate and artifact handoff; no live/deployment claim. |

Rollback uses normal revert commits in reverse dependency order, never amend/reset/
history rewrite. Each sprint records its real parent and corresponding binaries.
Keep new-profile datasets, failures and receipts immutable on rollback; historical
readers/producers are not used to reinterpret them. No rollback may abandon open
new-engine positions by adopting them into another version. Live rollout remains
outside this plan; any later rollout requires older positions flat, hedging, one
instance per account/symbol and the retained human/broker/feed acceptance gates.

Execution order is S1 -> S2 -> S3 -> S4 -> S5, with exactly one validated commit
per sprint before advancing. At authorized execution handoff, use the installed
Planner execution-state contract and record actual validations, rollback parents,
pending operational gates and next action. Execution state was initialized under
the user's subsequent all-sprint execution authorization.

Completion checklist:

- [ ] All five sprints passed their required automated gates and have one commit each.
- [ ] Both EAs compile with zero errors/warnings and matching source/EX5 receipts.
- [ ] New admission/expiry behavior, old-profile reads and export-on/off equivalence pass.
- [ ] Both final representative one-year datasets naturally seal and validate strictly.
- [ ] Any extension up to three years has a recorded reason; evidence limits are stated.
- [ ] Native background work used durable job identity and no model-driven polling loop.
- [ ] Incremental backend handoff and examples are complete; no backend execution is claimed.
- [ ] Human acceptance of new behavior passes, or an explicit user deferral is recorded
      with acceptance still pending. Other operational gates retain their prior scope;
      no live/deployment acceptance is implied by offline completion.
- [ ] Current status, version owners, links, ignored evidence and rollback pins are accurate.

## 9. Execution Evidence

### Sprint 1

- Rollback parent: `406a7d9a38c911d5bea5b640b3fc9ae5e06664cf`. Original 48
  tracked MQL sources and both EX5s retained in private `s1/baseline/` with hashes.
- New exact profiles and admission/expiry proof requirements registered; existing
  producers remain 2.00. Existing 76 tests passed before edits; 86 shared tests
  pass after the change. Generated schema check and whitespace check pass.
- Compiler MCP absent. Direct Wine argument quoting produced no log; a native
  command file with documented `/compile`, `/log` and `/avx2` succeeded. All four
  baseline/current builds: MetaEditor 6230, AVX2, zero errors/warnings, fresh EX5
  metadata. `s1/build.json` and compile logs are authoritative. Official flag
  reference: [MetaQuotes build 4230](https://www.metatrader5.com/en/releasenotes/terminal/2353).
- Terminal catalog excludes hidden artifact folders and caches CLI builds.
  Exact baseline copies in ignored `logs/eql-baseline/`, followed by Navigator
  Refresh, make the real EAs available to the tester. No chart EA was attached.
- Gold real ticks, H1/M3, zero delay, 2015-08-17..24: all four native exports pass
  strict intake. Each old-profile baseline/current pair has identical TSV bytes
  after run-ID normalization, ordered broker facts and report statistics.
  `s1/validation.json` binds counts; individual strict receipts bind all files.
- Source review: generated include reachability recorded in compile logs; no
  entry/close sites or engine selections changed. Exact profile dispatch replaces
  only legacy hard-coded manifest/reader assumptions. No legacy reader changed.
- Native waiter owns background checks; one workload at a time with durable job
  receipts. No model polling loop was used. Human new-behavior acceptance remains
  a later gate; Sprint 1 has no changed trading behavior.

### Sprint 2

- Rollback parent: `47556f9`; restore the corresponding S1 Candle EX5 on revert.
  Candle is now 2.10 / V3 with execution-owned fixed admission and complete trial/
  request proof; existing ATR, re-entry and deadline processing remain unchanged.
- Ownership uses new magic prefix `0x434e4433` and the bounded broker comment
  `CANDLE_PATTERN_ATR_V3`. The longer descriptive namespace need not be sent as
  a broker comment; magic and symbol establish ownership, never the old prefix.
- Both EAs compile on 6230 AVX2 with zero errors/warnings (`s2/build.json`).
  All 90 shared tests pass. An initial new fixture comparison incorrectly compared
  equivalent Decimal spellings as strings; numeric equality corrected it. The
  first 2-day M6 native case had no admitted entries and did not prove expiry.
- H1 week: 1,080 attempts, 15 broker admissions, 1,065 distance rejections;
  both directions and ten re-entry attempts are observed. Dense 2015-08-24..26
  M6/M3: 55 actual broker and parity time exits, 134 virtual time exits. All four
  retained datasets strictly validate. Export-on/off ordered broker results
  match; Pivot TSVs and broker results remain exact against S1.
- Independent native feature audits pass for Candle H1/M6 and Pivot regression.
  Partial feature readiness occurs without affecting execution. A disposable
  existing run ID is refused, its sentinel remains unchanged and the tester logs
  `RUN_ID_EXISTS`. Prior unchanged writer fault logic/evidence is retained.
- `s2/validation.json`, strict per-run receipts, `features.json` and `refusal.txt`
  hold counts/hashes. Include tracing and call-site review confirm the entry helper
  never participates in expiry closes; parity receives the submitted proof.
  Native invalid-specification, exact-equality and forced uncertain-send cases
  remain unavailable; deterministic reader cases/source review cover their stated
  invariants without claiming native injection. Human new-behavior acceptance is
  still pending; no deployment is included.
