# Pivot Retest Confluence Offline Research Closeout

**Archived**: 2026-07-30
**Status**: Complete
**Execution baseline**: `67c4398`
**Final commit**: `41f632d`
**Final rollback point**: `626eece`

## Summary

This five-sprint plan added causal six-timeframe prior-close retest context,
bounded first-touch confluence membership, unordered DuckDB pattern audits, and
an opt-in offline XGBoost feature lane. It did not change MQL5 runtime behavior,
schema V9 headers, broker execution, EA inputs, or live rollout state.

Natural-run acceptance covered `49,716` attempts, `298,296` retest rows,
`384,086` confluence members, and `48,431` broker-confirmed outcomes. The fixed
D1-group ablation found mixed, inconclusive model effects; no model or pattern
was approved for runtime use.

## Archived Files

- `pivot-retest-confluence-offline-research-plan.md`
- Research evidence:
  `docs/research/archive/pivot-retest-confluence-offline-research-2026-07-30/`

## Commit Sequence

- Sprint 1: `bfc4d60` - `feat: derive causal pivot retest context offline`
- Sprint 2: `f4d0134` - `feat: materialize causal pivot confluence snapshots`
- Sprint 3: `c2df309` - `feat: audit unordered pivot retest confluence`
- Sprint 4: `626eece` - `feat: add opt-in pivot confluence research features`
- Sprint 5: `41f632d` - `docs: validate pivot retest confluence research`

Generated datasets, audits, models, timing logs, and Strategy Tester exports
remain outside this tracked archive. Start a new explicitly invoked `$planner`
plan for further runtime, schema, long-horizon data, or model-promotion work.
