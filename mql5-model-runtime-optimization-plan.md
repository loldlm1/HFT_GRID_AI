# Plan: MQL5 Model Runtime Optimization

- **Generated:** 2026-09-24
- **Status:** In progress - Sprint 2.
- **Execution authorization:** The user requested execution of all five sprints,
  including the planned validation and commit gates, on 2026-09-24. Earlier
  authorization to stop the current Candle tester if needed remains applicable.
- **Proposal:** Not requested; this is the follow-up to the completed
  [feature framework plan](mql5-model-feature-framework-plan.md).
- **Complexity:** High
- **Planning baseline:** `2292be7517201a41b8dde8b78e503f413c15eb31`, branch
  `bot/pivot_points_fractal`; clean tracked worktree at discovery.

## 1. Outcome And Scope

Identify and remove avoidable runtime cost in both existing engines while
preserving broker behavior and the common schema-1 dataset. Establish evidence
over growing history lengths and write performance requirements for future
engines using the shared services.

The user reports that Candle before the feature-framework refactor finished the
whole Exness history in less than ten minutes. The current run starts quickly
and slows as history advances. The ten-minute report is a reference to reproduce,
not a measured comparable baseline or an unconditional delivery promise.

- **In scope:** `Candle_Pattern_Discovery.mq5`, `Pivot_Macro.mq5`, their shared
  feature/export services, measured engine lifecycle costs, existing local
  validation, native tester/profiler evidence and developer documentation.
- **Out of scope:** Django, training or discovery pipelines, new strategies,
  dependencies/frameworks, live deployment, feed changes, public tuning inputs,
  new test EAs/scripts, CI or test infrastructure.
- **Fixed constraints:** No tick thinning, OHLC substitution, feature removal,
  changed shift/capture semantics, reduced broker checks or altered labels to
  obtain a faster result. Keep execution ATR ownership independent of research.
- **Assumption:** Optimize nonvisual real-tick dataset collection as the primary
  throughput workload; measure Visual mode separately and preserve its behavior.
  This does not change the operator's current tester settings.
- **Pending required decisions:** None for this plan. Earlier Visual/export/feed
  settings remain factual unknowns; Sprint 1 reconstructs controlled comparisons
  without assuming the user's partial answer established those settings.

### Decision record

| ID | Decision and authority | Consequence |
| --- | --- | --- |
| D01 | User requested review/planning, then explicitly authorized all five sprints on 2026-09-24. | Execute the ordered validation and commit gates for both engines and future-engine rules. |
| D02 | User clarifies that the under-ten-minute reference predates the refactor. | Retained Candle 1.02 at `5df19f1` is a reproducible candidate; do not assert it was the exact reported binary. |
| D03 | User permits stopping the current Candle run if needed. | A stop is permitted only after identifying that run; retain its incomplete output and disposition. |
| D04 | Accepted framework decisions remain authoritative. | Preserve Macro/Micro, M1 forming structure, clocks, zones, broker/virtual/parity and failure semantics. |
| D05 | Earlier explicit scope is MQL5 only; Django follows later. | Update the producer handoff for later consumers without opening or changing that repository. |
| D06 | Existing validation rules require matched settings, alternating repeats and gains above measurement noise. | Establish repeatable performance gates before promoting an optimization. |
| D07 | User selected Q01 option B, then clarified on 2026-09-25 that positive execution delay is an intentional market-simulation setting, not a blocker. | Keep this plan performance-only. Use zero-delay runs for strict dataset acceptance; retain delayed runs for matched performance and broker comparisons. The existing Candle close-observation export inconsistency is a documented limitation outside this plan, not a prohibition on positive delay or a sprint blocker. Preserve timestamps and the strict reader. |

## 2. Findings And Evidence

### Confirmed observations

1. **New shared work repeats across callbacks.** `ModelObserve` runs from Candle
   Tick, Timer and relevant TradeTransaction callbacks
   (`Candle_Pattern_Discovery.mq5:58`, `:72`, `:94`).
   `services/model_features/stochastic_structure.mqh:169` resets readiness and
   queries M1 `iTime`, `SERIES_FIRSTDATE` and `iBarShift` on ordinary observations,
   including observations without a new closed M1 bar. This is repeated cost;
   its contribution to progressive slowdown has not been profiled.
2. **Row construction repeatedly searches column names.**
   `services/model_features/types.mqh:116` performs a linear lookup for every
   assignment; `Clock` at line 136 also counts earlier clock fields. The feature
   table has 279 physical columns. Filling a row performs approximately
   quadratic lookup work in its width, unlike old Candle's direct assembly.
   Fixed width alone does not explain deterioration with elapsed history.
3. **Buffered rows still produce individual writes.**
   `services/model_features/export.mqh:40` opens/checks/seeks on each flush, then
   line 56 encodes and writes every row separately. Old Candle retained open
   handles and flushed every 128 rows; it did not already use byte-batched output.
   Preserve the new integrity protections while reducing conversion/allocation
   and write-call overhead.
