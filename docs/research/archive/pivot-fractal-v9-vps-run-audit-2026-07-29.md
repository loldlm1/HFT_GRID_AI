# Pivot Fractal V9 VPS Strategy Tester Audit

**Date**: 2026-07-29
**Status**: Acceptance-blocking diagnostic evidence; not an accepted research dataset
**Run**: `us30_test_run_1`
**Owner**: HFT Grid AI pivot-fractal acceptance

## Scope And Provenance

This note records a read-only audit of the VPS Strategy Tester run requested for
the pivot-fractal engine. The remote files were inspected from:

- `/home/admin/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/Common/Files/`
- `/home/admin/.wine/drive_c/Program Files/MetaTrader 5-1/MQL5/Experts/`

No remote file was modified. The local audit copy is temporary evidence under
`/tmp/hft-grid-ai-vps-audit.FGrOcc/`; it is not a repository dataset and must
not be relabeled or copied into an accepted run folder.

The local and VPS `HFT_Grid_AI.ex5` binaries matched at SHA-256
`ea03fc41be43ad051a1b1c3e7bd1bb466b82d64a3e76ad9ef1af7749c2e26a45`.

## Run Configuration

| Fact | Observed value |
| --- | --- |
| Symbol/model | `US30`, `M1`, `Exness-MT5Real11`, real ticks |
| Test interval | `2026.01.12 00:00` through `2026.07.25 00:00` |
| Execution delay | `500 ms` |
| V9 export | enabled, run id `us30_test_run_1` |
| File/query diagnostics | enabled; normal EA logs disabled |
| Ticks/bars | `38,911,630` / `191,311` |
| Tester runtime | `0:06:00.514` test, `0:06:04.254` total |
| Memory | `1204 MB`, including `832 MB` tick data |

The tester completed successfully. Broker-side `Invalid stops`, `Market
closed`, and a small number of close-race modification rejections are expected
fail-closed lifecycle facts, not tester crashes.

## Export Counts And Completion

| V9 table | Rows |
| --- | ---: |
| `pivot_windows` | 23,375 |
| `pivot_levels` | 163,625 |
| `signal_attempts` | 49,714 |
| `signal_features` | 298,284 |
| `execution_checks` | 147,033 |
| `trailing_events` | 40,525 |
| `signal_outcomes` | 48,427 |

The exporter reported `export_status=OK`, zero duplicate identities, zero
referential-integrity errors, zero row-integrity errors, and zero incomplete
feature rows. The run reported `completion_status=CENSORED`: 48,439 attempts
were sent successfully, but 12 accepted sends were still open at the tester
cutoff and therefore had no broker outcome. The remaining attempts without an
outcome were denied or send-failed, as expected.

The original run is therefore useful diagnostic evidence only. It is not a
natural-completion V9 dataset or training/approval evidence.

## Checks That Passed

- Classic PP/S1-S3/R1-R3 calculations matched raw source prices; maximum
  absolute formula error was approximately `5.1e-11`.
- All 23,375 windows had seven strictly ordered normalized levels, and source
  candles were previous completed broker-native candles.
- Window expiration, weekend/session gaps, broker/analysis time conversion,
  and the Exness US-calendar DST transition passed the audit.
- Bid side/touch semantics, Ask buy execution, Bid sell execution, and spread
  facts passed except for the causal rows listed below.
- The exact `(symbol, timeframe, active_bar_open, level)` identity was unique;
  same-tick candidate ordering was deterministic; 3,439 confluence groups were
  observed with a maximum group size of 18.
- All 14 direction/level route families were observed, and every exported
  route stop/target matched the approved symmetric matrix.
- Trailing validation found no route milestone mismatch, widened stop, stale
  confirmation, ticket ownership mismatch, post-close trailing event, or final
  stop mismatch.
- Broker checks were contiguous and ticket-owned. Broker outcomes were causal,
  broker-confirmed, and retained captured route geometry.
- Each attempt had six context rows with valid structure tokens. Raw `%B`
  values remained unclamped, including legitimate values outside `0..100`.

The strict validator also passed on a temporary derived copy after removing the
ten causal attempts. That filtered result is a diagnostic localization aid,
not an accepted replacement for the original run.

