# Pivot SL/TP Re-entry Matrix V11 Archive

This archive records the completed nineteen-sprint implementation of strict
schema V11, the virtual four-by-four SL/TP matrix, bounded volatility
re-entries, and broker-parity calibration while preserving the single real
structural 1R order lane.

The final XAUUSD `EXNESS_SESSION` January-July real-tick run is accepted as raw
EA/export evidence: `OK/NATURAL`, 7,178 origins, 186,036 trials, 185,788
outcomes, 7,054 broker outcomes, 7,032 strict parity matches, zero integrity or
capacity errors, and an active-state peak of 83/2,048. The final compile is
`0 errors, 0 warnings`.

One offline tooling defect is intentionally not hidden by this closeout. The
official dataset builder inferred `execution_checks.block_source` as numeric
and failed on the valid text value `broker_close`. A diagnostic text override
proved that the same raw run builds, audits, and trains correctly. A focused
successor plan owns the exhaustive frozen V11 type registry and official
full-run regression; no MQL5 change or recompile is implied.

Files:

- `pivot-sl-tp-reentry-matrix-plan.md`: complete implementation plan, sprint
  gates, rollback points, and final handoff.
- Research evidence is archived separately under
  `docs/research/archive/pivot-sl-tp-reentry-matrix-v11-2026-08-07/`.

This archive authorizes offline research evidence only. It does not authorize
runtime model loading or live deployment.
