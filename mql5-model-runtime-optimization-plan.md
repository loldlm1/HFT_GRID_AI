# Plan: MQL5 Model Runtime Optimization

- **Generated:** 2026-09-24
- **Status:** Completed - five sprints, including the D11 readiness fix.
  Corrected full-history generation/acceptance remains manual under D10.
- **Execution authorization:** The user requested execution of all five sprints,
  including the planned validation and commit gates, on 2026-09-24. Earlier
  authorization to stop the current Candle tester if needed remains applicable.
- **Proposal:** Not requested; this is the follow-up to the completed
  [feature framework plan](docs/plans/archive/mql5-model-feature-framework-plan.md).
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
| D08 | During full-history execution, the user requested preserving both model datasets for the later backend upgrade and authorized removing comparison/test datasets. | Preserve both optimized full-source runs with strict validation, file hashes and consumer receipts. After all dependent checks, remove only positively identified generated comparison/test datasets. Retain native reports/settings/source pins, handoffs, operator/recovered data and raw Exness history. Record the exact cleanup inventory and retained run IDs. |
| D09 | On 2026-09-25 the user clarified that zero-versus-positive-delay comparisons are unnecessary, then explicitly requested only the handoff with both new full datasets; a later thread owns backend work. | Do not add latency comparisons or open the Django repository. Finish and validate both optimized full-source datasets at fixed zero delay, update the handoff and apply D08. Retain completed comparison evidence; defer the unstarted full Pivot baseline and report its full-history speedup as unmeasured. Backend implementation belongs to the later thread. |
| D10 | The user then explicitly requested finishing this plan without waiting for full-history runs, which they will continue manually. | Close S5 using completed short/medium/first-year validation and final documentation/source checks. Leave the current native run running, disable the automatic queue, preserve available datasets and provide both final full-run configurations plus manual strict-intake commands. Full-history generation/validation remains an operator follow-up, not a passed gate. No further native run is launched. |
| D11 | After the missing Macro percent-B readiness issue was reported, the user authorized fixing remaining issues with fast Strategy Tester runs. | Repair shared indicator readiness within S5, compile both engines and use short partial/warm-start runs to prove recovery, independent feature values, unchanged broker behavior and unaffected fields. This is an explicit exception to exact feature equivalence for formerly unavailable measurements, not permission to backfill old exports. Stop the owned obsolete full run if needed; retain its disposition. Publish new source/binary pins and fresh manual full-run IDs. D10 still defers full-history reruns; D07 chronology and Django boundaries remain unchanged. |

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

D09 narrows the remaining work to the two validated final datasets and their
handoff. Reuse the completed full Candle and first-year Pivot references; the
unstarted full Pivot reference is deferred. This does not waive strict full-run
intake for either selected dataset or permit extrapolated full Pivot speedups.
D10 subsequently moves full-run completion and intake to manual follow-up;
the plan closes on the validated optimization and documented handoff. A future
consumer must still validate a naturally sealed full dataset before intake.

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
  concise `AGENTS.md`, this plan and completed-plan archival/navigation. A measured
  validation follow-up also adds one temporary SQLite lookup index in
  `tools/model_dataset/reader.py`; it changes no semantic checks or source data.
  D11 additionally authorizes `services/model_features/indicators.mqh` to repair
  the nonvisual startup readiness latch, with both release builds and short
  native regressions. Schema, price formulas and broker behavior stay unchanged.
  Newly complete Pivot snapshots can restore existing broker research eligibility
  from FEATURE_INCOMPLETE to the unchanged TP/SL label. Validate that derived
  transition against the associated snapshot; actual trades/outcomes never change.
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
  5. Apply D08 after validation: preserve the two optimized full-source datasets
     for the backend handoff, then delete only the inventoried comparison/test
     exports whose checks are complete. Record ownership, paths, bytes and retained
     hashes before cleanup; exclude operator/recovered sources, raw tick history,
     tracked fixtures and handoff bundles. Verify both retained datasets afterward.
- **Acceptance/validation:** V1 links/source pins; V2 only if sources changed;
  completed short/medium/year V3/V5 for both models, with full-history V3/V5
  explicitly deferred to manual follow-up by D10. Existing consumer handoff remains usable with no
  schema/feature/engine identity changes. An unresolved performance or native
  gate is reported as open, not completed by documentation alone.
- **Commit:** `perf(models): finalize runtime gains and repair indicator readiness`.
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
No dataset migration is required: schema 1 remains exact, operator/recovered
datasets stay untouched, and every corrected run gets a new ID. D08 permits
receipt-backed cleanup of owned comparison/test exports after their checks.
Do not clear shared MT5
history/cache or change global settings to manufacture benchmark gains.

