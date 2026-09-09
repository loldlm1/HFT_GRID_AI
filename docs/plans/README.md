# Plans

## Active

There is no active implementation plan in this repository. V13 chart rendering
and the Exness broker/full-history acceptance queue are operational gates. The
[Exness handoff](../research/exness-tick-history-handoff-2026-09-07.md) records the
completed implementation, passing sampled imports and remaining evidence.

The downstream Django plan at
`/home/loldlm/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v13-django-research-progression-plan.md`
is a separate repository workflow. Its V13 contract preparation may proceed
from the accepted handoff, while V12 removal and destructive cutover remain
explicitly authorized gates in that repository.

## Archived

Completed and superseded plans live under `docs/plans/archive/`. They document
historical code and exporter revisions only; they are not active implementation
guidance.

- [Parent-close chronology](archive/parent-close-chronology-2026-09-09/README.md):
  completed three sprints covering the EA close-clock handoff, bounded Python
  audit/recovery, and Exness tester acceptance. The [acceptance record](../research/parent-close-chronology-acceptance-2026-09-09.md)
  retains the full recovered-run validation limits.
- [Exness tick-history service](archive/exness-tick-history-2026-09-07/README.md):
  completed six-sprint implementation; subsequent offline/native validation is
  recorded in its current handoff.
- `docs/plans/archive/pivot-fractal-v13-deep-pivot-producer-2026-08-31/README.md`:
  completed V13 H1/M10 producer migration and offline handoff.
- `docs/plans/archive/macro-micro-pivot-bandwidth-schema-v10-2026-08-06/README.md`:
  completed V10 pivot-bandwidth producer and broker acceptance.
- `docs/plans/archive/pivot-fractal-engine-schema-v9-2026-07-29/README.md`:
  completed V9 signal-engine and structural lifecycle work.
- `docs/plans/archive/pivot-retest-confluence-offline-research-2026-07-30/README.md`:
  completed causal retest/confluence offline research.
- `docs/plans/archive/pivot-sl-tp-reentry-matrix-v11-2026-08-07/README.md`:
  completed V11 matrix, retries, parity, and acceptance work.
- `docs/plans/archive/v11-dataset-column-type-registry-2026-08-07/README.md`:
  completed V11 type registry and offline builder gate.
- `docs/plans/archive/pivot-fractal-v12-signal-features-2026-08-13/README.md`:
  completed V12 origin-grain feature producer and Django handoff.

Do not edit archived plans for future work; create a new plan when the V13
contract or implementation changes.
