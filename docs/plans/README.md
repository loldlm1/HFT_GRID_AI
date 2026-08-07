# Plans

## Active

- `docs/plans/macro-micro-pivot-bandwidth-schema-v10-plan.md`: active ordered
  implementation of `PIVOT_FRACTAL_V2`, one Macro/one Micro weighted-Bands
  context, fixed-reference risk, immutable 1R execution, and strict schema V10.
  Source integration and the final zero-warning compile are complete through
  Sprint 7. Sprint 8 requires human real-tick acceptance before archival.

Do not start another substantial strategy, architecture, live-rollout, schema,
or repository-wide change until the active plan is completed or explicitly
superseded.

## Archived

Completed and superseded plans live under `docs/plans/archive/`. They document
their historical code and exporter revisions only; they are not active
implementation guidance.

- `docs/plans/archive/pivot-fractal-engine-schema-v9-2026-07-29/README.md`:
  completed `PIVOT_FRACTAL_V1`, schema V9, causal snapshot, structural trailing,
  paired performance, and natural Strategy Tester acceptance work.
- `docs/plans/archive/pivot-retest-confluence-offline-research-2026-07-30/README.md`:
  completed causal retest context, bounded unordered confluence, offline feature
  ablation, and natural-data research acceptance.

Use these current documents:

- `docs/architecture/market-data-broker-executor.md`
- `docs/workflows/pivot-fractal-statistics-flow.md`
- `docs/workflows/pivot-fractal-offline-research-boundaries.md`
- `docs/environment/mt5-agentic-workflows.md`

Do not edit archived plans during normal implementation work.
