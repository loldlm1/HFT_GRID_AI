# Extremum Engine Statistics Implementation Evidence

**Date**: 2026-07-10
**Status**: Complete; archived after owner acceptance on 2026-07-11

## Scope

This note records the ordered Sprint 1-7 implementation batch for the single M1
`EXTREMUM_V1` engine and schema v7 statistics contract. It is not Strategy
Tester acceptance, profitability evidence, or runtime-model approval.

## Sprint Commits And Rollback Points

| Sprint | Commit | Rollback point |
| --- | --- | --- |
| Baseline | `7a6826e` | Pre-engine behavior and schema v6 baseline |
| 1 | `c50aa57` | Revert to `7a6826e` |
| 2 | `b6ffd3c` | Revert to Sprint 1 |
| 3 | `9797151` | Revert to Sprint 2; preserve v7 run folders as immutable evidence |
| 4 | `203478a` | Revert to Sprint 3 |
| 5 | `2b23cd4` | Revert to Sprint 4 |
| 6 | `521e038` | Revert to Sprint 5 |
| 7 | `cdcc0f9` | Revert documentation/final cleanup only |

## MetaEditor Compile Evidence

All referenced logs report `0 errors, 0 warnings`:

| Gate | Log | Result |
| --- | --- | --- |
| Baseline | `logs/compile/extremum-engine-baseline.log` | PASS, 66494 ms |
| Sprint 1 | `logs/compile/extremum-engine-sprint1.log` | PASS, 59318 ms |
| Sprint 2 | `logs/compile/extremum-engine-sprint2.log` | PASS, 61029 ms |
| Sprint 3 | `logs/compile/extremum-engine-sprint3.log` | PASS, 72088 ms |
| Sprint 6 | `logs/compile/extremum-engine-sprint6.log` | PASS, 73546 ms |
| Sprint 7 | `logs/compile/extremum-engine-sprint7.log` | PASS, 70971 ms |

The Sprint 7 compile regenerated `HFT_Grid_AI.ex5`. Wine returned process code
`1`, while the MetaEditor log parser reported PASS; the log is the repository's
documented source of truth.

## Python And Data Contract Evidence

- `python -m compileall tools/deterministic_signal_ml`: PASS.
- `python -m unittest discover`: PASS, 10 tests.
- Positive schema v7 fixture: 1 cycle, 2 revisions, 2 attempts, and 1
  broker-target training row.
- Parquet assembly/readback: PASS for cycles, revisions, attempts, features,
  admissions, signal outcomes, leg outcomes, and training matrix tables.
- Human-depth fixture: attempt 1 at raw 39% maps nearest to 38.2 and returns
  `-1R`; attempt 2 at raw 63% maps nearest to 61.8 and returns `+2R`.
- Outcome separation: simulated cycle total is `+1R`; broker-confirmed cycle
  total is `+2R`; the lanes remain distinct.
- Negative fixtures: changed frozen anchors, orphan revisions, and invalid
  simulated provenance are rejected.
- Leakage contract: final depth, cycle finalization, simulated profit, and
  target facts are excluded from point-in-time features.
- Split contract: 12 synthetic cycle groups remain disjoint across
  chronological train/fold/holdout partitions.
- Artifact compatibility: schema v6 multi-strategy artifacts and unapproved v7
  research artifacts fail closed.
- Research training fixture: safely rejects two rows because the configured
  minimum is 500; validation thresholds were not weakened.

No real local schema v6 run was available for replay. Historical compatibility
is covered by preserved schema contracts and contract tests, not by a claimed
real-run replay.

## Static Review Gate

- PASS: one engine identity, fixed M1 timeframe, BOTTOM-to-bullish and
  PEAK-to-bearish direction mapping.
- PASS: no active `Enable_Strategy_*`, S1/S2/S3 config loop, MA confirmation,
  multi-strategy arbitration include, shifted visual handle, or macro chart
  ownership path remains.
- PASS: census attempts are captured separately from operational/broker
  admission, and simulated results cannot satisfy broker outcome predicates.
- PASS: license, session, spread, market, stops/freeze, volume, margin,
  protection, symbol/magic scope, and broker reconciliation remain outside the
  engine and were not weakened by the final cleanup.
- PASS: cycle/revision observation is new-bar scoped; simulated paths use a
  bounded horizon and reserved state; exporter writes remain buffered.

## Final Human Acceptance

The owner accepted plan closure on 2026-07-11 after the completed one-week C
lane passed strict schema v7 validation. The final runtime evidence is recorded
in `extremum-engine-telemetry-corrective-evidence.md`.

The run confirmed PEAK/BOTTOM coverage, stable genealogy, frozen Fibonacci
anchors, bounded active paths, separate simulated/broker outcomes, and
broker-confirmed leg closure. Lane A preserved deterministic trading parity at
matching checkpoints but was affected by external host contention. Lane B and
the one-month run were waived for archival rather than represented as executed.
No schema v7 runtime model is approved by this closeout.
