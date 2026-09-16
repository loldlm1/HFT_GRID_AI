# Plan: V14 MT5 Research Performance

**Generated**: 2026-09-16
**Readiness**: Ready for execution; no pending required decisions.
**Execution authorization**: User requested archive, planning and execution of all
optimization sprints, including the repository's validation/commit gates.
**Complexity**: High (behavior-preserving research lifecycle and persistence).

## Outcome And Scope

Reduce repeated Deep trial calculations, parent metadata copying and TSV export
work without changing any V14 research or broker fact. Keep schema 14, EA 1.40,
all twelve headers, numeric precision, both directions, feature capture, active
parent rules, shared ratios, link censor clocks, row order and failure handling.
Measure improvements against the exact accepted pre-optimization binary.

Archive the completed M1-M4 plan under
`docs/plans/archive/pivot-fractal-v14-mt5-plan.md`; preserve its original contents
except an archive annotation and corrected relative navigation. This document is
the sole current execution plan. The frozen producer handoff and independent
Django source remain historical accepted evidence, with a separate new build pin.
Changing status belongs only in `docs/README.md`; detailed execution receipts live
in ignored `.codex-artifacts/v14-optimization/`.

Out of scope: strategy changes, fewer features/parents/directions, new schema,
capacity changes, broker controls, new inputs, live rollout, Django implementation,
staging purge, new MQL5 harnesses/EA scripts, CI, broad or multi-year QA, GBPJPY
conversion repair, human chart acceptance and formal broker-feed equivalence.

## Decisions And Prerequisites

| Decision | Basis |
| --- | --- |
| New independent plan, preserve completed M1-M4 history | User accepted the recommendation and explicitly requested archive/execute. |
| Dataset equivalence is a release gate | User's explicit concern; speed never permits fact loss or relabeling. |
| QA H2/M15/M3 and defaults H1/M10/M3 | Existing accepted settings; no input/default changes. |
| Initial-2015 XAUUSD fallback | Accepted GBPJPY historical conversion diagnosis; recent GBPJPY is not a substitute. |
| Extra short busy window for scaling | Audit found greater event/parent density later in the operator run. |
| Four serial sprints, one writer | Repository policy; no delegated agents. |
| Preserve current operator run | It finished and sealed OK/NATURAL before this execution; no interruption needed. |
| No API/model/package upgrades | Local compiler, tester and Python environment already available. |

Starting branch `bot/pivot_points_fractal`, clean HEAD
`4586504d842f65ccde1b653c21aa77eab0355853`. Baseline AVX2 binary:
SHA-256 `423433befab4ecfb97a9685bfefda479d0a5acfe7d5d08ffaf0b03399b92be1b`,
308,334 bytes. Preserve it plus the completed Planner state before new execution.
Verify no attached EA and no active tester before compile/binary selection or a
new run. Use the established EA filename: earlier alternate binary paths did not
launch. Any baseline binary selection is temporary, while the tester is idle;
restore the current accepted binary before finishing.

## Resources

- `AGENTS.md`, `docs/architecture/market-data-broker-executor.md`,
  `docs/environment/mt5-agentic-workflows.md`, `docs/README.md`.
- `services/trading_signals/deep_pivot_lifecycle.mqh`: tick-scoped shared quote
  evaluation and refreshed eligible parent snapshots.
- `services/trading_signals/pivot_fractal_statistics_export.mqh`: bounded batches,
  column validation and checked file/header ownership.
- Existing structs/owners in `deep_pivot_signal_struct.mqh`,
  `pivot_trial_matrix_state.mqh`, `pivot_signal_state.mqh`, and
  `execution_lot_math.mqh` are inspection boundaries; change only if necessary.
- Existing `tools/deterministic_signal_ml/tests/`, `build_dataset.py`,
  `parent_chronology.py`, `pivot_fractal_audit.py`, schema/fixture registries.
- Retained M2/M3/M4 receipts under `.codex-artifacts/pivot-fractal-v14/` and the
  passive audit `.codex-artifacts/v14-long-run-audit-20260916/report.md`.
- Existing terminal/profile/common paths from the environment guide; fresh
  `v14-opt-*` settings under `MQL5/Profiles/Tester`, fresh `V14_OPT_*` export IDs.
