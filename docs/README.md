# Current Project State

Updated 2026-09-16. EA `1.40`, strict schema `14`, engine `PIVOT_FRACTAL_V2`.
This index owns changing status; guides own procedures and dated evidence keeps
its original results.

MT5 M1-M4 delivery and P1-P4 optimization are complete. There is no active MT5
implementation plan or pending plan question. The separate Django workflow retains
its plan and shared design references; start a new MT5 task from this index.

## V14 Optimization

Completed optimization covers P1-P4:
archive/baseline, Deep calculation and parent metadata reuse, checked byte-batch
exports, and exact parity/performance acceptance. Commits are P1 `3c15e0a`,
P2 `4855f70`, P3 `7ab2a7d`, P4 `04b5c6a`. Full commit/rollback receipts remain in
`.codex-artifacts/v14-optimization/`. The completed plan is retired from active
source and recoverable at `04b5c6a:pivot-fractal-v14-optimization-plan.md`.

All twelve tables match in original row order for initial-2015 H2/M15/M3 and
H1/M10/M3 defaults, the March 2017 busy week and the sustained September 2016 case.
Only verified run IDs normalize. Strict validation, chronology and 51 existing
focused tests pass. Export-on/off matches 576 H2 / 1,044 default ordered broker
messages and 43 non-job report fields. Missing-file and header faults each release
research, retain broker state, stop only their tester, seal FAILED/CENSORED and
reject strict intake. V14 headers, feature/fixture contract and broker owners are
unchanged; no Django data migration is introduced by this optimization.

| Alternating three-pair benchmark | Baseline median (range), seconds | Final median (range), seconds | Observed reduction |
| --- | ---: | ---: | ---: |
| Initial-2015 H2 | 10.804 (10.746-10.855) | 10.341 (10.318-10.375) | 4.285% |
| March 2017 H2 | 10.895 (10.706-10.930) | 10.396 (10.322-10.497) | 4.580% |

Both gains are below the 5% promotion threshold: modest observed improvements,
inconclusive for a substantial speedup. The sustained case processes 1,690,683
ticks in 62.521 baseline / 59.862 final seconds with exact tables and 3,162 matching
broker messages. It seals OK/NATURAL with zero capacity rejections: 4,264 events,
81,336 links and 244,008 outcomes; peak active events/links/trials/outcomes are
15/382/45/1,146. The final process sample spans 60.028 seconds: 98.488% of one CPU
core, RSS 146.969 to 156.973 MiB, high-water 160.016 MiB, 32 descriptors while
active and 23 at teardown, and 154,438,396 export bytes. Baseline process counters
are unavailable because Wine PID discovery failed; native MT5 memory is 137 / 138
MiB. These bounded results do not prove the absence of multi-year leaks.

Accepted source commit `7ab2a7d`, 38-file source mapping SHA-256
`c607bbd74406e60cb81ad2ce6a527fd1ef503009f09f29b28ad6e57583fa55b3`.
MetaEditor MCP 6184 optimized AVX2: 0 errors / 0 warnings, 311,034-byte EX5,
SHA-256 `00095569d044dda11bf45b27932dce0b91b8089f3182057fed3888fbaa90d5d2`.
The exact final pin is `.codex-artifacts/v14-optimization/p4/final-pin.json`,
SHA-256 `041fede7d1413552b2cdef390cd682c2b590202f6b5bb66d67cbe0e866fe61dc`.
P4's tracked changes are documentation only; compile, focused tests and fault
checks reuse unchanged inputs. Original/final binaries and all rollback receipts remain
under ignored `.codex-artifacts/v14-optimization/`. Restore a matching retained
binary only while idle; preserve operator runs and their original exports.

The operator's `V14_XAUUSD_test_run` finished naturally through August 14, 2017
and sealed OK/NATURAL, with zero capacity rejections and 3,259,164,050 export
bytes. Peak active Deep links/outcomes were 723/2,169. This is seal/resource
evidence only; a full semantic audit of that operator run has not been performed.

## Completed V14 Implementation

The [archived MT5 plan](plans/archive/pivot-fractal-v14-mt5-plan.md) completes M1-M4 implementation
and scoped validation. Each sprint has its own commit and rollback receipt.
The [frozen producer handoff](research/pivot-fractal-v14-producer-handoff.md)
records the exact contract, source pins, QA matrix and original independent copy.
Current staging source selection is recorded separately below.

| Sprint | Commit | Rollback parent |
| --- | --- | --- |
| M1: V14 offline contract | `013b95e` | `8625222` |
| M2: paired capture and both directions | `d60bc2c` | `013b95e` |
| M3: initial-2015 native QA | `879b39c` | `d60bc2c` |
| M4: final cleanup and handoff | `4586504` | `879b39c` |

Exact full hashes and gate receipts live in ignored
`.codex-artifacts/pivot-fractal-v14/execution-journal.md` and per-sprint commit
receipts. Completed earlier plans must not be restarted.

