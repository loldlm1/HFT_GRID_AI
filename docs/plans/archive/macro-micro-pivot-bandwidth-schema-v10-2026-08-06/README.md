# Macro/Micro Pivot Bands Engine And Schema V10 Closeout

**Archived**: 2026-08-06
**Status**: Complete
**Active engine**: `PIVOT_FRACTAL_V2`
**Active schema**: V10 (`schema_v10_macro_micro_pivot_bands`)
**Final rollback point**: `e32cd730707117453e1cbb4768836a8e29fd2f70`

## Summary

The completed implementation replaces the multi-timeframe V1/V9 collector
with one configurable Macro pivot window, one configurable Micro weighted-Bands
context, live-Bid virtual-limit triggers, immutable structural stops, fresh
quote 1R targets, fixed-reference percentage risk, broker-first
reconciliation, and strict six-file schema V10 persistence.

The renewed XAUUSD human real-tick run passed deterministic-time, debug-log,
strict-schema, structural-route, broker-lifecycle, dataset, audit, and offline
XGBoost smoke checks. Sprint 9's query-debug change is confirmed diagnostic
only, so no additional corrective source sprint was required.

## Acceptance Evidence

- Plan: `macro-micro-pivot-bandwidth-schema-v10-plan.md`
- Research acceptance:
  `docs/research/archive/macro-micro-pivot-bandwidth-schema-v10-2026-08-06/macro-micro-pivot-v10-short-run-audit-2026-08-06.md`
- Accepted compile: `0 errors, 0 warnings`; `.ex5` SHA-256
  `0e023a5441469021edd46858e6432d7a0c740328442ef508c70f6a6bb9957376`.
- Accepted natural run: `910` windows, `1,922` attempts, `7,663` checks,
  `1,909` outcomes, and `1,908` strict binary rows.
- Corrected debug SHA-256:
  `6fee77c5f048adb33af59d4ac4940650b4ce92f66247d53c7cd161345e6adf30`.

Generated Common Files exports, datasets, audits, models, logs, screenshots,
and binaries remain outside Git.

## Commit Sequence And Rollbacks

| Sprint | Commit | Message | Rollback point |
| --- | --- | --- | --- |
| 1 | `2c5d383f1b959644dc3e4fdec88c57066b6142b7` | `feat: define strict macro micro pivot schema v10` | `0a47ce2df99f804667f8110c2c8788f4fb89f297` |
| 2 | `aaead3232bd3b591e2120bc66ce6264e53ee9f17` | `feat: simplify pivot band research pipeline` | `2c5d383f1b959644dc3e4fdec88c57066b6142b7` |
| 3 | `826d7923c0d7c115976e52f2260f0c96623f60ed` | `refactor: reduce pivot runtime to macro and micro contexts` | `aaead3232bd3b591e2120bc66ce6264e53ee9f17` |
| 4 | `16c7c1d531f4f0258ab7b4e89d207b02591d19fb` | `feat: implement virtual pivot touch band snapshots` | `826d7923c0d7c115976e52f2260f0c96623f60ed` |
| 5 | `344789a8d841c4b6993f336461e3e6a0def03e56` | `feat: add quote based one r pivot execution` | `16c7c1d531f4f0258ab7b4e89d207b02591d19fb` |
| 6 | `f2a83babd94104223aec4aa31cecec8d1fd83dbc` | `refactor: remove pivot trailing and export v10 outcomes` | `344789a8d841c4b6993f336461e3e6a0def03e56` |
| 7 | `9e195b7c72579d1face2300f5bb3a827a0ecafd1` | `build: validate macro micro pivot executor v2` | `f2a83babd94104223aec4aa31cecec8d1fd83dbc` |
| 8 | `4d0516ba58743c14f262d2c29e39e85fbdeb7b63` | `docs: record V10 short-run diagnostic audit` | `9e195b7c72579d1face2300f5bb3a827a0ecafd1` |
| 9 | `e32cd730707117453e1cbb4768836a8e29fd2f70` | `fix: make pivot debug events deterministic` | `4d0516ba58743c14f262d2c29e39e85fbdeb7b63` |
| 10 | This archive commit | `docs: close out macro micro pivot v2 acceptance` | `e32cd730707117453e1cbb4768836a8e29fd2f70` |

## Restrictions

Completion does not authorize live rollout or runtime model use. Before any
future deployment, older-engine positions for the symbol must be flat, the
account must support retail hedging, and only one EA instance may run per
account and symbol.
