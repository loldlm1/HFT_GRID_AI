# Plan: EURUSD Tester Reliability And Deep-State Performance

**Generated**: 2026-09-10
**Status**: Executing Sprint 1; required decisions resolved
**Execution authorization**: The user authorized ordered execution of Sprints 1-4, including validation and one commit per sprint. Stopping the affected tester and removing its current V13 data if necessary remain separately authorized; the stopped data is preserved.
**Proposal**: Not requested; direct Planner plan with questions.
**Estimated complexity**: High; failure handling crosses broker bookkeeping, research lifecycles, tester completion and state indexing.

## Overview

Make export failures visible and promptly terminate invalid Strategy Tester runs,
release confirmed closed broker state independently of export success, and reduce
the normal deep-processing cost without changing strategy or research semantics.
Measure compiler targets after the algorithm changes, using the same source and
representative inputs. Full-history EURUSD acceptance remains a separate operator
gate, as requested.

The planning baseline is `c9ebb24a28276a42a72d33970f941ac37507ead5` on
`bot/pivot_points_fractal`. The worktree was clean before this plan was created.
The completed cleanup plan and its completed hook state are historical; do not
restart them. This is the sole new current plan. Retire the old plan and update
its index navigation in Sprint 1, after preserving its Git recovery reference.

### Discovery And Already-Authorized Containment

| Evidence | Consequence |
| --- | --- |
| XAUUSD completed in 7:43:11.625 with 332,994,255 processed ticks; EURUSD has only 168,825,623 prepared source ticks. | Raw tick volume does not explain the observed slowdown. Match intervals and settings for benchmarks rather than compare different symbols' total elapsed times. |
| EURUSD export files stopped growing at about 19:22 CEST on September 9, near simulated November 14, 2017, while broker simulation continued into May 2019. | Suspected failed export; identify the first actual error before claiming its initiating cause. Buffered table tails are not exact failure clocks. |
| `FinalizePivotSignalTerminalStates()` removes closed signals only after parity/outcome export succeeds. Those operations fail when `PivotV13Ready()` is false. | Confirmed cleanup dependency can retain closed signals indefinitely. The broker signal array has no historical-state bound. |
| Commit `65090dc` added a deep-link scan for each closed signal; the scan is reached on repeated finalization attempts. | The fix can amplify the retained-state workload. It is not yet proven to have triggered the first failure. |
| Export failure diagnostics require debug switches, both disabled in this run. | Absence of a journal error is not evidence of a healthy export. Capture the first error unconditionally. |
| The active run loaded the same tester payload as the retained post-fix AVX2 build. Today's later binary targets X64 Regular. | The later Regular build did not cause this already-running test. Pin each future target and binary explicitly. |
| The host exposes AVX2 and AVX512 CPU flags; MetaEditor build 6184 accepts target selection. | AVX512 execution and benefit under MT5/Wine still require a tester comparison. |
| Native Stop was clicked at 14:27:05 CEST on September 10; the journal records the stop and subsequent CPU sampling is 0%. | The affected run is stopped. This was containment, not an implementation validation run. |

Before stopping, all twelve TSVs, totaling 3,550,345,678 bytes, were preserved
with a hash receipt. The original run and backup remain; no data was deleted.
The original `run_summary.tsv` still contains only its header. Do not label this
run accepted, naturally completed, or recoverable by the existing censor-clock
repair, which requires a compatible sealed source.

Evidence lives in ignored `.codex-artifacts/eurusd-tester-failure-20260910/`:
`before-stop-receipt.json`, `before-stop/EURUSD_Exness_2015/`,
`stop-receipt.json`, and `mt5-before-stop.png`. Preserve these artifacts.

## Scope And Decision Record

| Decision | Accepted resolution and source |
| --- | --- |
| D1 / Q1 | User selected A: record the first export/integrity failure and stop the Strategy Tester. Live broker handling remains independent of research failure. |
| D2 / Q2 | User selected B: include normal deep-loop and lookup refactoring, in addition to the failure fix and compiler benchmarks. |
| D3 / Q3 | User selected B: focused tests and representative performance runs complete this implementation's validation. A full-history EURUSD rerun remains a separate operator gate. |
| D4 / containment | User explicitly allowed stopping the active run and removing current V13 data if required. Stopping is complete; deletion is unnecessary. This does not authorize deleting other runs, source ticks, recovery artifacts or shared terminal folders. |
| D5 / execution | The user subsequently authorized execution of Sprints 1-4 in order, validating and committing each sprint before advancement. |
| D6 / ownership | One agent and writing session; no delegation, remote Git writes, global Codex/plugin changes or live rollout. |

**Pending required decisions**: None. The precise initiating error is an
engineering investigation task, not a silently assumed product decision.

**In scope**: first-failure evidence, tester stop/completion behavior, independent
broker bookkeeping cleanup, research failure teardown, correction of the proven
initiating producer defect, deep-state lookups/counters/compaction/snapshots,
compiler target comparison, focused validation and existing guide updates.

