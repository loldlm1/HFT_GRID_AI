# Strict V11 Dataset Column Type Registry Archive

This archive records the completed three-sprint Python-only correction for the
strict V11 TSV-to-DuckDB loader.

The builder now gives all 333 unique schema columns exactly one explicit type
and fails closed on overlap, missing columns, or stale entries. The populated
`execution_checks.block_source=broker_close` path is covered as `VARCHAR`; no
suffix heuristic or default numeric fallback remains.

The preserved accepted XAUUSD run passes the official validate, build, audit,
and offline training path without a diagnostic override. This correction
changes no MQL5 source, compile evidence, public input, raw query, or raw TSV.
The user's intentional fresh pre-run `.ex5` regeneration is preserved and
identified in the plan rather than attributed to this Python work.

Files:

- `v11-dataset-column-type-registry-plan.md`: sprint gates, commits, timings,
  memory, artifact IDs, rollback points, and closeout restrictions.
- Compact execution evidence is archived under
  `docs/research/archive/v11-dataset-column-type-registry-2026-08-07/`.

The resulting datasets and models remain offline research artifacts. This
archive does not authorize MT5 runtime loading or live deployment.