Macro origins capture Macro + Deep; Deep events capture Deep + Micro. Both Deep
directions require active eligible Macro parents, with ALIGNED/OPPOSED links and
shared 1R/2R/3R trials. The structural Macro 1R broker policy stays independent.
Defaults remain H1/M10/M3; QA also covers H2/M15/M3. The strict offline toolchain
is V14-only, with 181 H1 / 186 Deep model features and 656 typed source columns.

Validation: 51 focused V14 tests pass; the changed Exness provenance API passes
91 tests. The exact MetaEditor 6184 optimized AVX2 build has 0 errors/warnings,
308,334 bytes, SHA-256
`423433befab4ecfb97a9685bfefda479d0a5acfe7d5d08ffaf0b03399b92be1b`.
M3/M4 retain its unchanged 38-source mapping. M3 passes three native
strict/chronology runs, main/default on/off/V13 broker parity, adjacent on/off
parity and both failed-export release/stop/seal cases. See the handoff for counts,
9,492 independent SMA checks, resource measurements and their bounded limits.

## Downstream Django Intake

The user selects the current MT5 folder `XAUUSD_Test_Run` as the staging source:
`Common\Files\PivotFractalV14\runs\XAUUSD_Test_Run\`, under
`/home/admin/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/`.
The journal and manifest identify XAUUSD_Exness_2015, H2/M15/M3, requested
September 1, 2015 to October 1, 2017 end exclusive. At thread closeout it seals
OK/NATURAL through September 29, 2017 20:59:00 broker time, with twelve TSVs,
3,322,455,138 bytes and zero Deep capacity rejections. This is seal-only evidence;
its semantic validation/intake is NOT RUN by this MT5 task. It is a two-year
source, so keep the consumer's test workflows focused and synthetic cases tiny.
The original selection receipt remains `p4/selected-staging-source.json` under
the optimization evidence root; the newer observation is
`.codex-artifacts/thread-closeout-v14-20260916/source-status.json`.
No operator run or source file was modified.

Before Django D1 purge/intake, require a successful seal, stable twelve-file
hashes, strict validation and chronology, then bind a new independent consumer
copy. Keep staging workflow tests focused and synthetic cases tiny. Do not import
growing TSVs, trim independent tables, reuse an old source receipt or infer READY
from the optimization matrix. The [environment procedure](environment/mt5-agentic-workflows.md#selected-staging-source)
owns this gate; the V14 contract remains unchanged across both plans.

Historical M4 source `V14_XAUUSD_20150817_H2M15M3_M3_20260916` remains intact in
the shared terminal: all twelve original files still match the frozen hashes,
30,841,071 bytes. Its earlier strict/chronology/audit evidence remains historical
acceptance. The previously retained
`/home/admin/Documents/Exness_Research_Runs/V14_MT5_Handoff_20260916/` folder is
missing; the user selects the current folder instead of recreating that copy.
Frozen M4 contract/fixture hashes and sidecar receipts are preserved unchanged.

Django implementation/intake has not run in this task. The consumer checkout is
`/home/admin/python_projects/hft-grid-ai-orchestrator`; its
[V14 plan](/home/admin/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v14-django-plan.md)
uses the frozen M4 contract and current selected source, with seal/source checks
before its staging purge/rebuild. Its feature modes select existing captures:
Macro modes use origin Macro or Deep; connected Deep modes use event Deep or
Micro. Django execution requires its own instruction; this task only aligns the
plan's source/navigation. It is limited to staging and focused tests. Production
is untouched. Existing V13 application compatibility evidence does not imply V14
intake compatibility.

## Remaining Operational Gates

- Human chart/rendering verification is outstanding and required before any
  deployment-oriented claim.
- Full-history EURUSD remains a separate operator gate. Historical settings and
  receipts are retained; a V14 launch needs new settings/identity and its own
  acceptance under the [environment runbook](environment/mt5-agentic-workflows.md#full-history-eurusd-operator-gate).
- Formal Exness broker equivalence is INCONCLUSIVE: complete native tick/value,
  specification/session/P&L, clock/feed mapping and registered round-trip evidence
  remain incomplete. Source equality and the small on/off matrix do not prove it.
- Full recovered-run semantic validation is NOT RUN. Chronology/reversibility
  acceptance of the historical XAUUSD derivative does not certify all facts.
- GBPJPY custom prices remain usable, but missing initial-2015 currency conversion
  history prevents complete account-currency QA. Repair is separate; recent
  GBPJPY data is not a substitute. The accepted fallback is initial-2015 XAUUSD.

No full-history V14 run, Django purge, production deployment or live rollout is
part of this execution. Live deployment requires older positions flat, hedging
and one instance per account/symbol, plus all applicable acceptance gates.

## Retained Evidence And Operator Artifacts

| Evidence owner | Purpose |
| --- | --- |
| [V13 original acceptance](research/pivot-fractal-v13-producer-acceptance-2026-08-31.md) | Historical producer baseline, dated compile/tester and open chart limits |
| [Parent-close acceptance](research/parent-close-chronology-acceptance-2026-09-09.md) | Actual close-clock correction, same-second durations and retained recovery limits |
| [Exness service acceptance](research/exness-tick-history-acceptance.md) | Registered source pipeline and resumable preparation |
| [Persistent tick preparation](research/exness-single-file-preparation-2026-09-09.md) | Four files, 1,018,476,599 ticks through September 7, 2026 and source hashes |
| [Custom-symbol alignment](research/exness-custom-symbol-alignment-2026-09-09.md) | 24 core properties, 265,592 H1 rows and 12 sampled tick intervals |
| [Original XAUUSD verification](research/exness-xauusd-run-verification-2026-09-09.md) | Historical real-tick completion and diagnosed censor-clock defect |

Preserve `/home/admin/Documents/Exness_Tick_Data/`: four tick TSVs, manifests,
README and SHA256SUMS, totaling 45,742,234,721 TSV bytes. Existing custom symbols
use source UTC/Shift=0 and EXNESS_SESSION. Analysis DST does not shift broker
candles. EURUSD alone has its manifested representation policy bounded by `1e-16`.

Preserve original `PivotFractalV13/runs/XAUUSD_Exness_Run_2015` and the derivative
`/home/admin/Documents/Exness_Research_Runs/XAUUSD_Exness_Run_2015_ParentClock_Recovered/`
with adjacent corrections/provenance/README. Its 1,109 corrected rows remain
CENSORED_PARENT_EXIT with null targets; it is not a new tester run. The original
failed EURUSD export and pre-stop snapshot likewise remain intact.

Ignored `.codex-artifacts/parent-close-chronology-20260909/`,
`.codex-artifacts/eurusd-tester-reliability/` and
`.codex-artifacts/project-guidance-cleanup/` retain receipts and matching rollback
binaries. Reliability Sprint 4's `operator-handoff.md`, `final-pin.json` and
`compiler-benchmarks.json` retain the old full-history preparation and performance
measurements. Its AVX2 EX5 SHA-256 is
`b1a15fea4bee29ef881e304dade16efe5e80b4779da497c8653f5ac5cdea80e6`;
this historical binary is also M3's retained V13 comparator.

Keep `.codex-artifacts/thread-closeout-20260909/` and reliability's
`thread-closeout-20260910/` checkpoints/handoffs. The V14 closeout is
`.codex-artifacts/thread-closeout-v14-20260916/`: document recovery copies,
retirement/validation receipts, new-thread handoff and `hook-state/`. Both the
completed local Planner state and its stale P4-question compaction checkpoint are
archived there, outside active hook discovery. Installed hooks/global configuration
are unchanged. Archived completed state must never resume an old plan.
Private binaries, logs, original/recovered data, shared
terminal directories and global Codex/plugin state are not cleanup targets.

## Guides And History Recovery

- [Runtime contract](architecture/market-data-broker-executor.md)
- [Environment and validation](environment/mt5-agentic-workflows.md)
- [V14 research procedures](../tools/deterministic_signal_ml/README.md)
- [Exness preparation/import/comparison](../tools/exness_tick_history/README.md)

M4 retires the superseded V13 handoff and completed EURUSD plan. Their exact bytes
and the prior detailed status/benchmark ledger are recoverable without resetting
history:

```bash
git show 04b5c6a:pivot-fractal-v14-optimization-plan.md
git show 879b39c:docs/research/pivot-fractal-v13-producer-handoff.md
git show 879b39c:eurusd-tester-reliability-performance-plan.md
git show 879b39c:docs/README.md
```

The [accepted shared proposal](../pivot-fractal-v14-feature-capture-proposal.md)
and archived M1-M4 plan remain as historical references used by the Django plan;
their planning-era instructions are not active MT5 work. The frozen V14 producer
handoff, optimized build pin and selected-source gates remain authoritative.

The completed reliability sprint commits are `9215df8`, `4360448`, `629fdf5`,
`06ecfdb`, starting from rollback `c9ebb24`. The earlier guidance cleanup commits
are `e9b3998`, `04aabcc`, `c9ebb24`, starting from `bb97e9e`. Detailed dated
performance results and all original hashes remain in the Git status snapshot
and private receipts; they are not relabeled as V14 evidence.

The older 106-document retirement is recoverable at
`bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93`; use `git ls-tree` or `git show` on
`docs/plans/archive`, `docs/research/archive` and the original tracked paths.
The completed cleanup plan is at
`c9ebb24:project-guidance-cleanup-plan.md`. Parent-close commits are `65090dc`,
`10aa194`, `4185054`; Exness service is `33eb5a6`. Revert reviewed sprint commits
in reverse order; source rollback needs its matching EX5 or recompilation.
Retain data independently and never reset history to recover a document.