**Non-goals**: strategy changes; new public inputs; live broker controls or live
testing; modifying broker SL/TP; altered lot sizing, tick history or symbol
specifications; new schema/feature/header versions; retrospective timestamp
rewriting; offline model changes; a general Python validator rewrite; full-history
reruns during these sprints; new MQL5 harnesses/test EAs/scripts, CI or test
infrastructure; compiler/terminal upgrades; global compiler preference changes.

**Fixed contracts**: preserve EA property version 1.30 and schema 13; H1/M10/M3
ordering; previous completed broker candles; first-consumption identities; H1
terminal transitions before deep discovery; exact confirmed broker parent close
clocks; eight H1 lanes and three shared deep ratios; frozen parent membership;
existing capacities; immutable broker protection and the sole structural 1R send
owner; exact twelve-file output and explicit nonbinary exclusions. A valid
`CAPACITY_REJECTED`, `NOT_TRIGGERED`, ineligible outcome or incomplete feature
snapshot is not automatically a fatal export failure.

**Safe assumptions**: retain the existing environment and local helpers; use
unique run IDs and sequential local tests; use optimized AVX2 as the comparison
baseline; accept AVX512 only on measured, equivalent behavior. Fault injection
touches only a disposable run created for that check. Preserve the current failed
EURUSD data unless a concrete storage need makes its authorized removal useful.

## Named Resources

