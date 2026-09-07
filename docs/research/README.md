# Research Evidence

## Active State

The active producer is the strict Pivot Fractal V13 H1/M10 evidence contract,
with no open MQL5 implementation plan. Sprints 1-8 (contract, runtime lanes,
deep lifecycle, M3 evidence, export, offline artifacts, handoff, and bounded
tester acceptance) are committed and archived. The human chart-object/rendering
check remains an outstanding rollout gate. Django may prepare its separately
authorized V13 work from the frozen handoff, but its destructive V12 removal
gate remains separate.

The accepted tester used `ExecutionMode=120` milliseconds. Its evidence is
causal and reconciliation-focused; it does not claim sub-120 ms latency,
perfect intra-second fill ordering, or exchange-level tick sequencing.

Use these active documents:

- `pivot-fractal-v13-producer-handoff.md`
- `pivot-fractal-v13-producer-acceptance-2026-08-31.md`
- `../workflows/pivot-fractal-statistics-flow.md`
- `../workflows/pivot-fractal-offline-research-boundaries.md`
- `../environment/mt5-agentic-workflows.md`
- `../plans/archive/pivot-fractal-v13-deep-pivot-producer-2026-08-31/README.md`

The separate Exness source pipeline has a
[current handoff](exness-tick-history-handoff-2026-09-07.md): implementation and
sampled winter/summer custom imports pass; broker equivalence, full backfill and
tester acceptance remain pending. Its original
[sprint evidence](exness-tick-history-acceptance.md) is a historical snapshot.

V13 writes twelve strict TSV files under
`Common\\Files\\PivotFractalV13\\runs\\<run_id>\\`. H1 evidence has
`STRUCTURAL` and `MIDPOINT_50` lanes at `1R/2R/3R/5R`; shared M10 events
capture one configured-Micro vector and deep `1R/2R/3R` parent outcomes.
Lifecycle durations and parent ages are exact, uncapped broker-time facts.

No current artifact authorizes live rollout, runtime model loading, online
learning, or execution filtering. Generated runs, datasets, audits, models,
screenshots, journals, and binaries remain operator-owned outside tracked
documentation unless a closeout explicitly archives compact evidence.

## Historical Evidence

The accepted V12 producer handoff and acceptance remain historical references:

- `pivot-fractal-v12-producer-handoff.md`
- `pivot-fractal-v12-producer-acceptance-2026-08-13.md`

V12 and earlier plans, fixtures, raw runs, and migration evidence are immutable
historical material. Active V13 tooling rejects V12 rather than converting,
dual-writing, or relabeling it. Earlier research remains under `archive/` and
must not be presented as V13 acceptance.