Execution starts only after its authorization is present. At that handoff, read
the loaded Planner's `references/execution-state.md`, retain the previous
framework plan's completed state/evidence and initialize a new active state for
this plan. Do not restart the six completed framework sprints. Preserve accepted
decisions and record any newly required question as a blocker before yielding;
continue only independent authorized work while it is unanswered.

- [x] Execute S1, validate, create exactly one commit and record its parent.
- [x] Execute S2 only after S1, with the same validation/commit/rollback gate.
- [x] Execute S3 only after S2, with the same gate.
- [x] Execute S4 only after S3, with the same gate.
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

- Commit: `c9ee8b4` (`docs(perf): record shared feature cost limits`).
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

### Sprint 3

- Implementation and validation passed; rollback parent: `c9ee8b4`.
  Committed as `3b2ba9b`; full commit/rollback receipt is in the execution journal.
- The canonical descriptor generates unique table-qualified raw-field IDs,
  clock-companion offsets and bounded role/shift/level groups. Checked indexed
  access rejects wrong tables, types and offsets. Field choices and layouts are
  prepared once; row strings reserve capacity before checked appends.
- The indexed-only increment passes exact native day TSV/broker/statistics and
  strict validation for both engines (`s3/indices-validation.json`). The shared
  suite passes 76 tests, including generated field/clock-layout checks.
- Byte batches retain at most 256 rows or 1 MiB per used table. One reusable
  encoding scratch array is bounded by descriptor width and existing field
  length limits. Oversized rows split into bounded writes; final partial
  batches and empty-table seal rechecks remain explicit. Allocation, encoding,
  copying and writes are checked; failed Pivot cleanup resets released buffers.
  Bounds were recorded before implementation in `s3/writer-design.json`.
- Both batch B02 EAs compile on MetaEditor 6184 AVX2 with zero errors/warnings;
  source and regenerated binary metadata: `s3/build-batch-b02.json`. Retain the
  earlier failed Pivot cleanup compile separately; it is not an accepted build.
  The B02 day byte/broker/strict gates pass (`s3/batch-day-validation.json`).
- Source review and unchanged include topology: `s3/source-review.json`.
  Official `StringReserve`/`StringAdd` references were fetched on 2026-09-25;
  their cached responses are in `s3/`. No new dependency, test EA or harness.
- `s3/performance.json`: three alternating release pairs after warmup for both
  week and month. Candle medians `1.001 -> 0.800 s` / `4.727 -> 3.807 s`
  (20.1% / 19.5% lower). Pivot `12.597 -> 12.389 s` / `58.600 -> 58.468 s`
  remain within noise; no Pivot speedup is claimed for shared changes.
- `s3/batch-validation.json` passes 89 exact TSV, broker, statistics, prefix
  and strict checks, including H2/M3, H1/M1, partial warmup, gold/FX seasons,
  Candle M6, export-off, Visual and 100 ms equivalence. Strict acceptance
  continues to use zero delay. Historical B03 dataset folders were unavailable
  on first current lookup; recreate those baselines with the immutable S1
  current binaries and retain the original reports/configurations.
- `s3/fault-validation.json`: six missing/header/final-seal cases retain one
  first error, failed seals and rejected intake. `s3/reuse-validation.json`:
  two reused IDs refuse startup and preserve all source hashes/strict validity.
- Isolated copies of the existing EAs with 2-row/1024-byte buffers exercise
  298 Candle and 58 Pivot multi-chunk rows and partial batches. Both compile
  cleanly and retain exact dataset/broker facts; only the declared operational
  `buffer_peak` changes to 2 (`s3/buffer-stress-validation.json`). Release B02
  remains unchanged. No new EA entrypoint or MQL test harness is introduced.
- Native month row bytes plus the writer's checked batch boundaries imply
  96,491 -> 386 Candle / 31,200 -> 128 Pivot data-write API calls; these are
  source-derived counts, not OS syscall samples. Row peaks remain 256 and
  staged byte peaks stay below 1 MiB (`s3/writer-boundary-evidence.json`).
- `s3/static-validation.json` verifies unchanged canonical JSON contract,
  regenerated MQL header, source/EX5 pins and local links. OS allocation and
  short-write faults retain focused checked-path review; no native injection
  hook exists. All broker logic/callback ordering remains unchanged.

### Sprint 4

- Implementation and automated validation passed; rollback parent: `3b2ba9b`.
  Committed as `48f1f5f`; the execution journal retains its full SHA and parent.