| Responsibility | Files/resources |
| --- | --- |
| Entry events, stop and completion | `HFT_Grid_AI.mq5`: `OnInit`, `OnTick`, `OnTradeTransaction`, `OnTester`, `OnDeinit`, `PivotRunCompletionStatus`. |
| Export failure, buffers and seal | `services/trading_signals/pivot_fractal_statistics_export.mqh`: readiness/failure functions, file helpers, row queues, parity links, summary and teardown. |
| Broker state ownership | `services/trading_signals/pivot_signal_lifecycle.mqh`, `pivot_signal_state.mqh`, `execution_controller.mqh`, `execution_broker_reconciliation.mqh`. All are under `services/trading_signals/`. |
| Deep state and hot path | `services/trading_signals/deep_pivot_lifecycle.mqh`, `deep_pivot_signal_struct.mqh`; H1 parent lookups in `pivot_trial_matrix_state.mqh`, `pivot_trial_matrix_lifecycle.mqh`, `pivot_trial_matrix_struct.mqh`. |
| Include and configuration contracts | `services/trading_signals.mqh`, `services/trading_management/pivot_fractal_engine_config.mqh`, `services/trading_management/ea_inputs.mqh`; reference changes only where the selected implementation requires them. |
| Maintained validation | `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`, `tests/fixtures/schema_v13_hft_deep_pivot_features/`, `tests/fixtures/schema_v12_pivot_signal_features/`, `build_dataset.py`, `parent_chronology.py`, `schema_contract.py` under `tools/deterministic_signal_ml/`. Reuse them without adding a harness. |
| Existing guide owners | `AGENTS.md`, `README.md`, `docs/README.md`, `docs/architecture/market-data-broker-executor.md`, `docs/environment/mt5-agentic-workflows.md`, `tools/deterministic_signal_ml/README.md`. Update only the owners affected by a sprint. |
| Historical evidence | `docs/research/parent-close-chronology-acceptance-2026-09-09.md`, `docs/research/pivot-fractal-v13-producer-acceptance-2026-08-31.md`, `docs/research/exness-xauusd-run-verification-2026-09-09.md`; preserve their dated claims. |
| Compile receipts/binaries | `.codex-artifacts/parent-close-chronology-20260909/metaeditor-compile.json`, `.codex-artifacts/project-guidance-cleanup/compiled-binary.json`, `.codex-artifacts/project-guidance-cleanup/HFT_Grid_AI-before.ex5`. |
| New private execution evidence | `.codex-artifacts/eurusd-tester-reliability/sprint-1/` through `sprint-4/`; receipts, settings, comparisons, source/binary pins and operator handoff. No extra files inside a strict run. |
| Native execution | `C:\MetaTrader 5-1\MQL5\Profiles\Tester\`, tester agent/journals under `C:\MetaTrader 5-1\Tester\`, existing MetaEditor and MT5 MCP servers. |
| Source data | Existing `EURUSD_Exness_2015` and `XAUUSD_Exness_2015` custom symbols; retained inputs under `/home/admin/Documents/Exness_Tick_Data/`. Do not reimport or modify them. |

Read applicable `AGENTS.md` and the loaded MQL5/Token Saver skills at execution.
The runtime and environment guides remain authoritative for their boundaries.

Official documentation retrieved during discovery/planning on September 10:

- [TesterStop](https://www.mql5.com/en/docs/common/testerstop?print=1): it is normal tester completion and still calls `OnTester()`; failure labeling must be explicit.
- [OnDeinit](https://www.mql5.com/en/docs/event_handlers/ondeinit?print=1): event and deinitialization contracts. Do not rely on a forced stop or crash to persist the first failure.
- [Compilation and processor targets](https://www.metatrader5.com/en/metaeditor/help/development/compile): maximum optimization is separate from target selection; unsupported CPU targets fail to load, and AVX512 has deployment restrictions.

## Prerequisites And Shared Validation

Before execution, inspect branch/worktree ownership and existing plan state.
Retain the current binary and exact source/include hashes before any source edit.
Do not assume the current Regular binary is the binary used by the stopped run.
Confirm no other tester is running and no live attached EA would reload from a
compile; use an isolated snapshot of the actual EA if that is necessary to keep
testing separate. Do not detach, replace or restart a live instance.

Resolve the loaded Planner's `references/execution-state.md` and initialize this
plan's state only after execution is authorized. Preserve the completed cleanup
handoff rather than treating it as an active sprint. All checks below are future
execution gates; planning has not run them.

### V1: Static, Boundary And Existing Contract Checks

Run each source sprint's exact identifier/caller sweep and include trace. Verify
all new references after state relocation, callbacks and teardown; no stale
index, cycle, sibling re-include, unbounded history scan or new order mutation.
Review the sole `OrderSend` path and absence of `TRADE_ACTION_SLTP`, trailing,
partial close, retries and research-driven broker gates. Preserve all headers.

```bash
git diff --check
rtk git diff --stat
rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root tools/deterministic_signal_ml/tests/fixtures --run-id schema_v13_hft_deep_pivot_features --validate-only
```

Reuse passing Python results if their code, fixtures and contract inputs are
unchanged. Source/include changes still require their own static and compile
gates. No unrelated Exness pipeline tests or dependency reinstalls are needed.

### V2: Native Compile And Binary Pin

Discover the live schemas and call MetaEditor `get_workspace_info` before other
MetaEditor operations. Compile the actual EA with `compile_file`, an explicit
`target` and `no_optimization=false`. Use AVX2 through Sprint 3. Require
`0 errors, 0 warnings`, regenerated EX5 metadata, SHA-256, source/include mapping,
compiler build, target and exact request arguments in the sprint receipt.
Use the existing `tools/mt5/compile_mt5.py` fallback only if MCP cannot execute;
record the reason and verify the actual target rather than silently accepting
Regular. If the fallback cannot produce the required target/evidence, this gate
is blocked. Do not amend a commit to replace its binary evidence.

### V3: Native Tester Recipe And Settings

Preflight MT5, then use discovered `tester_prepare_config` and
`tester_run_backtest` with absolute `.ini`/`.set` paths under
`C:\MetaTrader 5-1\MQL5\Profiles\Tester\`. Name each pair
`eurusd-reliability-s<SPRINT>-<CASE>-<TARGET>-<REPEAT>`; archive the exact settings
and returned tester job ID outside the run directory. Use `wait=false`, then
query status/report and stop only that job if a guard fires. A tool wait timeout
does not stop a tester run. Do not issue a second Stop against a completed job.

Poll at 15-30 second intervals and retain each job ID. Use a 30-minute wall-clock
guard for routine focused/benchmark passes and a three-hour guard for the
optional incident prefix. At a guard, explicitly stop the matching active job,
retain its evidence and mark that check incomplete; do not silently lengthen
the run or interpret the tool's timeout as completion. These are investigation
bounds, not performance promises or a full-history execution budget.

Settings: `model="real ticks"` (`Model=4`), chart M3, H1/M10/M3 inputs,
`Broker_Session=EXNESS_SESSION`, reference-balance lot mode, `Lot_Strategy_Size=0.001`,
50 ms delay, USD 1,000,000 simulated deposit, 1:10000 simulated leverage,
optimization/forward/visualization off and normal profit calculation. Both debug
switches are off unless a specific diagnostic pass requires them. Export is on
except for the matched export-off cases. These are simulated tester settings,
not instructions to modify the connected trading account.

Use unique export IDs `EURUSD_Reliability_S<SPRINT>_<CASE>_<TARGET>_<REPEAT>` or
the corresponding XAUUSD prefix. Reuse the same settings and source data on each
side of a comparison. Record actual start adjustments and processed ticks/bars.

### V4: Focused Runtime And Semantic Matrix

| Case | Initial requested interval, end exclusive | Purpose |
| --- | --- | --- |
| E-FAIL | EURUSD, 2017-11-01 to 2017-11-16 | Reproduce and then cross the observed failure neighborhood. Extend warm-up only when required by retained parent state. |
| X-PARITY | XAUUSD, 2015-08-11 to 2015-08-15 | Existing parent-close example; compare corrected export-on/off broker behavior and exact censor clocks. |
| E-STRESS | EURUSD, 2016-06-20 to 2016-06-28 | Representative FX stress and deep-parent churn. |
| X-STRESS | XAUUSD, 2020-03-09 to 2020-03-21 | Representative metals stress and deep fan-out. |
| E-DST / X-DST | EURUSD, 2024-03-04 to 2024-03-18; XAUUSD, 2024-03-18 to 2024-04-02 | US/UK analysis-time transitions with unchanged broker causality. |

First establish E-FAIL and X-PARITY. Freeze the representative benchmark windows
and their measured state peaks before optimizing; use stress passes to verify
that they exercise meaningful fan-out. A short run does not reconstruct parents
from earlier history. If necessary, reproduce from the original August 2015
start only through November 16, 2017, with a stop guard; this bounded prefix is
an incident reproduction, not the deferred 2015-2026 full-history gate. If it
cannot isolate the cause, report the unresolved gate and do not invent a fix.

For successful focused outputs run the existing strict validator and chronology
audit, substituting the actual `RUNS_ROOT`, `RUN_ID` and external `REPORT` path:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root "$RUNS_ROOT" --run-id "$RUN_ID" --validate-only
.venv/bin/python tools/deterministic_signal_ml/parent_chronology.py --runs-root "$RUNS_ROOT" --run-id "$RUN_ID" --memory-limit-mb 4096 --report "$REPORT"
```