## Acceptance-Blocking Findings

### 1. Observation-time causality is not enforced

The strict validator found ten attempts whose
`previous_m1_close_boundary_broker_time` was later than the trigger. Two of
those also triggered one second before the pivot window's
`active_bar_open_broker_time`. Examples include triggers at `12:29:59` for a
window opening at `12:30:00`.

The current refresh paths read `iTime(..., 0)` without receiving the observed
tick time (`services/trading_signals/pivot_context_features.mqh` and
`services/trading_signals/pivot_fractal_engine_state.mqh`). In the tester,
series visibility can advance to the next bar while the observation tick is
still in the previous second. This allows a future M1 context and, in two
cases, an early pivot window to become eligible.

Required correction:

1. Pass the observation tick time into M1 context refresh, pivot-window refresh,
   retry scheduling, and candidate discovery.
2. Do not adopt an `iTime(..., 0)` bar whose open is after the observation tick;
   retain the last causal context/window or defer until a causal tick arrives.
3. Add a defensive candidate guard requiring
   `active_bar_open <= trigger_broker_time`.
4. Add strict negative fixtures for future M1 boundaries and pre-open signals.

### 2. Feature snapshots drift inside one confluence tick

`ProcessPivotSignalAttempt()` currently calls
`CapturePivotContextFeatureSnapshot()` independently for each candidate in
`services/trading_signals/execution_controller.mqh`. Sequential market sends
under the `500 ms` tester delay can advance indicator state between candidates.

There were 3,439 same-tick confluence groups. The 4,254 candidates after each
group's first candidate were exposed to sequential capture; 2,492 groups
actually showed feature variation. Comparing each later row with its group's
first row found 2,768 later signal rows with changed feature values. Maximum
shift-0 `%B` differences were:

| Context | Maximum absolute difference |
| --- | ---: |
| `M1` | 84.1655 |
| `M15` | 34.9512 |
| `M30` | 18.2086 |
| `H1` | 8.8693 |
| `H4` | 5.9345 |
| `D1` | 0.8133 |

Required correction:

1. Capture one six-timeframe `PivotContextFeatureSnapshot` immediately after
   candidate discovery and before processing or sending any candidate for the
   tick.
2. Copy that frozen snapshot into every candidate signal in the batch.
3. Add an offline validator invariant and a negative fixture requiring exact
   feature equality within each maximal contiguous attempt batch with identical
   trigger tick/context facts. Contiguity avoids grouping unrelated later ticks
   that happen to share the same second and prices.
4. Keep the existing V9 headers unless implementation evidence proves a new
   capture timestamp is necessary; the trigger timestamp is the intended
   snapshot boundary.

This correction is both a data-integrity fix and a hot-path optimization: it
removes repeated indicator buffer reads for same-tick confluence candidates.

## Efficiency Assessment

The six-month real-tick run completed in about six minutes, so the current
engine was operationally fast on the VPS. At the time of this diagnostic it was
not yet possible to claim an export overhead ratio because there was no paired
export-off baseline over the same interval.

Observed output was approximately:

- V9 TSV files: `251.3 MB` (`signal_features.tsv` and
  `execution_checks.tsv` were the largest files).
- `query_debug.txt`: `48.6 MB`, `187,151` lines.
- Two tester logs: approximately `190.9 MB` combined.
- Query-debug categories: 49,714 attempts, 48,581 send results, 48,427
  terminal records, and 40,428 trailing records.
- Trailing retry telemetry included 4,274 blocked retries and 5 rejected
  retries; one signal accumulated 624 retry rows during repeated session or
  geometry blocks.

The next benchmark must use identical symbol/model/date/input settings with
file/query diagnostics disabled in the normal lanes:

| Lane | V9 export | File/query diagnostics | Purpose |
| --- | --- | --- | --- |
| A | off | off | execution/runtime baseline |
| B | on | off | normal research export overhead |
| C | on | on | diagnostic-only logging cost |

Record elapsed time, ticks/sec, peak memory, total output bytes, row counts,
and order/price parity at matching checkpoints. Do not compact retry telemetry
or weaken retry behavior before this comparison; if output remains a material
cost, coalesce only identical repeated diagnostic rows while retaining the
first, changed, and terminal facts.