- The profile implicates `pivot_trial_matrix_lifecycle.mqh`, a directly reached
  Pivot state helper within S4 scope. Copy-B01 reads active/pending fields before
  copying and passes trials by const reference in the hot resolver. Its isolated
  week profile matches the release dataset/broker facts and identifies 7,011,961
  resolver calls over 427,713 ticks. Profile overhead is excluded from timings.
- Final touch-B02 extracts the existing pure readiness/threshold calculation.
  Non-touch ticks avoid outcome construction; the resolver retains reset-on-false
  for broker parity. Eligibility, quote validity, strict second-based entry guard,
  TP/SL exclusivity, Bid/Ask sides, prices and outcome payload are unchanged.
  Transactional copies remain for actual activation. Reverse iteration and stable
  removal remain; no array-element reference survives mutation.
- Three alternating release pairs after warmup: week `12.362 -> 1.212 s`,
  month `58.294 -> 5.784 s`, late week `19.413 -> 1.631 s`. Raw samples/ranges
  are in `s4/performance.json`; the reductions are 90.2%, 90.1% and 91.6%.
  Day/week/month virtual peaks are 64/84/101 and late week 61, below the unchanged
  2048 cap. Structural-survival scans remain bounded by active occupancy.
- Exact TSV bytes, ordered broker reports/non-job statistics, strict intake and
  matching-start feature prefixes pass. The matrix covers H2/M3, H1/M1, partial
  warmup, gold/FX seasonal cases, export-off, Visual and 100 ms delay. Native
  receipts and comparisons are in `s4/validation.json`; D07 remains unchanged.
- Candle lifecycle source/binary is unchanged. Prior native close-history costs
  are 1.142 ms over 979 early calls and 2.001 ms over 1591 late calls. Position
  histories retain a 64-deal cap, confirmed-entry fast paths and bounded active
  extents. No material safe history-cache change is justified. Pivot history
  selection also remains unchanged; its measured close work is under 2 ms per
  profiled week. Native selection complexity is not claimed constant.
- `s4/lifecycle-assessment.json` records each engine's disposition;
  `s4/static-validation.json` traces unchanged include topology, Candle closure,
  canonical schema/shared sources/Python, broker isolation and exact references.
  Reuse the unchanged S3 76-test/fault/feature evidence. Pivot's regenerated EX5
  compiles on MetaEditor 6184 AVX2 with zero errors/warnings; pins are in
  `s4/build-final.json`. Resource snapshots retain process-lifetime HWM limits;
  they do not prove leak freedom. No new dependency, harness or live rollout.

### Sprint 5

- Completed; rollback parent: `48f1f5f`. The final commit is recorded in the
  execution journal after its creation. Both native year gates pass on the
  optimized pre-readiness builds; D11 adds final short native regressions.
  Corrected full-history completion/acceptance is explicitly deferred by D10.
- Long-run settings and guards are pinned in `s5/long-cases.json` and
  `s5/long-preflight.json`. The prepared gold source has 333,083,223 rows,
  begins 2015-08-10 and ends 2026-09-07 23:59:58.893 UTC. `s5/feed-pin.json`
  retains source coverage/gaps, hashes and import metadata. Both long prefixes
  start 2015-08-10; the full interval ends 2026-09-08 exclusive. The original
  operator requested through 2026-09-23, beyond this prepared source's end.
  Earlier day/week/month prefixes retain their matched 2015-08-17 start.
- Current/final release runs use real ticks, H1/M3, zero delay, reference risk
  0.001, simulated USD 10,000,000 / leverage 500, export on and Visual/debug off.
  Initial native warmup may advance the effective start; reconcile the journal
  and generated ticks with coverage before claiming full-source acceptance.
- The completed framework plan is archived with repaired links and original
  `48f1f5f:mql5-model-feature-framework-plan.md` recovery. Onboarding/runtime/
  validation owners declare bounded work/state, cache invalidation, retry and
  exact-behavior/performance gates. Current shared-schema procedures distinguish
  ten/eleven files and Macro/Micro from retained historical V14/Deep procedures.
  D11 later adds the shared readiness repair below; schema/backend stay unchanged.
- The first-year Candle reader exposes a separate validation cost: re-entry
  checks repeatedly scan `outcomes` by `attempt_id`. The interrupted owned
  validation traceback identifies that exact query; the existing fixture's
  SQLite plan changes from SCAN to indexed SEARCH with one temporary index.
  Add `outcomes_attempt_lookup` to the disposable reader database so full-source
  acceptance is practical. No query, strict rule, exported field or clock changes.
  Evidence: `s5/reader-index-query-plan.json` and the retained interruption log.
  All 76 shared tests and both indexed-reader year validations pass before
  extending to full history. This is a local performance fix within the MQL5
  project's acceptance tooling, with no Django or producer behavior change.