Require successful seals, zero unexpected integrity errors, all twelve headers,
exact H1/deep ratios and membership, correct midpoint rollover/touch/no-touch,
parent close/run-end censors, same-second duration and explicit ineligible states.
Compare every native-grain field and ordered broker event stream. Normalize only
documented run identifiers/path metadata and measured execution timings outside
the TSV facts; do not normalize prices, money, causal clocks, labels or membership
to conceal differences. Tickets and IDs must match when the tester produces them
deterministically; explain any unavoidable external identifier mapping explicitly.

The strict validator materializes rows. Bound focused intervals so full semantic
validation fits this host. Chronology-only results on a larger diagnostic prefix
do not become full semantic acceptance. Require complete dependency slices for
strict incident-case validation if that prefix is too large.

### V5: Failure Injection And Shutdown

Use the real EA and existing tester. After a fresh disposable export initializes,
back up then invalidate the header of that run's `virtual_outcomes.tsv` before
its next flush. Trigger an observable `HEADER_MISMATCH`; restore nothing while
the producer is running. Preserve the intentionally failed output and external
fault receipt, and verify rejection by the maintained validator. Repeat with
debug logging off; test an unavailable export file/destination separately to
exercise the original I/O failure branch, including best-effort diagnostics.
Never inject faults into the original EURUSD run, its backup, source ticks, or
an accepted XAUUSD/recovered run.

Require one primary unconditional diagnostic with first operation/error, run,
broker time and bounded state counts; preserved first cause during teardown;
one queued tester stop after safe event-boundary handling; and a `FAILED` export
seal with `CENSORED` completion when writable. Otherwise absence of a valid seal
plus the first journal diagnostic must clearly invalidate the run. `OnTester()`
must not set natural completion or return a successful custom score for a failed
run. Export-off and valid exclusion/capacity rows must not trigger this stop.

Exercise several real/virtual parent closures around failure and review cleanup
postconditions before stop. For the live continuation branch, require static
control-flow proof and shared cleanup coverage; this plan authorizes no live/demo
account mutation to test failures. Record that operational limitation explicitly.

### V6: Performance Method

Measure native elapsed time, processed ticks, ticks/second, tester CPU/RSS,
export bytes/rows, state peaks and bounded operation counters where useful.
Counters must not create per-tick logs or change TSV headers. Benchmark with
debug/file logs and profilers off, one tester pass at a time and comparable host
load. Separate diagnostics from performance measurements.

Use one unmeasured warm-up and three measured repetitions for the frozen E-STRESS
and X-STRESS workloads; alternate baseline/candidate order to reduce host/cache
bias. If a pass is too short for useful timing, extend the fixed window before
comparison. Record medians and min/max spread. The optimization gate requires
equivalent results, no repeatable regression over 5% on the representative cases,
and an improvement on at least one stressed case exceeding both 5% and observed
repeat variability. Aim for at least 15%; it is a target, not a claimed result.
If variation obscures a result, investigate host load or repeat only the ambiguous
comparison. Remove complexity that provides no measurable benefit.

### V7: Documentation And Sprint Commit

Validate relative links/anchors, current plan ownership, requirement coverage,
source/binary pins and ignored paths. Keep `AGENTS.md` at most 160 lines / 8 KiB;
replace or shorten existing wording rather than append beyond its current budget.
Only `docs/README.md` owns changing project status. Record residual gates honestly.
Review staged paths and `git diff --cached --check`; stage no private data,
diagnostics, logs, binary, settings file or hook state. Commit exactly once per
sprint, record the SHA and rollback parent, then advance. No amend or history
rewrite; a failed gate keeps the current sprint open.

## Sprint 1: First-Failure Evidence And Tester Stop

**Goal**: An invalid research run stops visibly and cannot masquerade as natural
completion; the initiating EURUSD failure is isolated with retained evidence.
**Dependencies**: prerequisites, D1-D3 and retained containment evidence.
**Tracked scope**: entrypoint; export/error paths and research-integrity callers
in the named signal modules; affected guide owners; this plan; retirement of
`project-guidance-cleanup-plan.md` after navigation/recovery migration.
**Commit**: `fix(v13): surface research failures and stop invalid tester runs`
**Rollback point**: record pre-Sprint-1 HEAD and matching source/binary receipt.

### Task 1.1: Pin Baselines And Migrate Plan Navigation

