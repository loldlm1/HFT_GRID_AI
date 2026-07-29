# Pivot Fractal Engine And Schema V9 Closeout

**Archived**: 2026-07-29
**Status**: Complete
**Active engine**: `PIVOT_FRACTAL_V1`
**Active schema**: V9 (`schema_v9_pivot_fractal`)
**Final rollback point**: `1c9d573`

## Summary

The pivot-fractal engine replaces the fixed M1 extremum source with broker-native
`M15`, `M30`, `H1`, `H4`, and `D1` windows. Each exact
`(symbol, timeframe, active_bar_open, level)` identity is consumed once on a
Bid-based first touch, with Ask buy execution, broker-authoritative checks,
captured structural routes, monotonic pivot trailing, and strict schema V9
research persistence. M1 remains context-only.

Sprint 8's diagnostic run exposed two defects: series visibility could expose a
future M1/window boundary before the observed tick, and sequential confluence
sends could capture different feature values. Sprint 9 corrected both without
adding strategy rules, public inputs, schema columns, runtime ML, or test
infrastructure.

## Final Acceptance

- Static reference/include review, Python compilation, all existing contract
  tests, strict positive fixtures, and causal/frozen-feature negative fixtures
  pass. The original `us30_test_run_1` still fails closed for its causal rows.
- The post-fix MetaEditor compile reports `0 errors, 0 warnings`. Local and both
  VPS acceptance terminal binaries match at SHA-256
  `866d8bf3439a82c3570f029f94564b37781a53b934b612ccc2062c497cb2b07b`.
- Paired US30/M1 real-tick lanes over `2026.07.21`-`2026.07.24` used identical
  settings and `500 ms` tester delay with logs disabled. Export off took
  `5.301 s`; export on took `5.471 s` (`3.21%` overhead), with `5,823`
  byte-identical broker lifecycle lines.
- The natural unfiltered run
  `sprint9_natural_us30_final_20260112_20260725` completed with
  `export_status=OK`, `completion_status=NATURAL`, `49,716` attempts, `298,296`
  features, `48,431` broker outcomes, zero incomplete features, zero duplicate
  identities, and zero referential/row-integrity errors.
- Formula, window, causal trigger, Bid/Ask, all 14 route families, trailing,
  ticket ownership, broker outcomes, confluence snapshot equality, and Exness
  DST audits pass on the unfiltered run. Twelve positions were right-censored
  at the interval boundary and are excluded from broker-outcome research rows.

## Evidence

- Corrective audit note: `docs/research/pivot-fractal-v9-vps-run-audit-2026-07-29.md`
- External tester, dataset, and audit artifacts:
  `/tmp/hft-grid-ai-sprint9-evidence/`
- Compile log: `logs/compile/agentic-build.log` (ignored/generated)

Generated tester exports, datasets, audits, binaries, and VPS files remain
outside Git. The original censored diagnostic run remains immutable historical
evidence and is not an accepted training source.

## Commit Sequence

- Sprint 1: `4c80c2b` - `feat: add cached pivot fractal window foundation`
- Sprint 2: `070ff8d` - `feat: capture multi timeframe pivot context features`
- Sprint 3: `2635413` - `feat: add pivot fractal schema v9 export contract`
- Sprint 4: `5a22d5c` - `feat: cut broker entries over to pivot fractal signals`
- Sprint 5: `350539a` - `feat: trail pivot positions by captured levels`
- Sprint 6: `5be81ea` - `refactor: replace schema v8 research tooling with v9`
- Sprint 7: `1c9d573` - `docs: align the pivot fractal broker executor foundation`
- Sprint 8: deliberately uncommitted failed diagnostic acceptance.
- Sprint 9: the single commit containing this archive and the causal/frozen-
  snapshot correction, with `1c9d573` as its rollback point.

## Restrictions And Residual Risks

- Completion does not authorize live rollout. Before any future deployment,
  old-version positions must be flat, the account must support retail hedging,
  and only one EA instance may run per account and symbol.
- `500 ms` is tester stress configuration, not a public input or strategy rule.
- Broker-outcome data is naturally right-censored at a test interval boundary;
  downstream research must use broker-confirmed rows only.
- No profitability conclusion, runtime XGBoost/model approval, or live signal
  authorization follows from this closeout.

Start a new explicitly invoked `$planner` plan under `docs/plans/` for live
rollout, runtime model approval, another schema, or a new execution strategy.
