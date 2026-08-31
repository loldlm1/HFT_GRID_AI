# Pivot Fractal V13 Deep Pivot Producer Archive

This archive records the completed eight-sprint migration from strict V12 to
the strict V13 H1/M10 producer and offline research contract.

V13 keeps the structural H1 broker `1R` lane, replaces Bands-width entries and
retries with `STRUCTURAL` and `MIDPOINT_50` H1 lanes at `1R/2R/3R/5R`, and adds
shared causal M10 events with one configured-Micro snapshot and parent-scoped
deep `1R/2R/3R` outcomes. Exact H1 lifecycle seconds and M10 parent-age seconds
remain uncapped research facts.

The implementation chain is `8b2069b`, `f05678b`, `84bfb36`, `af08a2f`,
`1597448`, `a684db5`, `dc41827`, and `8c57aaf`. The final MetaEditor compile
reported `0 errors, 0 warnings`; the bounded real-tick export-on/off tester gate
and strict V13 validation/build/audit passed. The configured `120 ms` execution
delay does not support sub-120 ms or perfect intra-second sequencing claims.

Files and evidence:

- `pivot-fractal-v13-deep-pivot-producer-plan.md`: completed sprint scope,
  decisions, gates, and rollback ledger.
- `docs/research/pivot-fractal-v13-producer-handoff.md`: frozen downstream
  contract and hashes.
- `docs/research/pivot-fractal-v13-producer-acceptance-2026-08-31.md`: compile,
  tester, dataset, audit, and residual-risk evidence.

The human chart-object/rendering pass remains outstanding before any
deployment-oriented claim. This archive authorizes neither live rollout nor
the downstream Django V12 deletion gate.