- **Location**: existing compile receipts, native tester settings/journals, private `sprint-1/` evidence and `docs/README.md`.
- **Dependencies**: execution authorization, worktree ownership and the retained containment receipts.
- **Work**: retain the stopped-run and current-source binaries separately; pin a same-target AVX2 baseline and successful X-PARITY output before changing behavior. Preserve the old plan through `git show c9ebb24a28276a42a72d33970f941ac37507ead5:project-guidance-cleanup-plan.md`; migrate unique current facts and update navigation before retiring it.
- **Acceptance**: source/target/input provenance and baseline X-PARITY output are unambiguous; there is one current plan and the old plan remains recoverable from Git.
- **Validation**: V1-V3, the baseline X-PARITY portion of V4, and V7. First-error reproduction follows Task 1.2's observability change.
- **Rollback**: restore the matching binary if changed; Git recovery retains the completed old plan. Never overwrite the stopped-run snapshot.

### Task 1.2: Latch Failure And Request A Tester-Only Stop

- **Location**: `pivot_fractal_statistics_export.mqh`, integrity mutation/caller paths in the named H1/deep modules, and `HFT_Grid_AI.mq5`.
- **Dependencies**: Task 1.1's baseline pins.
- **Work**: retain the first cause before cleanup can overwrite an error code; emit one unconditional journal diagnostic independent of debug switches. Retain bounded failure context in memory and, when writable, a best-effort sidecar at `Common\Files\PivotFractalV13\diagnostics\<run_id>.failure.txt`, outside the strict twelve-file directory. Diagnostic failure must not recurse.
- **Work**: detect all fatal export/integrity paths, including missing files and bare research failure flags; queue stop only under `MQL_TESTER` with export enabled. Process the request at a safe event boundary, not recursively inside file/array/broker callbacks. Valid exclusions and atomic capacity-rejection rows remain normal output.
- **Work**: keep failure latched through `OnTester`, `PivotRunCompletionStatus`, summary writing and deinit. Preserve existing headers and emit `FAILED`/`CENSORED` when sealing is possible; keep failure teardown bounded and do not retry the irrecoverable exporter for every retained row.
- **Acceptance**: first cause is never replaced by secondary teardown errors; one stop request is made; automatic stop cannot produce acceptable natural completion or a successful custom score. No live order/session/permission path depends on the research failure or diagnostic write.
- **Validation**: V1, V2 and V5 with both logging switches off; inspect all failure-call sites and reference/include ordering.
- **Rollback**: revert this sprint and restore its matching pre-sprint EX5; sidecars remain evidence, not replay input.

### Task 1.3: Isolate The First Error And Validate The Policy

- **Location**: E-FAIL/native tester evidence, first-failure capture and producer branch, `AGENTS.md`, runtime/environment guides and `docs/README.md`.
- **Dependencies**: Task 1.2's compiled first-failure/stop behavior.
- **Work**: run the staged E-FAIL reproduction and identify its first failure and causal state, distinguishing producer logic from I/O/environmental cause. Retain compact error context and affected parent/trial identities. Verify automatic-stop/failed-seal rejection and document the accepted tester-only policy.
- **Acceptance**: the first cause is isolated, or this sprint remains blocked rather than guessing a repair. Strict tooling rejects failed/unsealed output; healthy X-PARITY and export-off behavior remain valid.
- **Validation**: V1-V5 and V7. Record the initiating error and any remaining repair as Sprint 2's explicit input.
- **Rollback**: pre-sprint code/binary restore; retain incident/fault evidence and historical documentation claims.

**Sprint 1 gate**: Tasks 1.1-1.3 and their validations complete; first cause
isolated; residual risks recorded; exactly one proposed sprint commit; commit and
rollback parent recorded before starting Sprint 2.

## Sprint 2: Independent Cleanup And Producer Correction

**Sprint 1 investigation input**: native E-FAIL reproduces a parity rejection
at 2017-11-14 07:18:42, broker `broker_9838823830189424876`: accepted request risk
29 points versus the research minimum of 30 (spread 29, stops/freeze zero).
Keep broker guards and submitted prices unchanged; preserve the computed
research-distance eligibility fact while removing its veto on accepted-request
parity. Strict intake additionally exposes lossy decimal serialization of PP
comparison evidence; preserve the actual numeric facts and causal comparisons,
without changing schema/headers or relaxing validation.

**Goal**: Confirmed closed broker state is released without waiting for export,
and the proven initiating defect is corrected without fabricating research facts.
**Dependencies**: committed Sprint 1 and its isolated first-error evidence.
**Tracked scope**: `pivot_signal_lifecycle.mqh`, `pivot_signal_state.mqh`,
`deep_pivot_lifecycle.mqh`, export and H1/parity lifecycle modules; the exact
producer location identified by Sprint 1; affected guide owners and this plan.
**Commit**: `fix(v13): decouple broker cleanup from research export failures`
**Rollback point**: Sprint 1 commit and its pinned AVX2 binary.

### Task 2.1: Separate Broker Ownership From Export Delivery

