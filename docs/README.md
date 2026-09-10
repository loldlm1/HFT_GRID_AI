# Current Project State

Updated 2026-09-10. EA version `1.30`, strict Pivot Fractal schema `13`, engine
`PIVOT_FRACTAL_V2`. This index owns changing project status; the linked guides
own procedures and dated evidence owns its original results.

## Active Work

The [EURUSD reliability and performance plan](../eurusd-tester-reliability-performance-plan.md)
has validated Sprint 3 of four authorized, ordered sprints; its commit gate is
next. Sprint 1 is `9215df8` (rollback `c9ebb24`), and Sprint 2 is `4360448`
(rollback `9215df8`). The affected EURUSD tester is stopped; its incomplete original export and
pre-stop snapshot remain preserved. Prior cleanup, V13,
Exness preparation and parent-close plans are historical and must not be restarted.

The native EURUSD reproduction isolated `PARITY_DISTANCE_INELIGIBLE` at
2017-11-14 07:18:42: an accepted broker request has 29 risk points, while its
research parity shadow incorrectly requires 30 (spread 29 plus one trade tick).
The first diagnostic and tester stop now work with debug logging off, and the
output seals `FAILED` / `CENSORED`. The corrected EURUSD run crosses this boundary
and finishes naturally with valid strict/chronology output. Accepted parity now
retains its actual `distance_eligible=0` fact without vetoing the shadow. Closed
broker cleanup no longer depends on research delivery. Both injected failures
release research state once, preserve open broker ownership, stop and reject;
the original historical run remains incomplete and unaccepted.

Strict intake also exposes a separate decimal serialization issue in the failed
EURUSD reproduction: a below-PP bid and the pivot both print as `1.1586400000`.
Seventeen-significant-digit serialization now retains the causal numeric evidence
without changing tick comparisons or weakening validation. EURUSD export-on/off
matches 4,216 broker messages and 43 report fields; XAUUSD matches 1,392 messages
and 43 fields against Sprint 1. XAUUSD's only table changes from Sprint 1 are
numeric precision; row order, identities, labels and clocks remain unchanged.

All six Sprint 2 windows pass strict validation and parent chronology: E-FAIL,
X-PARITY, EURUSD June 2016 stress, XAUUSD March 2020 stress and both March 2024
DST cases. Sprint 3 also passes this matrix with exact twelve-table facts, row
order and broker events against Sprint 2. Export-on/off parity and both injected
failure/release/stop checks pass. Deep processing now uses checked associations,
one bounded active-count pass, stable event-group compaction and one parent
snapshot pass; links own frozen membership without a duplicate parent array.

One unmeasured warm-up per workload/binary and three alternating measured pairs
on optimized AVX2 establish the algorithm gain:

| Frozen workload | Ticks | Sprint 2 median (min-max), seconds | Sprint 3 median (min-max), seconds | Elapsed reduction |
| --- | ---: | ---: | ---: | ---: |
| EURUSD 2016-06-20 to 2016-06-28 | 775,654 | 68.225 (67.427-68.382) | 20.616 (20.356-20.730) | 69.78% |
| XAUUSD 2020-03-09 to 2020-03-21 | 1,710,103 | 96.907 (95.348-97.279) | 33.756 (33.670-34.558) | 65.17% |

All twelve measured passes match exact native facts and broker events, including
the separately retained rejected-request messages. Maximum observed repeat
spread is 1.81% for EURUSD and 2.63% for XAUUSD, well below the gain. Peak deep
outcomes remain 522 and 420. Sampled tester RSS peaks at 156.90 / 195.45 MiB
across each symbol's measured pairs; process/load samples and full receipts live
in `sprint-3/benchmark-results.json` and adjacent private artifacts. These results
do not predict full-history elapsed time. Sprint 4 owns compiler selection.

| Area | Accepted baseline and evidence |
| --- | --- |
| V13 producer | H1 eight-lane matrix, shared deep events/parent outcomes and bounded runtime/export/performance acceptance; [original acceptance](research/pivot-fractal-v13-producer-acceptance-2026-08-31.md). |
| Parent-close correction | Actual broker close clocks retained for deep censoring; same-second broker duration accepted; [correction acceptance](research/parent-close-chronology-acceptance-2026-09-09.md). |
| Exness source service | Registered source pipeline and resumable preparation; [implementation evidence](research/exness-tick-history-acceptance.md). |
| Persistent ticks | Four reusable files, 1,018,476,599 ticks through September 7, 2026; [preparation and hashes](research/exness-single-file-preparation-2026-09-09.md). |
| Custom-symbol checks | Intended mappings, 24 exposed core properties, all 265,592 H1 rows and 12 sampled tick intervals; [alignment evidence](research/exness-custom-symbol-alignment-2026-09-09.md). |
| Original historical XAUUSD run | Real-tick completion and diagnosed censor-clock defect; [original verification](research/exness-xauusd-run-verification-2026-09-09.md). |
| Historical recovery | Separate derivative corrects 1,109 censor clocks, passes 53 chronology checks and byte-reversal verification; correction acceptance retains limitations. |

