# Current Project State

Updated 2026-09-10. EA version `1.30`, strict Pivot Fractal schema `13`, engine
`PIVOT_FRACTAL_V2`. This index owns changing project status; the linked guides
own procedures and dated evidence owns its original results.

## Active Work

The [EURUSD reliability and performance plan](../eurusd-tester-reliability-performance-plan.md)
has validated Sprint 1 of four authorized, ordered sprints; its commit gate is
next. The affected EURUSD tester is stopped; its incomplete original export and
pre-stop snapshot remain preserved. Prior cleanup, V13,
Exness preparation and parent-close plans are historical and must not be restarted.

The native EURUSD reproduction isolates `PARITY_DISTANCE_INELIGIBLE` at
2017-11-14 07:18:42: an accepted broker request has 29 risk points, while its
research parity shadow incorrectly requires 30 (spread 29 plus one trade tick).
The first diagnostic and tester stop now work with debug logging off, and the
output seals `FAILED` / `CENSORED`. Header corruption and missing-file tests also
stop once and reject. Sprint 2 owns the parity correction and independent closed
broker cleanup; the original historical run remains incomplete and unaccepted.

Strict intake also exposes a separate decimal serialization issue in the failed
EURUSD reproduction: a below-PP bid and the pivot both print as `1.1586400000`.
Sprint 2 must retain the causal numeric evidence without changing tick comparisons
or weakening validation. XAUUSD baseline/candidate/export-off broker streams
match all 1,392 captured messages and 43 report fields; the two export-on runs
match all twelve TSVs after run-ID normalization and pass strict/chronology checks.

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

Sprint 1 compile (2026-09-10): MetaEditor MCP build 6184, explicit optimized
`AVX2 + FMA3`, **0 errors, 0 warnings**. Binary: 304,964 bytes, modified
`2026-09-10T13:00:47.358840+00:00`, SHA-256
`ad238cb3343038fe7103e6e1c570360311da80ef0b291b35312a7d67e8501126`.
The 38-source compact sorted mapping hashes to
`15054598caf827ecddd757732d67a3b0d125b378a490148c8b3cfb0a9b2ee301`.
Receipts, paired rollback binaries, settings, failed-run diagnostics and exact
comparisons are in ignored `.codex-artifacts/eurusd-tester-reliability/sprint-1/`.
The existing 45 Python tests and strict V13 fixture pass. No live failure test,
full-history EURUSD run or new human chart acceptance is claimed.

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