- **Location**: broker finalization/reconciliation, `RecordDeepPivotBrokerParentClose`, parity finalization and outcome export.
- **Dependencies**: committed Sprint 1 and its failure evidence.
- **Work**: copy authoritative confirmed close facts to existing research links before removing the broker signal. On research failure, release closed broker bookkeeping without waiting for parity/export recovery; retain genuinely open or unresolved broker state. Prevent repeated deep-link scans for the same completed handoff.
- **Acceptance**: closed-history size cannot drive future tick work; cleanup requires no new entry restriction, broker-position cap, close, resize, retry or protection modification. Healthy exports still get exactly one broker outcome and exact parity shadow.
- **Validation**: V1-V5; ordered broker-event/export-on/off parity; assert and record the closed-state cleanup postcondition at bounded lifecycle boundaries.
- **Rollback**: restore Sprint 1 code/binary; do not restore corrupted output as valid input.

### Task 2.2: Bound Failed Research Teardown And Repair The Proven Trigger

- **Location**: export buffers/pending origins/parity links, H1/deep state cleanup and Sprint 1's identified producer branch.
- **Dependencies**: Task 2.1's independent broker cleanup and the proven first cause.
- **Work**: stop research retries and admission after a fatal failure, release its state once while retaining first-failure/peak evidence, and keep broker continuation independent. Fix the proven trigger at its owning boundary; handle transient I/O by explicit failure rather than broad retries or fabricated success.
- **Acceptance**: no stale state growth after failure; no repeated full-array teardown each tick; a normal run crosses E-FAIL with valid export and no integrity stop. Parent/run censors, zero-second duration and binary labels remain exact. A proposed change to strategy, schema or causal meaning requires a new scoped decision before dependent edits.
- **Validation**: V1-V5; normal E-FAIL, fault injection, explicit successful exclusions, multiple-parent close/run-end cases and restart with a fresh run ID.
- **Rollback**: restore the Sprint 1 source/binary pair; preserve first-error reproduction and fixed-run outputs separately.

### Task 2.3: Freeze The Corrected Performance Baseline

- **Location**: native representative cases and private `sprint-2/` receipts; `docs/README.md` and runtime guide.
- **Dependencies**: Tasks 2.1-2.2.
- **Work**: run the successful focused matrix, freeze E-STRESS/X-STRESS settings and measured active-state distributions, and pin the corrected AVX2 source/binary as the sole baseline for algorithm optimization.
- **Acceptance**: representative strict/chronology checks pass, export-on/off broker events match and fault cases stop/reject correctly. Live failure behavior has only the authorized static/shared-path evidence; no live acceptance claim.
- **Validation**: V1-V7. Keep sufficient normal/export-off evidence for comparison without repeating unrelated historical checks.
- **Rollback**: use the Sprint 1 commit/binary; keep all distinct run evidence.

**Sprint 2 gate**: Tasks 2.1-2.3 and their validations complete; corrected
baseline and residual risks recorded; exactly one proposed sprint commit; commit
and rollback parent recorded before starting Sprint 3.

## Sprint 3: Optimize Normal Deep-State Processing

**Goal**: Remove repeated deep-state searches and copying while preserving every
observable broker/research result on the frozen representative workloads.
**Dependencies**: committed Sprint 2 and its corrected AVX2 baseline.
**Tracked scope**: `deep_pivot_lifecycle.mqh`, `deep_pivot_signal_struct.mqh`,
the named H1 state/lifecycle structures and narrow broker-state lookup support;
aggregator declarations only if necessary; existing documentation owners.
**Commit**: `perf(v13): reduce deep-state lookup and lifecycle scan costs`
**Rollback point**: Sprint 2 commit and pinned corrected AVX2 binary.

### Task 3.1: Add Bounded Internal Associations

- **Location**: `FindDeepPivotParentLink`, `FindDeepPivotTrial`, event lookup, `DeepPivotParentStillActive`, and owning state structures.
- **Dependencies**: committed Sprint 2 and its frozen corrected baseline.
- **Work**: use bounded indices/associations to resolve outcome-to-link/trial/event and parent activity without repeated whole-array string searches and full struct copies. Prefer existing arrays and compact scratch/index state over a new generic container. Account for duplicate/collision checks, allocation failure and all reset/removal paths.
- **Acceptance**: serialized IDs and output schemas are unchanged; no stale slot can reference a reused identity. An index is invalidated/remapped with its owner, and partial allocation rolls back atomically. All caps retain their existing meaning.
- **Validation**: V1-V4; trace every array mutation/copy/reset site; verify multi-event churn, all terminal paths and existing capacity contracts. State associations must be checked before use.
- **Rollback**: revert this sprint as a unit; never mix old removal code with new stored indices.

### Task 3.2: Replace Repeated Outcome Scans And Element Shifts

- **Location**: `ResolveDeepPivotActiveOutcomes`, `RefreshDeepPivotTerminalFlags`, `ReleaseTerminalDeepPivotState` and `RemoveDeepPivot*At` helpers.
- **Dependencies**: Task 3.1's association/remap contract.
- **Work**: maintain or derive trial/link/event active counts in a bounded pass, cache same-tick parent activity once per parent/link, and compact terminal groups in stable passes instead of shifting the entire array per removed element. Preserve the original outcome traversal/export order; update index remaps together.
- **Acceptance**: no unconditional trial/link/event-by-all-outcomes recount remains on every tick; terminal release is bounded by retained state plus removed rows. Do not retain resolved rows longer or release them earlier if that changes admission capacity, peak accounting or output. Once a parent closes, unresolved children censor at its exact retained time.
- **Validation**: V1-V6 against Sprint 2; exact normalized native-row/broker stream comparisons, zero unexpected duplicates/references, active-count reconciliation and stress peaks.
- **Rollback**: restore Sprint 2 code/binary; preserve the regression diff if any gate fails.