4. **The current run uses Visual mode.** The new H1/M3 Candle configuration owns
   seven research indicator handles plus its separate execution ATR. Official
   tester documentation says Visual mode recalculates indicators on every tick;
   nonvisual calculation is generally demand driven. Hiding indicators does not
   establish that native calculation cost disappears. The pre-refactor run's
   Visual setting is unknown.
5. **Existing short acceptance did not establish full-history performance.**
   Prior single-pair one-week times were Candle 2.545 -> 2.635 seconds and Pivot
   17.836 -> 15.044 seconds, with settings different from the current run. They
   prove neither the reported regression magnitude nor a full-history speedup.

### Current-run sample and limits

- Dataset: `Common/Files/MQL5ModelDatasetV1/runs/CANDLE_PATTERNS_XAUUSD_2015`;
  Candle 2.00, `CANDLE_PATTERN_ATR_V2`, `XAUUSD_Exness_2015`, H1/M3,
  `EXNESS_SESSION`, export on, reference lot size `0.001`, logs off.
- Journal confirms Visual testing from 2015-08-10 through 2026-09-23, started
  2026-09-24 22:13:49.534 Europe/Berlin. Persisted settings indicate real ticks,
  USD 10,000,000 deposit, 1:500 leverage and 100 ms delay; bind these to a final
  native settings/report receipt before treating them as fully proven.
- Ten samples over 90.009 seconds: tester CPU 99.59% of one core; RSS
  7,880.29 -> 7,897.82 MiB; 34 file descriptors; zero disk-read bytes and zero
  major faults. Export size near sample end was 957,350,980 bytes.
- Observation sequence increased by 871,312; this is not an exact tick count.
  Buffered snapshot times advanced from 2016-11-10 to 2016-11-15. An interim
  80-second sample recorded about 130,044 read and 119,248 write syscalls, with
  about 20.6 MB of physical writes. These are process metrics, not per-function
  attribution or evidence of saturated storage bandwidth.
- The evidence shows a CPU-intensive interval and modest RSS growth, not a
  proven leak. Native tick/history/indicator retention can contribute to RSS.
  The precise cause of the reported progressive slowdown remains open.
- The run was left running. Its summary was unsealed; do not validate it as a
  completed dataset. No compile, native profile, new tester job or implementation
  test ran during this review.
  Execution annotation: the user stopped that original run at
  2026-09-24 23:24:16.951 Europe/Berlin. Its unsealed output is retained;
  `s1/operator-run-disposition.json` records that this session did not stop it.

### Candidates requiring measurement

- Candle uses bounded 2048 broker / 6144 virtual slots and shrinks extents after
  terminal cleanup. It does not intentionally retain every completed position.
  `HistorySelectByPosition` serves missing entry facts or disappeared positions,
  not every normally open position. Measure its frequency and selected deal cost.
- Pivot reconciliation selects history from trigger/entry lookback through the
  current time and scans selected deals in
  `services/trading_signals/execution_broker_reconciliation.mqh:272` and `:430`.
  Increasing account history is a candidate, not a confirmed dominant cause.
- Measure native indicator cost, Timer work, chart work, active-state occupancy,
  serialization and history selection independently. Do not infer a leak from
  increasing RSS or infer algorithmic growth from simulated days per second.

## 3. Preserved Runtime Contract

- Defaults Macro H1 / Micro M3, supported native periods with `Micro < Macro`;
  no Deep path. Fixed M1 structure remains independent of those role periods.
- Native Stochastic 5/3/3 SMA Close/Close K/D; weighted-price percent B/SMA5;
  ATR13 x 1.0/SMA5; six shifts 0..5 with each historical candle's own price.
- Confirmed M1 state and a separate current forming projection, including
  undrawn candidates. Warmup <=4096 prior closed bars; catch-up <=256 per
  callback. Retain initial/retry/history-change/readiness reasons and no lookahead.
- Macro adjacent zones from the previous completed native candle; captured-Bid
  relation to the latest/outermost tested support/resistance, including PP rules.
- Raw precision, millisecond facts, explicit unknowns, exact close/reference
  clocks and censored states. Broker time remains causal; Exness normalization is
  export-only and cannot reorder native events.
- Callback sequence and lifecycle ordering; Candle both directions, confirmed-SL
  re-entry, independent ATR stops and per-entry expiry; Pivot structural 1R
  broker ownership, eight virtual lanes and exact accepted-request parity.
- Shared failures never gate broker decisions. Preserve first-failure diagnostics,
  matching tester stop, missing/header/append/flush/seal checks, refusal of reused
  run IDs and original failed data. No relaxed reader or silent repair.

## 4. Resources And Task Context

### Source and documentation owners

