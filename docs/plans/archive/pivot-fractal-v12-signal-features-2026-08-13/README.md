# Pivot Fractal V12 Signal Features Archive

This archive records the completed six-sprint replacement of active strict V11
with strict V12 origin-grain Macro/Micro Bands and Stochastic features.

The accepted XAUUSD real-tick run contains `1,445` origins, `36,966` virtual
trials, `1,431` broker outcomes, complete availability for all `170` signal
features, zero integrity/capacity failures, and `1,418/1,418` strict parity
matches. Matched export-off/export-on tester sessions produced identical broker
event streams. Strict validation, build, audit, all `29` tests, and all six
offline XGBoost ablations pass.

The acceptance audit also corrected one Python-only derived artifact defect:
`initial_matrix_wide.parquet` duplicated the Micro/Macro width-point columns.
Raw V12 TSVs, the 464-column type registry, broker behavior, and model targets
were unchanged.

Files:

- `pivot-fractal-v12-signal-features-plan.md`: sprint scope, gates, rollback
  policy, and completed execution contract.
- `docs/research/pivot-fractal-v12-producer-acceptance-2026-08-13.md`: compact
  runtime, dataset, pipeline, and residual-risk evidence.

This archive authorizes the downstream Django research-app cutover only. It
does not authorize live MT5 rollout, runtime model loading, or execution
filtering. Visual chart behavior was explicitly waived and remains unverified.