### Task 3.3: Build Parent Snapshots Once And Verify The Gain

- **Location**: `CollectDeepPivotParentSnapshot`, `DeepPivotParentCandidateDuplicate`, `ProcessDeepPivotTick` and snapshot storage.
- **Dependencies**: Tasks 3.1-3.2 and their equivalence checks.
- **Work**: collect eligible buy/sell parents in one bounded pass, avoid redundant struct copies and quadratic duplicate probes, and reuse appropriately reserved scratch storage. Do not cache parent eligibility across ticks unless every membership/eligibility change has explicit invalidation. Compute age at the event trigger and freeze each event's parent set before discovery.
- **Acceptance**: no retroactive parents or broker-parity substitution; H1 terminal/entry ordering and all same-tick facts match Sprint 2. Delete frozen-parent copies or helpers only after equivalence/non-use proof. Meet V6's improvement/no-regression gate before retaining added complexity.
- **Validation**: V1-V7; full focused semantic matrix, export-on/off parity, fault stop regression, fixed-window benchmark medians/spread and reviewed source complexity evidence.
- **Rollback**: restore Sprint 2 source/binary and retain measured comparisons; do not promote a faster but behaviorally different candidate.

**Sprint 3 gate**: Tasks 3.1-3.3 and their validations complete; equivalent
outputs and measured benefit recorded; exactly one proposed sprint commit;
commit and rollback parent recorded before starting Sprint 4.

## Sprint 4: Compiler Selection And Bounded Acceptance

**Goal**: Select and pin a validated optimized target, close the focused
reliability/performance gates and hand off the deferred full-history gate.
**Dependencies**: committed Sprint 3 and stable optimized-source behavior.
**Tracked scope**: existing environment/runtime/index guides and this plan;
only compiler-discovered source issues that are necessary for this scope may
reopen affected source validation. No global settings or toolchain upgrades.
**Commit**: `docs(v13): record compiler benchmarks and bounded tester acceptance`
**Rollback point**: Sprint 3 commit and pinned AVX2 binary.

### Task 4.1: Compare Regular, AVX2 And AVX512 On Identical Source

- **Location**: native `compile_file`, tester cases and private `sprint-4/` binary/settings/benchmark receipts.
- **Dependencies**: committed Sprint 3 and its source/AVX2 pin.
- **Work**: explicitly compile `x64`, `AVX2` and `AVX512` with `no_optimization=false`; record exact source, target, compiler build and EX5 hash/size. Verify AVX512 loading on a short local tester pass before longer comparisons. Run V6 on supported candidates with the same inputs and correct source baseline.
- **Acceptance**: selected candidate has equivalent broker events and strict research facts; no relaxed rounding/clock tolerance. Prefer AVX2 when timings are within variability. Promote AVX512 only if it loads, validates and improves beyond noise. An unsupported/non-equivalent/slower AVX512 candidate is a recorded rejection, with AVX2 as the supported fallback.
- **Validation**: V2-V6; distinguish algorithm gains from target gains and warm-up/synchronization costs. Record target-specific unavailable checks honestly.
- **Rollback**: restore the pinned Sprint 3 AVX2 EX5 and receipt; do not alter MetaEditor's global preference to perform the experiment.

### Task 4.2: Pin The Final Candidate And Recheck Changed Inputs

- **Location**: intended EA binary, source hash mapping, focused tester outputs and first-failure diagnostics.
- **Dependencies**: Task 4.1's supported-target comparison and selection.
- **Work**: leave one clearly identified final binary/target and matching source receipt. Reuse valid passing evidence, and run only the additional focused/fault/parity checks needed for the selected target or any intervening source change.
- **Acceptance**: zero compiler errors/warnings; selected binary is the one tested; successful focused outputs seal and validate; injected failures stop and cannot be accepted; no unreviewed implementation changes or source/receipt mismatch.
- **Validation**: V1-V7 as applicable to changed inputs; verify staged paths and all retained rollback pairs.
- **Rollback**: restore Sprint 3's binary/source pair and document the rejected candidate without deleting its evidence.

### Task 4.3: Update Existing Owners And Leave Explicit Operator Gates

