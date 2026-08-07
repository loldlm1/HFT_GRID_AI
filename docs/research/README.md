# Research Evidence

## Active State

The current implementation candidate is the `PIVOT_FRACTAL_V2` Macro/Micro
broker executor with strict schema V11 persistence, a virtual SL/TP policy
matrix, bounded volatility re-entries, broker-parity calibration, and
offline-only DuckDB/Parquet/XGBoost research. Final V11 real-tick acceptance is
pending the active plan's compile and human Strategy Tester gate.

Use these active documents:

- `docs/workflows/pivot-fractal-statistics-flow.md`
- `docs/workflows/pivot-fractal-offline-research-boundaries.md`
- `docs/environment/mt5-agentic-workflows.md`
- `pivot-sl-tp-reentry-matrix-plan.md`
- `docs/research/archive/macro-micro-pivot-bandwidth-schema-v10-2026-08-06/README.md`
- `docs/plans/archive/macro-micro-pivot-bandwidth-schema-v10-2026-08-06/README.md`

No current research artifact is approved for MT5 runtime or live deployment.
Accepted V2/V11 evidence must come from a natural eight-file run that passes
the strict validator and the human tester matrix. Generated Common Files
exports, datasets, audits, models, reports, screenshots, and binaries remain
outside tracked documentation unless the closeout explicitly archives compact
evidence.

## V10 Acceptance Archive

`docs/research/archive/macro-micro-pivot-bandwidth-schema-v10-2026-08-06/`
records the accepted post-Sprint-9 XAUUSD run. It remains offline research
evidence only and does not approve runtime model loading or live deployment.

## Historical V9 Evidence

`docs/research/pivot-fractal-v9-vps-run-audit-2026-07-29.md` and all V9
archives describe the historical `PIVOT_FRACTAL_V1` implementation only. They
must not be presented as V2/V11 acceptance or converted into V11 datasets.

Completed broker, signal-engine, exporter, retest/confluence, ML, and
robustness evidence remains under `docs/research/archive/` as immutable
historical audit material.