Use `EXNESS_SESSION` and H1/M10/M3 for the four existing custom symbols unless
a new scoped task changes the configuration. Source ticks remain UTC, imported
with Shift=0. Analysis-time normalization does not shift broker candles or
execution clocks. EURUSD alone has the approved, manifested representation
policy bounded by `1e-16`; all source ticks are retained.

## Remaining Operational Gates

- **Full-history EURUSD: outstanding operator gate.** Focused reliability and
  performance checks in the active plan do not certify the 2015-2026 interval.
- **Human chart/rendering verification: outstanding.** Required before any
  deployment-oriented claim; compilation and fixtures cannot replace it.
- **Formal Exness broker equivalence: INCONCLUSIVE.** Positive native broker
  trade tick/value, full specification/session/P&L, historical clock/feed mapping,
  registered-export/round-trip and pinned comparison evidence remain incomplete.
  Native H1 and sampled tick equality do not prove broker-feed equality.
- **Full recovered-run semantic validation: NOT RUN.** Chronology and reversible
  correction do not certify every geometry, feature or money rule.

No live rollout is authorized. Downstream Django contract preparation is a separate
repository workflow; its V12 deletion/cutover needs its own explicit authorization.
Its locally documented plan location at the prior handoff was
`/home/loldlm/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v13-django-research-progression-plan.md`;
that external path is operator context, not a required file in this checkout.

## Source And Validation Pins

Sprint 3 compile (2026-09-10): MetaEditor MCP build 6184, explicit optimized
`AVX2 + FMA3`, **0 errors, 0 warnings**. Binary: 306,420 bytes, modified
`2026-09-10T13:37:42.748495+00:00`, SHA-256
`cdd51b362965f90d5fb4ae45da3b7d1b2e0379093dc1d3327a62a6e7a1ae035f`.
The 38-source compact sorted mapping hashes to
`1f342ddcdb0ff0d110faa4520d997dbe55f0523c5cab22093a34a2736c14b0ff`.
Receipts, paired rollback binaries, settings, failed-run diagnostics and exact
comparisons are in ignored `.codex-artifacts/eurusd-tester-reliability/sprint-3/`;
`optimized-1-pin.json` is the matching source/binary receipt. The Sprint 2
rollback pair remains in `sprint-2/corrected-1-pin.json` and Git `4360448`.
The unchanged 45 Python tests and strict V13 fixture reuse their Sprint 1 pass.
No live failure test, full-history EURUSD run or new human chart acceptance is claimed.

Historical cleanup compile (2026-09-10), source `c9ebb24`: MetaEditor MCP preflight
and `compile_file`, build 6184 / x64,
**0 errors, 0 warnings**. Regenerated binary: 294,694 bytes, modified
`2026-09-10T11:57:01.228474+00:00`, SHA-256
`f729139e19f1867a74006f041175d7f4d4668e2ab92732b0b852b487240cd125`.
All 38 source/include hashes match the compile receipt. The compact, sorted JSON
path-to-SHA-256 mapping hashes to
`a0ff8c10c0173f9c977d1dac45ca611dcdba2f536679a434276fb55e19ab5a97`;
the full mapping and binary rollback copy are in ignored
`.codex-artifacts/project-guidance-cleanup/`.

Cleanup validation passes: 45 Python contract tests, strict V13 fixture CLI,
include/reference/broker-boundary checks, document links and Git recovery. Removed
40 unused functions, one private constant, an unused array header/include and 23
unused V9/V10/V11 fixtures. V12 rejection/V13 fixtures, all Python/C++ sources,
public inputs and broker guards remain unchanged. The equivalent CENSORED branch
was simplified; 434 retained function bodies are unchanged. No new tester run was
needed for these proved removals; the previous runtime evidence tested its own
recorded binary and is not relabeled as testing this binary.