| Concern | Files/resources |
| --- | --- |
| Rules and status | `AGENTS.md`, `docs/README.md` |
| Runtime/consumer contract | `docs/architecture/market-data-broker-executor.md`, `docs/architecture/model-feature-dataset.md`, `docs/research/model-feature-producer-handoff.md` |
| Shared observation/capture | `services/model_features.mqh`, `services/model_features/stochastic_structure.mqh`, `services/model_features/indicators.mqh`, `services/model_features/pivot_context.mqh` |
| Row, clock, writer and generator | `services/model_features/types.mqh`, `services/model_features/clock.mqh`, `services/model_features/export.mqh`, generated `services/model_features/schema.mqh`, `tools/model_dataset/schema_contract.py` |
| Candle | `Candle_Pattern_Discovery.mq5`, `services/candle_pattern/{engine,broker,state,dataset_adapter}.mqh` |
| Pivot | `Pivot_Macro.mq5`, `services/trading_signals.mqh`, `services/trading_signals/{execution_broker_reconciliation,pivot_dataset_adapter}.mqh`, reached state/frontend helpers only if profiling implicates them |
| Existing checks | `tools/model_dataset/tests/`, `tools/candle_pattern_ml/tests/`, `tools/deterministic_signal_ml/tests/`, `tools/model_dataset/reader.py` |
| Native procedures | `docs/environment/mt5-agentic-workflows.md`, `tools/mt5/compile_mt5.py` |
| Prior native evidence | `.codex-artifacts/model-feature-framework/s1/` old sources/binaries; `s3/`, `s4/`, `s5/` settings, comparisons, fault/prefix/feature checks; `s6/` handoff |
| New private evidence | `.codex-artifacts/model-runtime-optimization/{discovery,s1,s2,s3,s4,s5}/` |

- **Workspace:** `/home/admin/.wine/drive_c/MetaTrader 5-1/MQL5/Experts/HFT_Grid_AI`;
  `/home/admin/mql5_projects/HFT_Grid_AI` resolves to the same checkout. One writer,
  no delegation. Keep raw data, binaries, profiles and diagnostics ignored.
- **Guidance:** Reuse the completed on-demand search for
  `profiling performance optimization memory growth CPU IO bottleneck benchmarking`,
  limited to five results at library revision
  `4b57740b1048475aeb21d9adfc9ecea0affa97b7`. Selected `performance-profiling` for
  baseline -> identify -> optimize -> validate. Its browser examples do not apply;
  no browser tools, Lighthouse or installation prerequisite. Receipts:
  `discovery/skill-search.json`, `discovery/skill-selected.json`.
- **Graph:** Understand-Anything refreshed the `services` scope at unchanged
  planning sources: 44 file nodes, no omitted files, zero parsed MQL edges.
  Artifact `/home/admin/.cache/codex-skill-stack/graphs/3b77e337ea639ce9e6fedf5192c979f3d2adf8f78a5fc3a065a977215d95ff6c/knowledge-graph.json`;
  helper revision `6df3065f1d8ddc2ce3615314d1d493f36d6b1c80`.
  This is a file map only; direct source/include inspection owns conclusions.
- **MCP routes:** Retained plugin `references/project-mcp-routing.md` and the
  environment runbook were consulted. MetaTrader workspace discovery succeeded.
  Discover each server's current schema and call `get_workspace_info` before its
  operations. Prefer MetaEditor `compile_file` and MetaTrader
  `tester_run_backtest`/status/report/stop routes. Native compiler fallback is
  permitted only when MCP cannot execute, with the reason recorded.
- **Active-run limitation:** The manually started job has no discovered MCP job
  ID. Earlier ID `7689186496611578884` was rejected as not matching; never reuse
  it to stop the current job. Identify the exact native tester first if a stop
  becomes necessary; use normal stop, retain deinitialization evidence and do not
  kill unrelated terminal processes. Read-only review requires no stop.
- **Existing evidence:** Prior 74 shared, 44 Candle and 51 Pivot Python tests and
  zero-error/warning compiles are historical passes, not rerun review checks.
  Current source/binary pins and runtime samples are in
  `discovery/run-context.json` and `discovery/running-summary.json`.

Official references fetched successfully on 2026-09-24, retained in
`discovery/official-docs.json` and its companion text extracts:

1. [Strategy Tester behavior](https://www.mql5.com/en/docs/runtime/testing):
   indicator calculation differs in Visual mode; Timer frequency affects work.
2. [iTime](https://www.mql5.com/en/docs/series/itime): each call requests current
   timeseries data and has no local quick-return cache.
3. [HistorySelectByPosition](https://www.mql5.com/en/docs/trading/historyselectbyposition):
   position-specific selection and shared history-list semantics; native
   complexity is not specified.
4. [MetaEditor profiling](https://www.metatrader5.com/en/metaeditor/help/development/profiling):
   use native history sampling. The page contains older Visual wording and a
   newer explicit note that history profiling is nonvisual; verify the installed
   build's actual mode. Profile builds are not release timing baselines. Never
   profile these EAs on a live trading chart.

## 5. Measurement And Validation Gates

### V1: Source, schema and unit checks

Run checks affected by each change; keep raw receipts outside tracked source.
These are implementation commands, not claims of new passing evidence:

```bash
git diff --check
.venv/bin/python -m tools.model_dataset.schema_contract --check-mql-header services/model_features/schema.mqh
rtk test .venv/bin/python -m unittest discover -s tools/model_dataset/tests -t . -p 'test_*.py'
rtk test .venv/bin/python -m unittest discover -s tools/candle_pattern_ml/tests -t . -p 'test_*.py'
rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python -m tools.model_dataset.reader "$MODEL_RUN_PATH" --report "$MODEL_REPORT_PATH"
```

Set the final two paths to a sealed owned run and an external receipt. Add
meaningful cases to existing suites only where changed behavior warrants them.
Review exact symbol references, both include closures, broker/research ownership,
resource bounds, local links and tracked artifact exclusions. Generate schema
code through the existing generator, never hand-edit its output. No full legacy
test repeat is required when its inputs and prior acceptance remain unchanged.

### V2: Native builds

For any source/include/compiler change, compile both affected EAs through
MetaEditor MCP with the accepted optimized AVX2 target. Require `0 errors,
0 warnings`, regenerated EX5 metadata and source/include/compiler/EX5 hashes.
Use isolated benchmark EA names/paths with receipt mapping, preserving internal
engine identities; never overwrite an active operator's binary. Keep native
profile and release build identities separate. Documentation-only changes need
unchanged source/binary hashes, not another compile.

### V3: Exact behavior and feature acceptance

- Compare optimized output against the pinned **current schema-1 producer** in
  original table/row order: all ten Pivot or eleven Candle TSVs. Normalize only
  verified run-ID values/references and explicitly enumerated build provenance
  fields. Record expected operational resource-peak differences separately;
  never exempt feature gaps, counts, clocks, values, membership, order or labels.
- Validate both datasets strictly on the zero-delay acceptance baseline (D07).
  Positive execution delay remains supported as an intentional simulation
  setting. Existing delayed Candle exports can fail strict chronology when a
  broker close is later than the last quote observation; retain that evidence
  without changing clocks or weakening intake. Compare ordered native broker requests,
  order/deal report cells and non-job statistics; pair export on/off per engine.
  Reuse prior comparison/audit routines in ignored receipts with explicit path
  parameters, not stale hardcoded run IDs.
- Old Candle 1.02 / Pivot V14 have intentionally different research schemas.
  Compare their preserved broker facts and documented ownership exceptions;
  never require their obsolete feature datasets to equal schema 1.
- Exercise H1/M3, H2/M3, H1/M1 handle reuse, Candle M6 expiry, both directions,
  re-entry, Pivot midpoint/no-touch/parity, repeated equal-time quotes with
  changed prices, M1/Macro rollover, partial history, delayed availability,
  catch-up >256 bars, history-change detection, and gold/FX DST boundaries.
- Compare identical-start short/long prefixes, including confirmed and forming
  M1 fields, to detect lookahead or stale cache reuse. Isolated late-date runs
  have different warmup context; they are performance samples, not an exact
  feature oracle for a continuously running prefix.

### V4: Writer and failure acceptance

In new disposable owned runs, reuse missing-file/header/final-seal/reused-ID
fault procedures. Include the already-flushed-table seal recheck, a partial
batch at shutdown and row/byte flush boundaries. Verify exact UTF-8/CRLF bytes,
null/precision/clock tokens, exact counts, checked short-write/allocation/flush
failure paths, first-error latching and rejected intake. Exercise unavailable
native faults by focused checked-path review if no existing safe injection
exists; label that limitation. Never corrupt the operator's growing dataset.

### V5: Performance and bounded-work acceptance

1. Pin symbol/feed/import/spec hashes, interval, requested/effective tester
   settings, periods, lot settings, deposit/currency/leverage, delay, logging,
   Visual speed/template, export state, compiler/CPU target, machine load and
   cache preparation. Use one tester workload at a time and fresh run IDs.
2. Separate startup/history synchronization, warmup, steady execution and final
   sealing. For short/medium benchmarks use a warmup and at least three alternating
   baseline/candidate pairs; report median, range and raw samples. A speed gain
   below 5%, or within observed timing variation, is inconclusive.
3. Record wall/CPU time, actual tick count where native reports expose it,
   callback counts by type, signals/snapshots/rows/bytes, active extents/peaks,
   handle count, per-process sampled RSS/HWM, descriptor counts and I/O deltas.
   Do not substitute callback sequence for ticks. For stage profiling use
   aggregate call counts/time and per-call distributions where available.
4. Use matched early/middle/late windows and growing identical-start prefixes:
   day, week, month and year, extending only when the previous stage passes.
   Inspect time per callback, capture, active-item/deal scan and output byte,
   accounting for tick density and trade frequency. Days/second alone is not a
   regression measure. Distinguish native retained history from application state.
5. Promote only changes with exact V3/V4 behavior and measured cost improvement;
   either engine regressing by more than 5% beyond measured noise blocks
   promotion. A flat result may justify retaining simpler code, but is not a
   claimed speedup. Persistent late-stage growth in comparable application work
   must be explained and bounded or remains a failed optimization gate.
6. Steady-state application memory/work must depend on fixed windows, bounded
   buffers and active lifecycles, never all previously exported rows/trades.
   Preserve current 4096/256 structure budgets and engine caps. Record byte
   buffer limits and cache invalidation rules before implementing their changes.
   Native MT5 memory growth is reported separately; stable FD/RSS samples alone
   cannot establish leak freedom.
7. Run final full-history real-tick export-on acceptance for both engines after
   focused gates pass. Use retained matching full baselines when available;
   otherwise create them with resource guards. If a baseline cannot finish,
   retain its stop reason and comparable prefix, and report full-history speed
   as unmeasured rather than extrapolated. Do not repeat every full-history run
   after each small change.

No blanket Timer removal/coarsening is allowed: it services broker lifecycle
and expiry. Use native history profiling first. If attribution remains missing,
permit narrowly scoped compile-time counters in the real EA code, with bounded
aggregate diagnostic output outside the dataset, no public input/schema change,
and measured instrumentation overhead. Final speed evidence uses release builds
with instrumentation disabled. Reuse existing private sampling/check helpers;
no new committed profiling framework or test harness.

## 6. Ordered Sprints

Each sprint requires its tasks and named validation, a reviewed tracked diff,
exactly one sprint-specific commit, recorded residual risks and the pre-sprint
rollback commit before the next sprint starts. All private receipts go in the
corresponding `sN/` directory. A measurement-only outcome is legitimate when a
candidate is not material or no semantics-preserving improvement is proven;
record it explicitly instead of changing a working path for appearances.

### Sprint 1: Reproduce And Attribute The Slowdown

- **Goal:** A reproducible old/current baseline and measured cost attribution.
- **Dependencies:** Execution authorization, clean ownership check, retained
  binaries and a free tester. Preserve or normally stop the identified current
  run before scheduling any competing tester job.
- **Tracked scope:** This plan's execution annotations, `docs/README.md`,
  `docs/environment/mt5-agentic-workflows.md`; narrowly scoped real-EA diagnostic
  counters only if native profiling is insufficient.
- **Tasks:**
  1. Pin old Candle 1.02/Pivot V14 and current 2.00 source/include/binary receipts;
     recover comparable settings if available. Retain unknowns, and label new
     old-build runs as reconstructions of the user's timing reference.
  2. After task 1, run old/current short/medium comparisons for both engines:
     export on/off and Visual/nonvisual, then selected growing prefixes. Apply
     V5 controls; do not require full multi-year completion to locate a bottleneck.
  3. Profile early and late phases of the real EAs in history mode. Attribute
     shared observation, native indicators, row building, writing and engine
     reconciliation. If counters are necessary, validate their overhead and
     separate their receipts from release timing.
  4. From tasks 2-3, freeze the benchmark cases, metrics, resource guards and
     ranked cost table in `s1/baseline.json` / `s1/profile-summary.json`. Update
     current-plan navigation in existing owners; keep the completed framework
     plan as historical evidence until its final archival task.
- **Acceptance/validation:** V1 documentation/include review; V2/V3 if counters
  change code; V5 reproducible paired measurements and stage attribution. State
  explicitly whether settings reproduce the reported ten-minute baseline.
- **Commit:** `docs(perf): pin model runtime baselines and profiling evidence`
  (use `perf(diagnostics): attribute model runtime costs` if counters ship).
- **Rollback:** Record S1 parent, initially expected to be `2292be7`; revert only
  this sprint's commit. Restore its matched binary if instrumentation changed
  code. Retain all baseline/operator data and receipts.
- **Gate:** Tasks, validation, exactly one commit and rollback pin complete
  before S2; unresolved attribution blocks speculative source optimization.

### Sprint 2: Bound Shared Observation And Feature Reads

- **Goal:** Reduce measured duplicate source work without stale snapshots.
- **Dependencies:** S1 gate and its ranked profile.
- **Tracked scope:** `services/model_features.mqh`, shared `types.mqh`,
  `stochastic_structure.mqh`, `indicators.mqh`, `pivot_context.mqh`; existing
  `tools/model_dataset/tests/test_structure.py` / `test_features.py` as needed.
- **Tasks:**
  1. Introduce a bounded M1 update path separating closed-bar advancement,
     readiness/history validation and capture-time forming projection. Preserve
     every callback sequence, retries after unavailable data, gap catch-up and
     first-date/prior-source changes. Retain any query whose removal cannot
     preserve its observable availability/failure timing; an unchanged bar alone
     is not enough to reuse a prior failure or declare history unchanged.
  2. After task 1, optimize only profiled repeated indicator/rate reads and
     temporary allocations. Prefer reuse within one capture; any cross-capture
     cache needs bounded ownership and explicit symbol/period/parameters, bar,
     quote, stage and source-readiness/history invalidation. Equal milliseconds
     alone are not identity. Keep capture guards before/after reads and shifts
     0..5 exact; no substitution of final OHLC for observed shift 0.
  3. Verify both include trees and unchanged engine callback/lifecycle ordering;
     compare exact baseline output and profile call counts on the same cases.
- **Acceptance/validation:** V1/V2/V3; V5 short/medium pairs and growing-prefix
  checks. Forming candidates remain current, incomplete features remain explicit,
  and history/catch-up behavior is unchanged. Retain only demonstrated wins.
- **Commit:** `perf(features): bound repeated shared observation work`
  (measurement-only alternative: `docs(perf): record shared feature cost limits`).
- **Rollback:** Record S2 parent (S1 commit); revert S2 and restore/rebuild both
  matching EX5s. Keep generated datasets under their original run IDs.
- **Gate:** Tasks, exact feature/broker checks, measured result, one commit and
  rollback pin complete before S3.

### Sprint 3: Make Row Construction And Writing Linear

- **Goal:** Remove repeated field/clock searches and amortize checked byte writes.
- **Dependencies:** S2 gate; S1 serialization/I/O evidence.
- **Tracked scope:** `tools/model_dataset/schema_contract.py`, generated
  `services/model_features/schema.mqh`, shared `types.mqh`, `clock.mqh`,
  `export.mqh`, provider/adapter call sites, existing `test_contract.py`,
  `test_clock.py` and `test_extensions.py` where needed.
- **Tasks:**
  1. Generate table-qualified field indices and clock companion offsets from
     the existing descriptor. Replace hot name-based assignments with checked
     indexed access, including role/shift mappings. Preserve field validation,
     table/type ownership, header order and strict unknown-field failure; avoid
     hardcoded duplicate schemas. Precompute immutable header/layout data once.
  2. After task 1 parity passes, implement bounded byte batches and reusable
     scratch capacity. Declare both row and byte limits, oversize-row handling,
     allocation checks and partial-batch shutdown. Bound staging copies; do not
     concatenate an entire run or repeatedly copy a growing batch quadratically.
  3. Keep missing/header/append/flush/final-seal protections. Prefer fewer writes
     within the existing checked open/close lifecycle; persistent handles require
     separate evidence that replacement/removal and seal faults remain detectable.
     Check exact bytes written and preserve first-failure research isolation.
- **Acceptance/validation:** V1/V2/V3/V4; V5 serialization time, write-call counts,
  bytes/second and bounded buffer peaks. Runtime and generated-schema checks must
  reject wrong table/type/offset access. All schema-1 column tokens and row order
  remain identical; resource peaks are explicitly accounted for.
- **Commit:** `perf(dataset): index fields and batch checked export writes`.
- **Rollback:** Record S3 parent (S2 commit); revert generator, generated header,
  writer and call sites together, then restore/recompile both matching EX5s.
  Never append old code to a partially written optimized run.
- **Gate:** Tasks, exact bytes/schema/broker checks, disposable faults, measured
  result, one commit and rollback pin complete before S4.

### Sprint 4: Bound Measured Engine Lifecycle Costs

- **Goal:** Remove any measured history-length cost in Candle and Pivot while
  preserving exact execution, reconciliation and output order.
- **Dependencies:** S3 gate; reprofile only as needed after shared costs change.
- **Tracked scope:** Candle `engine.mqh`, `broker.mqh`, `state.mqh`; Pivot
  `execution_broker_reconciliation.mqh` and directly reached state helpers;
  frontend/entrypoints only where the profile establishes an avoidable cost.
- **Tasks:**
  1. Measure scans against active occupancy and selected account/position deal
     counts. Inspect stable cleanup/extent reuse and native history-list effects.
     Do not replace already bounded arrays merely because process RSS grows.
  2. Optimize only material repeated selections/scans: reuse confirmed immutable
     facts, bound work to active/unresolved identities, and preserve retries for
     delayed deal availability. Prefer existing helpers over a new indexing
     subsystem; retain safe fallback reconciliation where needed.
  3. Validate both directions, entry/close costs, late transaction observations,
     exact actual close clocks, expiry, same-tick re-entry, midpoint survival and
     deterministic tie/order handling. Keep fresh pre-send checks and Timer
     lifecycle guarantees. Retain engine paths unchanged if no material cost is
     proven; record the measured decision for each engine.
- **Acceptance/validation:** V1/V2/V3 and V5 early/late and higher-occupancy cases;
  V4 if terminal export/failure paths change. Selected-deal/callback costs and
  active caps are explained and bounded. No duplicated/omitted/misattributed deal
  or changed broker/virtual/parity outcome is acceptable.
- **Commit:** `perf(engines): bound measured lifecycle reconciliation work`
  (measurement-only alternative: `docs(perf): record engine lifecycle cost evidence`).
- **Rollback:** Record S4 parent (S3 commit); revert only S4 and restore/rebuild
  matching binaries. Keep trade/dataset evidence intact; this is tester-only work.
- **Gate:** Each engine's measured disposition, broker/data gates, one commit and
  rollback pin complete before S5.

### Sprint 5: Full-History Acceptance And Future-Engine Rules

- **Goal:** Establish final long-history results and prevent recurrence when
  new engines/features are added.
- **Dependencies:** S4 gate and all focused failure/parity checks passed.
- **Tracked scope:** `docs/README.md`, `docs/environment/mt5-agentic-workflows.md`,
  `docs/architecture/market-data-broker-executor.md`,
  `docs/research/model-feature-producer-handoff.md`, `tools/model_dataset/README.md`,
  concise `AGENTS.md`, this plan and completed-plan archival/navigation.
- **Tasks:**
  1. Apply V5 to final release binaries and pinned unoptimized current baselines.
     Complete both full-history Exness exports and strict V3 intake, including
     final seal time and resource slopes. Use short matched Visual checks for
     rendering/indicator behavior; report Visual throughput separately. Reuse
     unchanged focused/fault evidence; rerun only invalidated gates.
  2. Publish measured old/current/optimized timing with configuration differences,
     ranges and stage attribution. Distinguish recovered throughput, remaining
     native cost and unresolved regression. Do not label full-history acceptance
     passed if a run was stopped, failed or never strictly validated.
  3. Add the checklist below to existing engine onboarding/runtime/validation
     owners; correct legacy-only twelve-file/Deep language in the validation
     runbook for new shared-schema acceptance while retaining historical rules.
     Pin final source/binary/run receipts in the producer handoff for later
     Django planning. Keep human chart/feed/broker/recovered-run gates explicit.
  4. Archive the completed framework plan to
     `docs/plans/archive/mql5-model-feature-framework-plan.md` with repaired
     relative links and Git recovery reference. Keep this as the single latest
     plan, preserve old facts/commit pins, and update navigation. Keep AGENTS
     <=160 lines / 8 KiB and changing project status in `docs/README.md`.
- **Acceptance/validation:** V1 links/source pins; V2 only if sources changed;
  final V3/V5 for both models. Existing consumer handoff remains usable with no
  schema/feature/engine identity changes. An unresolved performance or native
  gate is reported as open, not completed by documentation alone.
- **Commit:** `docs(perf): publish model benchmarks and engine performance rules`.
- **Rollback:** Record S5 parent (S4 commit); revert S5 documentation/navigation
  as one commit if needed, without deleting private runs or acceptance evidence.
- **Gate:** Final outcomes, tests, residual limits, one commit and rollback pin
  recorded; close execution state only after required automated gates pass.

## 7. Future-Engine Performance Contract

Every new engine or shared feature must declare and validate:

1. **Work frequency:** Which Tick/Timer/TradeTransaction/bar/capture events update
   it; separate advancing closed state from live projection and serialization.
   State the per-callback/per-bar/per-snapshot work bound and retry policy.
2. **Resource bounds:** Maximum indicator handles, active records, cache entries,
   pending work and row/byte buffer capacity. Storage output may grow with events;
   retained application state must not grow with completed history.
3. **Invalidation:** Symbol, role, source parameters, native bar/quote identity,
   source readiness/history and failure changes. A timestamp alone is not a
   reusable snapshot key. Shift-0 features must remain current at their capture.
4. **Shared ownership:** Reuse generated descriptors and existing providers;
   no per-tick handle creation, copied indicator services, per-field linear
   searches or unbounded full-history scans. Separate execution-owned resources.
5. **Determinism:** Preserve callback ordering, exact event/snapshot identity,
   row order, source clocks, precision, labels and explicit unknown/censor states.
   Read-only feature services cannot change a broker decision.
6. **Evidence:** Export-on/off broker parity, exact-prefix/feature checks,
   failure/seal checks, handle cleanup and day/week/month/long-history metrics.
   Report CPU/callback/row/byte/active-state-normalized cost and early/late trends.
   Shared changes require both existing engines' focused regression gates.

Implement these through generated invariants, meaningful cases in existing tests,
source review and native acceptance receipts. Do not introduce new CI, harnesses
or a third trading EA to enforce them.

## 8. Risks, Rollback And Execution Handoff

| Risk | Mitigation and acceptance signal |
| --- | --- |
| Different settings or tick density appear to be a code regression. | Pin the native reports/settings and use matched stage-normalized V5 comparisons. |
| A new cache hides updated history or stale shift 0. | Explicit invalidation, retry and prefix checks; retain the original path if equivalence is unproven. |
| Batching loses errors or increases retained memory. | Row and byte caps, checked writes, exact bytes, seal/fault checks and bounded scratch capacity. |
| History selection/indexing changes deal order or close attribution. | V3 native broker/TSV equality, stable identity/order and unresolved-deal retries. |
| Profiling distorts cost or assumes Visual matches nonvisual. | Separate native profiles from optimized release timings and measure instrumentation overhead. |
| Full-history runs exhaust disk/memory or monopolize the tester. | S1 pins conservative guards from available resources and measured output growth; stop only the owned run, retain incomplete data, report an unpassed gate. |
| Old ten-minute runtime cannot be reproduced with the new required features. | Report the comparable baseline and measured feature/native cost; a semantic scope change requires a separate user decision. |
| Historical evidence or active operator binaries are overwritten. | Isolated benchmark paths, fresh run IDs, immutable receipts and no shared-folder cleanup. |

For each sprint, record its parent and resulting commit plus exact source and
binary receipts. Roll back with a new reviewed revert commit, never reset/amend
history; unwind dependent sprints in reverse order and restore matching binaries
or recompile. A revert is not permission to deploy or alter open live positions.
No dataset migration is required: schema 1 remains exact, old and failed datasets
stay untouched, and every corrected run gets a new ID. Do not clear shared MT5
history/cache or change global settings to manufacture benchmark gains.

Execution starts only after its authorization is present. At that handoff, read
the loaded Planner's `references/execution-state.md`, retain the previous
framework plan's completed state/evidence and initialize a new active state for
this plan. Do not restart the six completed framework sprints. Preserve accepted
decisions and record any newly required question as a blocker before yielding;
continue only independent authorized work while it is unanswered.

- [x] Execute S1, validate, create exactly one commit and record its parent.
- [ ] Execute S2 only after S1, with the same validation/commit/rollback gate.
- [ ] Execute S3 only after S2, with the same gate.
- [ ] Execute S4 only after S3, with the same gate.
- [ ] Execute S5 only after S4 and record full-history outcomes for both engines.
- [ ] Retain human chart, broker-feed and recovered-run gates in the index;
  automated performance acceptance grants no live rollout authority.

## 9. Execution Evidence

### Sprint 1

- Commit: `d7d7097` (`docs(perf): pin model runtime baselines and profiling evidence`).
- Rollback parent: `2292be7517201a41b8dde8b78e503f413c15eb31`.
- Immutable source/EX5 closures: `s1/build-pins.json`, `s1/include-trace.json`.
  Production source and binaries are unchanged. Isolated profiled real-EA
  copies compile on MetaEditor 6184 AVX2 with zero errors/warnings.
- Baselines: `s1/baseline.json`; three alternating measured week pairs after
  repetition-0 warmup. Candle export-on median `0.857 -> 1.009 s`, export-off
  `0.325 -> 0.267 s`; Pivot `15.395 -> 12.497 s` and `0.350 -> 0.337 s`.
  Month and Candle year prefixes retain broker equality. Visual pairs are
  separate single samples; no repeatable Visual speed claim is made.
- Attribution: `s1/profile-summary.json`. Pivot's early-week trial loop is
  12.657 seconds inclusive (8.195 self), with midpoint activation 3.582 seconds
  inclusive. Large active-state copies in per-tick loops are the S4 candidate;
  measured broker history selection is small. Candle costs are distributed
  across callbacks, observation, capture and serialization. Instrumented
  overhead is substantial and excluded from release timings.
- Early/late profiles show no demonstrated increase in cost per callback for
  shared M1 work. Late weeks have different tick density and active lifecycles.
  No leak or complete explanation of the operator's progressive Visual slowdown
  is established. The exact old sub-ten-minute configuration remains unknown.
- D07 resolves Q01: positive delay is intentional; zero-delay strict gates
  replace delayed strict acceptance for this plan. Retain the unchanged delayed
  Candle chronology failure in `s1/baseline-chronology-failure.json`.
- Validation: `s1/independent-validation.json` (17 checks) and
  `s1/zero-validation.json`; exact instrumented/current tables, ordered broker
  comparisons, matching-start feature prefixes and non-job report statistics.
  Day/week/month zero-delay exports supply canonical schema-1 baselines.
- Resource guards and history exclusions are in `s1/baseline.json`. Production
  source/EX5 pins, include tracing and documentation checks precede the commit.

### Sprint 2

- Measurement-only disposition permitted by the sprint contract; no runtime
  change or speed claim. Rollback parent: `d7d7097`.
- `s2/assessment.json` records source inspection and early/late profile costs.
  M1 update self time averages 0.134/0.142 microseconds per Candle observation
  and 0.236/0.182 per Pivot observation, including the bounded warmup work.
  No history-length growth is demonstrated in this path.
- Existing code already separates bounded closed-bar advancement from
  capture-only forming projection. Keep callback readiness resets, native
  first-date/cursor queries, prior-source validation and source guards. An
  unchanged quote/bar does not establish unchanged native availability/history;
  replacing the cursor query with another source query has no proven benefit.
- Indicator arrays are fixed at ten source values; catch-up allocates at most
  257 rates/256 K values. Capture runs once per snapshot. Seven-level touch
  tracking retains observation sequence even for repeated timestamps. No
  per-tick indicator allocation or unbounded retained history was found.
- No safe, material read removal was established. Retain these source paths;
  S3 targets the measured per-field search and serialization costs instead.
- Validation reuses identical source/EX5/include pins and S1 native strict,
  prefix and broker receipts. Existing structure/feature tests and whitespace
  checks complete this documentation-only gate; compilation is not required.