- Official MQL5 references: [FileWriteString](https://www.mql5.com/en/docs/files/filewritestring),
  [FileWrite](https://www.mql5.com/en/docs/files/filewrite),
  [FileReadString](https://www.mql5.com/en/docs/files/filereadstring),
  [OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit).
  Official file API pages returned HTTP 403 during discovery. Use existing local
  API conventions and compile/native byte comparisons; do not assert an unverified
  encoding or partial-write assumption.

## Shared Validation And Commit Gate

Each sprint finishes its tasks, validates, records residual limits, creates exactly
one sprint commit, then records the commit SHA and rollback parent before advancing.
No amend/rewrite. Planner state is initialized only for this authorized execution
and updated at implementation, validation, commit, advance and completion.

Every sprint runs `git diff --check`, reviewed-path/reference sweeps, include
reachability/cycle checks, broker/research boundary review and documentation
link/anchor/ignore checks. Source changes require MetaEditor MCP preflight then
`compile_file(path=<absolute entrypoint>, no_optimization=false, target="AVX2")`,
0 errors/0 warnings and regenerated EX5 timestamp/size/hash. Preserve raw receipts
outside tracked source. No stale binary qualifies a new source change.

Existing focused contracts:

```bash
rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root <runs> --run-id <id> --validate-only
.venv/bin/python tools/deterministic_signal_ml/parent_chronology.py --runs-root <runs> --run-id <id> --memory-limit-mb 4096 --report <receipt.json>
```

Freeze XAUUSD_Exness_2015, real ticks, M3 chart, EXNESS_SESSION, 50 ms execution
delay, simulated USD 1,000,000 / 1:10000, reference size 0.01, debug/visualization/
optimization/forward off. Native cases: 2015-08-10 to 2015-08-15 for H2/M15/M3 and
defaults, plus 2017-03-13 to 2017-03-18 H2/M15/M3 (end exclusive). Inspect actual
manifest/settings and tick/bar totals, including identical warm-up shifts.

Compare all twelve TSVs in original row order with exact text/numeric values.
Only `run_id` and explicitly recorded run-specific provenance may normalize;
no timestamp, feature, outcome, price, membership, capacity or summary count
differences are permitted. Source/binary pins and performance metrics live in
sidecars. Compare ordered native broker journal messages and execution facts.
Strict validation and chronology supplement equivalence; they do not replace it.

Use fresh IDs, one tester job at a time and retained job IDs. Poll in bounded
intervals; a tool wait timeout never launches another job. Each focused case has
a 180-second execution guard; stop only the matching owned job if exceeded and
retain it as failed/unaccepted. Reuse passing checks only while inputs stay valid.

## Sprint P1: Archive And Freeze The Baseline

**Depends on**: verified clean starting checkout and idle tester.
**Commit**: `docs(mt5): archive V14 delivery and freeze optimization baseline`
**Rollback parent**: starting HEAD `4586504`; documentation only.

1. Move the completed plan to its archive path, correct links, update the index
   and preserve completed execution state and original file hash in P1 receipts.
2. Pin reachable source, binary, strict headers/fixtures and broker owners. Save
   native baseline runs for the three frozen cases and retain settings, rows,
   performance/resource observations and strict/chronology results.
3. Record operator run seal/peaks as passive baseline evidence only; its multi-year
   full semantic audit is outside this bounded optimization scope.

Acceptance: recoverable completed history, only one current plan, unchanged source
and binary, three valid sealed native baselines, reproducible comparison inputs.
Validate source/include hashes, archive equivalence and links, then commit P1.

## Sprint P2: Reuse Deep Work Without Changing Observation

**Depends on**: P1 validation/commit.
**Commit**: `perf(mt5): reuse shared Deep calculations and parent metadata`
**Rollback parent**: P1 commit, plus its saved matching EX5.

1. Evaluate shared trial quote/touch/profit at most once per invocation of the
   Deep resolver. Keep outcomes in existing order, check each parent first, and
   build link-specific identities/censors separately. Scratch state is capped,
   initialized on every observed tick and released on reset/failure; never reuse
   prices by serialized second or across ticks.
2. Recheck parent eligibility each tick, preserving pre-discovery freeze and
   virtual-then-broker order. Reuse immutable snapshot metadata only for a proven
   unchanged identity/source slot; rebuild changed members and truncate departures.
   Do not move discovery ahead of freezing or introduce cross-owner invalidation.
3. Run source review, compile, existing focused contracts and all three native
   comparisons/strict/chronology gates. Inspect same-tick exits, shared trials
   with different parent censor clocks, PP arming, capacity and compaction cases.

Acceptance: exact V14/broker equivalence and no stale-parent/price cache; report
measured timing without treating a single observation as a promised speedup.
Required failures block the P2 commit and advancement until fixed/retested.

## Sprint P3: Batch Export Work With Checked Persistence

**Depends on**: P2 validation/commit.
**Commit**: `perf(mt5): batch V14 TSV writes and reuse header counts`
**Rollback parent**: P2 commit, plus its saved matching EX5.

1. Keep the 256-row flush boundary and bounded memory. Encode/write a batch with
   exact existing ANSI/CRLF/tab/null/numeric bytes and original row order.
2. Reuse fixed header column counts and remove redundant row scans only after
   proving queued rows are immutable and validated. Keep missing-file and current
   header checks at every append; check failed writes and preserve first failure,
   tester-only stop, buffer/handle release and failed seal.
3. Compile and run three-case exact/native/strict/chronology QA. Reuse unchanged
   fixture evidence; inject missing-file and header faults only into new disposable
   owned runs with original files retained outside their twelve-file directories.

Acceptance: exact successful exports, checked faults rejected by strict intake,
no silent partial/corrupt successful seal, no descriptor growth or changed broker
control. Required failures block commit/advance.

## Sprint P4: Measure And Publish The Accepted Build

**Depends on**: P3 validation/commit.
**Commit**: `test(mt5): verify V14 optimization parity and performance`
**Rollback parent**: P3 commit; retain both original and final binaries.

1. On initial-2015 H2 and busy H2 cases, run a warm-up per build plus three
   alternating baseline/final measurements. Compare exact TSVs for every run;
   report medians and ranges rather than cherry-picked times. Treat under-5%
   median gains as inconclusive, never as a performance guarantee.
2. Verify final export-on/off broker parity for H2 and defaults, and a bounded
   sustained busy-window resource sample (CPU, RSS, descriptors, export/state
   peaks). Reuse earlier same-binary semantic/fault evidence. No multi-year replay.
3. Update existing runtime/environment/index owners with actual implementation,
   results, final source/binary/contract hashes, rollback and open gates. Keep the
   frozen M4 Django handoff intact; record new producer provenance separately.
4. Restore/select the final accepted EX5 while idle, validate links/ignores and
   unchanged consumer contract, record P4 commit and complete Planner state.

Acceptance: no dataset/broker differences, successful required seals and faults,
measured resource/performance evidence without regression, coherent current docs
and independent historical recovery. If a proposed change regresses materially,
remove it within its owning sprint before acceptance; never trade facts for speed.

## Risks And Rollback

| Risk | Mitigation and signal |
| --- | --- |
| Same-second quotes reused | Reset scratch every resolver call; preserve quote chronology; native exact comparison. |
| Parent closes while another survives | Parent checks precede cached shared result; link-specific censor tests and chronology. |
| Compaction changes indices | Cache lasts only before same-call compaction; snapshots validate identity and source slot. |
| Encoding/row drift | Twelve exact row-ordered comparisons; bounded batches; strict native validator. |
| Missed file faults | Check existence/current header each append, retain fault injection and failed intake gates. |
| Benchmark noise or changed workload | Frozen settings/tick totals, warm-ups, alternating repeated timings and ranges. |
| Long-run accumulation outside small QA | Bounded state/resource evidence; no universal no-leak or live-acceptance claim. |

Rollback reviewed sprint commits in reverse order using new revert commits; never
reset history or amend. Restore the matching retained EX5 (or recompile) with no
active tester/attached EA. No data migration is involved. Preserve every original,
failed and accepted run, historical handoff, operator file and global setting.
Human chart, formal Exness equivalence and full recovered-run semantics remain
separate open gates. Completion requires all four actual validation/commit gates;
this plan records intended checks, not claims that they already passed.