- The matched first-year pairs each generate 31,438,575 ticks and pass exact
  ordered bytes, broker cells/statistics and strict intake. Single-pair release
  times: Candle `61.383 -> 51.547 s` (16.0% lower), Pivot `849.944 -> 73.944 s`
  (91.3% lower). Receipts: `s5/year-*-validation.json`, `s5/year-performance.json`.
  `s5/year-source-coverage.json` reconciles the first-day history and one remaining
  startup quote difference; the terminal's internal first-tick disposition is
  not exposed. `s5/report-stream-validation.json` proves the bounded XML decoder
  retains the existing helper's ordered broker cells and canonical digest.
- Before full runs, release only the confirmed idle original operator tester,
  identified by the retained sampler, executable mapping, low CPU and no open
  dataset files. Its roughly 8 GiB retained memory is freed. The receipt
  `s5/idle-operator-worker-release.json` confirms exit and unchanged original
  dataset sizes/mtimes; no terminal, disk cache or operator data was removed.
- D10 explicitly closes this plan without waiting for full-source acceptance.
  The earlier Candle baseline and optimized run completed naturally in
  `787.053 / 669.674 s`, each with 332,994,255 ticks. The native full count is
  source rows minus 88,968 startup-day rows; the year-derived one-tick forecast
  was not exact and is corrected in `s5/full-source-coverage.json`. Full strict
  intake/comparison remains unrun; these times do not certify the latest repair.
  The queued full Pivot run never started, and the automatic queue is disabled.
- Handoff inspection found Macro percent B unavailable throughout the old
  year summaries and first/last full samples. D11 authorizes repairing this
  pre-existing readiness latch with fast native checks. `ModelCopyBuffer` now
  calls bounded `CopyBuffer` before the same `BarsCalculated` threshold, allowing
  demand-driven calculation. No formula, timeframe, schema or broker source changes.
  Readiness-null snapshots already written to disk remain immutable.
- Both EAs compile on MetaEditor 6184 AVX2 with zero errors/warnings. All 76 shared
  tests pass in 10.989 seconds. Twenty-four short native runs produce 40 passing
  strict, source-value, broker/statistic, unaffected-field, prefix and export-off
  checks. Partial cases recover 1,014/1,116 Candle and 141/156 Pivot Macro-percent-B
  snapshots; warm-week outputs remain exactly equivalent. Ninety-three Pivot
  broker research labels recover from FEATURE_INCOMPLETE under the existing
  policy, with unchanged entry/exit, TP/SL and orders. The validator binds every
  such transition to its newly complete entry snapshot. Preserve its initial
  eligibility-discovery assertion as diagnosis, not an unresolved failure.
- Three alternating warm-week medians after warmup: Candle `0.867 -> 0.848 s`,
  Pivot `1.321 -> 1.295 s`; no material regression or additional speed claim.
  Evidence: `s5/readiness-validation.json`, `readiness-compile.json`,
  `build-readiness.json` and `readiness-feature-availability.json`. Retain the
  original source/binary pins for year/full evidence; current release pins differ.
- The manual handoff reserves fresh `RUNTIME_S5_CANDLE_READY_FULL_ZERO` and
  `RUNTIME_S5_PIVOT_READY_FULL_ZERO` IDs, both unstarted, with exact settings,
  current binary hashes and strict-intake instructions. Corrected one-week
  datasets are retained for both engines. No Django changes or latency comparisons
  were added. Genuine startup/other feature gaps remain explicit.
- D08 cleanup removes 138 owned S1-S4 comparison/test exports totaling
  2,358,030,442 bytes, after recording paths and hashes. Operator files retain
  sizes/mtimes; accepted year hashes still match. S5 manual-follow-up references,
  current model examples, raw history and private handoff/evidence remain.
  Exact inventory/disposition: `s5/dataset-cleanup-{inventory,receipt}.json`.
- Ten additional exact raw-byte/prefix comparisons pass. Final source/EX5,
  generated schema, manual full settings, ignores, whitespace and 82 local
  links/anchors pass; AGENTS remains 133 lines / 8,189 bytes. A further 20
  temporary D11 datasets totaling 144,361,955 bytes are removed after their
  dependent checks. The two corrected one-week examples retain every accepted
  file hash. Receipts: `s5/final-validation.json` and
  `s5/readiness-cleanup-{inventory,receipt}.json`. All automatic queues are empty.
  D11 reuses the pinned profiling/testing guidance and scoped graph: only an
  existing helper body changes, with the include/call topology confirmed unchanged.
