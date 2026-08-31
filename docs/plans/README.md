# Plans

## Active

- `../../pivot-fractal-v13-deep-pivot-producer-plan.md`: active eight-sprint
  producer migration. Sprints 1-6 are committed; Sprint 7 is the documentation
  and handoff gate; Sprint 8 owns the final compile and human acceptance.

The downstream Django plan at
`/home/loldlm/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v13-django-research-progression-plan.md`
is a separate repository workflow. It must not perform its V12 removal or
destructive cutover until the V13 producer handoff is accepted.

## Archived

Completed and superseded plans live under `docs/plans/archive/`. They document
historical code and exporter revisions only; they are not active implementation
guidance.

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

Do not edit archived plans during normal V13 implementation work.
