# Current Project State

Updated 2026-09-16. EA `1.40`, strict schema `14`, engine `PIVOT_FRACTAL_V2`.
This index owns changing status; guides own procedures and dated evidence keeps
its original results.

## V14 Optimization

The [optimization plan](../pivot-fractal-v14-optimization-plan.md) is the current
authorized execution: P1 archive/baseline, P2 Deep reuse, P3 export batching and
P4 exact parity/performance acceptance. P1 validation passes: three native
baselines seal OK/NATURAL and pass strict/chronology checks. P1 commit is `3c15e0a`.
P2 passes all twelve-table and ordered broker comparisons on all three cases,
strict/chronology validation and 51 focused tests. Its AVX2 compile has 0 errors
and 0 warnings; the broker owners and V14 headers are unchanged. Receipts and rollback
binaries are retained in ignored `.codex-artifacts/v14-optimization/`.
The schema, feature contract and frozen Django source remain V14.

The operator's `V14_XAUUSD_test_run` finished naturally through August 14, 2017
and sealed OK/NATURAL, with zero capacity rejections and 3,259,164,050 export
bytes. Peak active Deep links/outcomes were 723/2,169. This is seal/resource
evidence only; a full semantic audit of that operator run has not been performed.

## Completed V14 Implementation

The [archived MT5 plan](plans/archive/pivot-fractal-v14-mt5-plan.md) completes M1-M4 implementation
and scoped validation. Each sprint has its own commit and rollback receipt.
The [frozen producer handoff](research/pivot-fractal-v14-producer-handoff.md)
contains the exact contract, source pins, QA matrix and independent native copy.

| Sprint | Commit | Rollback parent |
| --- | --- | --- |
| M1: V14 offline contract | `013b95e` | `8625222` |
| M2: paired capture and both directions | `d60bc2c` | `013b95e` |
| M3: initial-2015 native QA | `879b39c` | `d60bc2c` |
| M4: final cleanup and handoff | `m4/commit.json` receipt | `879b39c` |

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

MT5's selected source is `V14_XAUUSD_20150817_H2M15M3_M3_20260916`, initial-2015
XAUUSD, H2/M15/M3. Its twelve files seal OK/NATURAL and pass strict validation,
chronology and an audit at support floor 30. All 129 Macro and 908 Deep pairs are
complete; there are 15,732 links and 47,196 link-scoped outcomes. This is workflow
evidence; narrow filters may remain below support thresholds.

The independent retained root is
`/home/admin/Documents/Exness_Research_Runs/V14_MT5_Handoff_20260916/`.
`runs/<run_id>/` contains exactly twelve unchanged TSVs; `contract-pins.json`,
`source-receipt.json` and registries remain outside it. The handoff publishes
all hashes and vendoring boundaries. Original shared terminal runs are preserved.

Django implementation/intake has not run in this task. The consumer checkout is
`/home/admin/python_projects/hft-grid-ai-orchestrator`; its
[V14 plan](/home/admin/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v14-django-plan.md)
requires M4 completion before its separately authorized staging purge/rebuild.
It is limited to staging and focused tests. Production is untouched. Existing
V13 application compatibility evidence does not imply V14 intake compatibility.

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
`thread-closeout-20260910/` checkpoints/handoffs. Archived completed state must
never resume an old plan. Private binaries, logs, original/recovered data, shared
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
git show 879b39c:docs/research/pivot-fractal-v13-producer-handoff.md
git show 879b39c:eurusd-tester-reliability-performance-plan.md
git show 879b39c:docs/README.md
```

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
