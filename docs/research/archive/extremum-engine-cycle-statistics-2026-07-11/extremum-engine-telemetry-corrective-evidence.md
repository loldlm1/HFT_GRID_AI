# Extremum Engine Telemetry Corrective Evidence

**Date**: 2026-07-10
**Status**: Complete; owner accepted and archived on 2026-07-11

## Scope

This note records Sprints 8-11 after auditing the intentionally interrupted
schema v7 run `xauusd_2025_dataset_1`. The owner stopped that diagnostic run
because its projected one-month duration was approximately one hour. The
partial files were useful for diagnosis, but their missing `run_summary.tsv`
means they are not accepted dataset, DuckDB, profitability, or training
evidence.

No account identifiers, license values, credentials, or private profile values
are reproduced here.

## Corrective Commits And Rollback

| Sprint | Commit | Result | Rollback point |
| --- | --- | --- | --- |
| 8 | `68428eb` | Valid frozen attempt TP and terminal append-only broker flags | `cdcc0f9` |
| 9 | `60b58b8` | Strict geometry and genealogy validation | `68428eb` |
| 10 | `097b8ba` | Bounded tester telemetry hot path and file logging | `60b58b8` |
| 11 | `bc8823f` | Evidence and human handoff | `097b8ba` |

## Correctness Repairs

- Intrinsic attempts now freeze their configured deterministic TP before census
  capture. Positive risk and directional `stop < trigger < target` for bullish
  or `target < trigger < stop` for bearish are required.
- Invalid runtime geometry marks the export failed instead of allowing TP zero
  to become an immediate simulated target.
- A finalized simulated attempt waits for broker close, definitive no-entry
  termination, or run end before its single append-only row is written.
- Broker outcome recording also marks the attempt lifecycle terminal, so the
  attempt row and joined outcome carry consistent entry/close flags.

## Validator Repairs

Schema v7 validation now rejects:

- non-positive trigger, stop, target, or risk distance;
- target on the wrong side of the trigger;
- `SIMULATED_TARGET` profit R inconsistent with frozen target/risk geometry;
- a broker feature without a matching broker-entered intrinsic attempt;
- an outcome whose attempt row does not also confirm entry and close;
- broker-confirmed attempt flags without corresponding feature/outcome
  evidence.

Automated Python evidence:

- `python3 -m compileall -q tools/deterministic_signal_ml`: PASS.
- `.venv/bin/python -m unittest discover`: PASS, 14 tests.
- Positive schema v7 fixture validation and DuckDB assembly: PASS.
- Negative TP-zero, wrong-side TP, target-R mismatch, and stale broker-flag
  mutations: rejected for the intended invariant.

## Performance Repairs

- `DeterministicSignalStatsUpdateAttemptPaths()` iterates a compact active index,
  not every historical attempt accumulated in the run.
- Revision expiration also inspects active attempts only.
- Attempt lookup searches newest-first, matching the normal lifecycle where
  admissions and closes usually reference recent attempts.
- Historical terminal attempt state remains available for append-only broker
  completion, but is outside the per-tick loop.
- Query debug changed/throttle caches are fixed at 512 keys and replace old
  entries instead of growing for the entire month.
- Optional file logging keeps one append handle, flushes every 128 lines, and
  closes deterministically on reset/deinit.
- Schema rows flush in bounded batches of 256 instead of 32, while normal
  deinit still flushes all remaining rows before `run_summary.tsv`.

MetaEditor evidence:

| Gate | Log | Result |
| --- | --- | --- |
| Sprint 8 | `logs/compile/sprint8-corrective.log` | PASS, 0 errors, 0 warnings, 74058 ms |
| Sprint 10 | `logs/compile/sprint10-performance.log` | PASS, 0 errors, 0 warnings, 73187 ms |

Compile time is not Strategy Tester runtime evidence. The elapsed tester
improvement remains a human-measured gate.

## Human Short-Run Gate

Use XAUUSD, the same 1-3 market-day range, real ticks, deposit, broker settings,
and all other EA inputs for each lane. Keep ML disabled.

| Lane | Export | File logs | Suggested evidence ID | Purpose |
| --- | --- | --- | --- | --- |
| A | OFF | OFF | `xauusd_2026_extremum_perf_a` | Engine/execution baseline |
| B | ON | OFF | `xauusd_2026_extremum_perf_b` | Normal schema v7 statistics run |
| C | ON | ON | `xauusd_2026_extremum_perf_c_debug` | Optional diagnostic logging cost |

Let every measured run finish naturally. For lane B require:

- `run_summary.tsv` exists with `export_status=OK`;
- strict schema v7 validation passes;
- no zero or wrong-side TP rows exist;
- attempt feature/outcome flags and IDs are consistent;
- cycle, revision, attempt, feature, outcome, and leg counts reconcile;
- elapsed time, total output bytes, and `max_active_attempt_paths` are recorded.

Lane C is diagnostic-only and is not the recommended month configuration.

## One-Month Acceptance

Run one naturally completed month only after lanes A and B pass the short gate
and their elapsed-time delta is acceptable. Use:

- `Enable_Signal_Feature_Export=true`;
- `Enable_Logs=false`;
- `Enable_File_Logs=false`;
- `ML_Inference_Mode=ML_INFERENCE_DISABLED`;
- a new semantically correct 2026 `Signal_Feature_Run_Id`.

The one-month folder becomes eligible for DuckDB and XGBoost research only
after the same validator and count reconciliation pass.

## Final Accepted Runtime Evidence

On 2026-07-11 the owner completed a one-week C lane using XAUUSD M1 real ticks
from 2026-06-07 through 2026-06-13. Export and diagnostic file logs were both
enabled. The run completed naturally in `0:02:03.624` with 2,322,421 ticks and
6,889 bars.

Strict schema v7 validation passed:

- `export_status=OK`;
- 699 cycles, 2,859 revisions, 6,889 attempts, and 14,012 admissions;
- 1,366 features, 1,365 outcomes, and 1,365 joined supervised rows;
- 4,095 leg outcomes, all with broker-confirmed closure;
- maximum 22 active paths;
- zero TP-zero, wrong-side TP, target-R mismatch, duplicate-ID, orphan, frozen
  anchor, or genealogy contradictions.

Two expected run-end limitations remain non-blocking: one broker-entered
feature had no close/outcome inside the test range, and one broker-valid profit
outcome ended with `RUN_ENDED` and no path-ratio label. Both are handled safely
by the dataset validator.

Lane A used identical trading inputs with export and file logs disabled. It was
stopped manually after progressing more slowly under external host contention.
Matching checkpoints produced identical orders, prices, volumes, SL, and TP,
so no telemetry-driven trading divergence was observed. The owner accepted the
correctness and bounded-performance evidence, waived lane B and the one-month
run for this closeout, and authorized archival. This acceptance does not claim
profitability, an approved runtime model, or a controlled A/B overhead ratio.