- **Location**: `docs/README.md`, runtime/environment guides, `AGENTS.md` where critical wording changes, relevant V13 guide navigation and this plan.
- **Dependencies**: Task 4.2's final validation and matching source/binary receipt.
- **Work**: record actual first cause and correction, failure policy, measured workload/target results, tested binary/source hashes, limitations and exact operator rerun recipe. Keep dated XAUUSD/recovery evidence unchanged. Mark this plan complete only after its final sprint validation/commit; retain its commit ledger externally if the final SHA cannot be included in its own commit.
- **Acceptance**: full-history EURUSD, human chart/rendering, formal Exness broker equivalence and full recovered-run semantic validation remain separately visible. Focused results do not certify those gates or authorize rollout. Prepared tick data and original/recovered evidence remain intact.
- **Validation**: V7 and a final requirement-to-evidence review. No full 2015-2026 run is launched as a closeout shortcut.
- **Rollback**: restore Sprint 3 guide/binary state; retain the operator evidence and planning decisions.

**Sprint 4 gate**: Tasks 4.1-4.3 and their validations complete; final target
and bounded acceptance recorded; exactly one proposed sprint commit; final SHA
and rollback parent recorded before implementation closeout.

## Testing Strategy And Residual Risks

- **Contract tests**: reuse the existing strict V13 suite/fixtures, including V12 rejection, exact parent chronology, capacity fan-out and same-second clocks. Add no MQL5 harness or substitute fixture tests for actual EA execution.
- **Integration/E2E**: native focused real-tick runs, intentional disposable export faults, normal restart, broker export-on/off parity and complete focused semantic validation.
- **Performance**: same-source/target algorithm comparisons followed by same-source compiler comparisons; fixed windows, repeated medians, host/load evidence and unchanged outputs.
- **Safety/privacy**: tester-only stop, no account mutation, no extra broker send path, no credentials in receipts, isolated faulty data and fresh IDs. No live/deployment claim.
- **Accessibility/UI**: frontend behavior is out of scope; retain the outstanding human chart/rendering gate and existing nonvisual-tester chart guard.

| Risk | Mitigation and validation signal |
| --- | --- |
| Initial EURUSD error depends on long-lived parent state or external I/O. | Stage the reproduction/warm-up, preserve full stopped evidence and require an isolated first cause before declaring the defect repaired. Do not fabricate diagnosis from stale file tails. |
| `TesterStop()` invokes normal tester completion callbacks. | Failure remains latched through `OnTester`/deinit; explicit failed/censored seal, invalid score and strict rejection are V5 gates. |
| An unwritable destination prevents even the summary or sidecar. | Emit the primary journal message first; best-effort persistence, no recursive error reporting, and absence of a successful seal keeps the run invalid. |
| Clearing research state loses authoritative broker ownership. | Clear research-owned arrays only; preserve open/unresolved broker signals and prove terminal cleanup independence. No live failure test is claimed. |
| Compaction/index reuse changes parent membership, row order or capacity admission. | Stable compaction, complete remaps, identity checks, atomic reservation and exact old/new native-row comparisons. |
| AVX512 is unsupported under this VM/Wine or changes floating-point results. | Short load check, exact facts/parity and explicit target rejection; retain validated AVX2. |
| Benchmark noise or short intervals produce a false gain. | Warm-up, alternating order, three repetitions, spread-aware gates and fixed state-rich cases. |
| Focused runs miss later history-dependent behavior. | Full-history EURUSD remains an operator gate; no claim of long-run acceptance or ETA guarantee. |

## Rollback And Execution Order

Each sprint records its actual pre-sprint HEAD, source/include mapping and matching
EX5. Restore reviewed commits in reverse order using ordinary revert commits;
never reset/amend history or mix old source with a newer compiled binary. Before
restoring a tester binary, ensure its job is stopped and preserve its output.
Restoring a binary does not fix or reseal an existing failed dataset. No tick
imports, database migrations or global configuration changes require rollback.

On authorized execution, finish **Sprint 1 -> Sprint 2 -> Sprint 3 -> Sprint 4**.
For each sprint: implement only its scope, run and record its gates with actual
results, review residual risks, create exactly one sprint-specific commit, record
the rollback parent and binary pin, then advance. If a new required product
decision appears, record it through Planner execution-state handoff and continue
only independent work until answered. A status question does not restart a sprint.

The later full-history operator gate uses the selected binary, the same Exness
EURUSD inputs, a new run ID and requested interval 2015-08-10 to 2026-09-08,
end exclusive. It requires monitored export growth, no first-failure stop, natural
completion, reconciled warm-up/tick counts, capacity/state evidence and applicable
data validation. Its launch and acceptance are outside this plan's execution
completion criteria under D3; no live rollout follows automatically.

## Completion Checklist

- [x] Q1=A, Q2=B and Q3=B are explicitly answered and recorded.
- [x] Authorized incident stop and pre-stop preservation are recorded separately from implementation.
- [x] Execution is authorized and this plan's execution state is initialized.
- [ ] Sprint 1 first-error/stop gates pass; commit and rollback point recorded.
- [ ] Sprint 2 cleanup/correction gates pass; commit and rollback point recorded.
- [ ] Sprint 3 behavioral/performance gates pass; commit and rollback point recorded.
- [ ] Sprint 4 target/acceptance gates pass; commit and rollback point recorded.
- [ ] Final binary/source pins, evidence links and bounded acceptance agree.
- [ ] Full-history EURUSD and all unrelated operational gates remain explicit.
- [ ] Original data, retained recovery artifacts and operator handoffs are preserved.