## Disposition

The VPS run confirms that the pivot formulas, symmetric route matrix, trailing
model, broker safety kernel, and V9 row relationships are fundamentally sound.
It does not pass final acceptance because causality is violated, confluence
features are not frozen, and the run is censored. No profitability conclusion,
runtime ML approval, live-rollout authorization, or schema migration follows
from this evidence.

At the time of this diagnostic, the active plan still required a corrective
sprint for the two causal defects, validator coverage, paired efficiency
measurement, final compile, natural-completion tester run, and closeout commit.

## Corrective Sprint 9 Evidence

This section records separate post-fix evidence. It does not mutate, filter, or
relabel the original `us30_test_run_1` export above.

### Final Compile And Binary Parity

- The post-fix MetaEditor compile reported `0 errors, 0 warnings`; the parsed
  result is retained in `logs/compile/agentic-build.log`.
- Local and both VPS acceptance terminal copies have the same SHA-256:
  `866d8bf3439a82c3570f029f94564b37781a53b934b612ccc2062c497cb2b07b`.
- The compile and tester used the existing EA input surface. `ExecutionMode=500`
  ms was held constant as tester stress evidence only; it is not an EA input or
  trading rule.

### Paired Runtime Lanes

The lanes used identical US30/M1 real-tick settings for `2026.07.21` through
`2026.07.24`, with normal EA and file logs disabled. Lane A disabled V9 export;
Lane B enabled it.

| Lane | Ticks | Test time | Ticks/sec | Memory | Export output |
| --- | ---: | ---: | ---: | ---: | ---: |
| A: export off | 578,669 | 5.301 s | 109,162 | 174 MB | none |
| B: export on | 578,669 | 5.471 s | 105,770 | 253 MB | 5,627,171 bytes |

Export-on elapsed overhead was `3.21%`. The lanes had `5,823` byte-identical
broker-lifecycle lines at matching checkpoints (SHA-256
`51c63462331e909eb80e17abd0e16e8c9babb8c5a47c1ced98d4c163e51d411f`). The
export lane contained `1,060` attempts and `6,360` feature rows. No query-debug
or file-log diagnostics were enabled in either measurement lane.

### Natural Unfiltered Acceptance

The new run is preserved outside Git at
`/tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs/sprint9_natural_us30_final_20260112_20260725`.
It used the same `500 ms` tester delay, export enabled, and query/file
diagnostics disabled. The tester completed naturally after `38,911,630` ticks
and `191,311` bars in `6:13.174`, using `1,199 MB` including tick history.

`run_summary.tsv` reports `export_status=OK`, `completion_status=NATURAL`,
`49,716` attempts, `298,296` features, `48,431` broker outcomes, zero
incomplete features, zero duplicate identities, and zero referential or row
integrity errors.

The strict validator and offline dataset/audit found:

- all `163,590` pivot levels matched classic formulas (maximum error
  `5.09e-11`), with zero invalid ladders, misaligned/overlapping windows,
  future M1 contexts, pre-open or post-window attempts, or Bid-touch violations;
- all 14 level/direction families, `3,442` contiguous confluence batches
  (maximum size `18`), and zero divergent frozen feature snapshots;
- zero route SL/TP geometry, trailing milestone, desired/confirmed stop, TP,
  ordering, final-stop, ticket, or broker-owner mismatches; and
- correct Exness DST offsets (`-60` before the US transition and `0` after it),
  with zero timestamp conversion errors.

Twelve filled positions were still open at the interval boundary and therefore
have no broker outcome. This is expected right-censoring from the chosen test
interval; the broker-outcome dataset excludes those rows and does not treat the
condition as an abnormal tester stop.

### Final Disposition

Sprint 9 acceptance passes the causal, frozen-feature, pivot, route, trailing,
broker, time, dataset, and performance gates on the new unfiltered evidence.
The original `us30_test_run_1` remains a preserved failing diagnostic artifact,
and no profitability conclusion, runtime model approval, or live-rollout
authorization follows from either run. The corrective plan is archived at its
single Sprint 9 commit; reverting it returns to rollback point `1c9d573`.