The parent-close acceptance preserves the prior 295,370-byte binary and its source
pin. Its focused Exness export-on/off tester matched 43 report fields and 694
ordered broker messages at 50 ms delay. The original V13 acceptance used 120 ms.
Neither proves subsecond/exchange ordering. The unchanged Exness service's prior
91-test result is historical and was not rerun for this cleanup.

The [frozen V13 handoff](research/pivot-fractal-v13-producer-handoff.md) preserves
schema/header/registry/fixture pins and the downstream vendoring boundary as of
August 31. Its older compiler/source hashes are historical. Select current source
and any later validation from this index and the correction acceptance.

## Retained Operator Artifacts

- `/home/admin/Documents/Exness_Tick_Data/`: XAUUSD, EURUSD, GBPJPY and BTCUSD
  `<SYMBOL>_ticks.tsv` files, adjacent manifests, README and SHA256SUMS;
  45,742,234,721 TSV bytes. Preserve existing files and unrelated retained archives.
- Original export: `XAUUSD_Exness_Run_2015` under the local MT5 Common Files
  `PivotFractalV13/runs/` directory. Do not modify it in place.
- Derivative: `/home/admin/Documents/Exness_Research_Runs/XAUUSD_Exness_Run_2015_ParentClock_Recovered/`,
  with adjacent `.corrections.jsonl`, `.provenance.json` and `.README.md`.
  The 1,109 affected rows remain `CENSORED_PARENT_EXIT`, excluded with null targets.
  It is a recovered artifact, not a new tester run or output of the corrected EA.
- Ignored `.codex-artifacts/parent-close-chronology-20260909/` contains correction
  compile, tester, audit and recovery receipts. Other dated raw artifact locations
  are in the selected evidence records. Preserve them and their retained handoffs.
- Ignored `.codex-artifacts/thread-closeout-20260909/` retains four completed
  checkpoints and the prior cleanup receipt. Old session IDs/uncommitted labels
  do not represent active work. The maintained environment, helper cache and data
  remain local; project cleanup does not remove global Codex/plugin state.

## Guides And History Recovery

- [Runtime](architecture/market-data-broker-executor.md)
- [Environment and validation](environment/mt5-agentic-workflows.md)
- [V13 research procedures](../tools/deterministic_signal_ml/README.md)
- [Exness preparation and native acceptance](../tools/exness_tick_history/README.md)

Historical documents are recoverable from baseline commit
`bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93`. Paths in Git commands are historical
locations, not required live checkout links:

```bash
git ls-tree -r --name-only bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93 -- docs/plans/archive docs/research/archive
git show bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93:docs/research/exness-research-handoff-2026-09-09.md
git show bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93:docs/plans/archive/parent-close-chronology-2026-09-09/README.md
```

Parent-close commits are `65090dc`, `10aa194`, `4185054`; preparation service
commit is `33eb5a6` with rollback parent `4185054`; prior documentation closeout
is `bb97e9e` with rollback parent `33eb5a6`. Source rollback preserves original
and derived datasets independently. Do not reset history to retrieve a document.

## Cleanup Commit Ledger

The retained set is seven current guides/indexes and seven dated evidence records,
plus the latest plan. All 106 retired Markdown files are recoverable byte-for-byte
from the baseline Git anchor. AGENTS is 128 lines / 8,174 bytes. The cleanup removes
about 92% of the prior Markdown bytes even including its execution plan; it does
not delete private market data, sidecars or retained operator checkpoints.

| Sprint | Commit | Rollback parent |
| --- | --- | --- |
| Guidance and current owners | `e9b3998ab10cbb433a387771ceb7bee0ca769e59` | `bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93` |
| Historical document retirement | `04aabccd0375337ba82ec673cc775f27d0081ebe` | `e9b3998ab10cbb433a387771ceb7bee0ca769e59` |
| Proven dead-code removal and integration | `c9ebb24a28276a42a72d33970f941ac37507ead5` | `04aabccd0375337ba82ec673cc775f27d0081ebe` |

The final commit SHA and completed execution state are recorded in the ignored
execution journal. Revert reviewed sprint commits in reverse order when needed;
source rollback also requires its matching retained binary or a recompile.

The completed cleanup plan is recoverable with
`git show c9ebb24a28276a42a72d33970f941ac37507ead5:project-guidance-cleanup-plan.md`.
Its completed execution state and exact plan copy were preserved before the
reliability plan was initialized; they do not authorize restarting old work.
