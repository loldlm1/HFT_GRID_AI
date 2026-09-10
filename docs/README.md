# Current Project State

Updated 2026-09-10. EA version `1.30`, strict Pivot Fractal schema `13`, engine
`PIVOT_FRACTAL_V2`. This index owns changing project status; the linked guides
own procedures and dated evidence owns its original results.

## Active Work

The authorized [guidance and cleanup plan](../project-guidance-cleanup-plan.md)
is executing Sprint 2 of 3. Completed V13, Exness preparation and parent-close
plans are historical and must not be restarted.

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

Current pre-cleanup source anchor:
`bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93`. The parent-close acceptance records
MetaEditor build 6184, zero errors/warnings and a 295,370-byte binary, SHA-256
`ac5ae06f4d7a2c788d4470e2b849a9bb76cd6b97d1d0c646c2e9ffd719b79237`.
The cleanup has not changed source or replaced this compile evidence yet.

The prior correction closeout reports 45 Python contract tests and 91 Exness
service tests. These are historical results, not fresh tests in this cleanup.
Its focused Exness export-on/off tester matched 43 report fields and 694 ordered
broker messages at 50 ms delay. The original V13 acceptance used 120 ms delay.
Neither establishes subsecond accuracy or exchange-level tick ordering.

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
