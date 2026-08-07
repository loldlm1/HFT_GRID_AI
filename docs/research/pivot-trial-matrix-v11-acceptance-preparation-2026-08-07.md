# Pivot Trial Matrix V11 Acceptance Preparation - 2026-08-07

## Status And Boundary

**Status**: Initial MetaEditor compile passed, but the first human real-tick run
failed strict V11 acceptance. Sprint 11 corrects the exporter lifecycle and
Sprint 12 owns the final corrective compile and renewed human evidence.

This protocol validates strict schema V11, the virtual SL/TP trial matrix,
bounded volatility re-entries, the unchanged one-order broker lane, and
broker-parity calibration. It does not create an automated Strategy Tester
harness, approve an MT5 runtime model, or authorize live rollout.

Raw TSV files are evidence. Do not edit them to satisfy validation. Preserve a
failed run and its artifacts when any gate fails.

## Frozen Candidate

- Branch: `bot/pivot_points_fractal`.
- Source candidate before acceptance-only documentation:
  `b3ebc59f463d72d1c378c3575ee6115876691ac5`.
- Sprint 8 rollback point: `9b55b5ddd70777df7da23c63e3f360d8280c96c2`.
- Entrypoint: `HFT_Grid_AI.mq5`.
- Initial compile mode used in Sprint 10: real `/compile`, not `/s`.
- Sprints 1-9 add no MQL5 test harness, test EA/script, CI module, or automated
  Strategy Tester orchestration.

### Precompile Binary Evidence

MetaEditor was intentionally not invoked for this V11 candidate before Sprint
10. The existing binary and compile log predate the V11 source commits:

| Artifact | Size | Modified | SHA-256 |
| --- | ---: | --- | --- |
| `HFT_Grid_AI.ex5` | 163,068 bytes | `2026-08-06 21:32:25.797037875 -0400` | `f080092b463e6ddd648407b7d8d955d841e75ca90be4464cd3e16c45c870dec8` |
| `logs/compile/agentic-build.log` | 20,834 bytes | `2026-08-06 20:50:14.605711269 -0400` | `b62a593f578bd09465ff307caf01c5748bffc0db1498f25c4c5e192dc83d9b32` |

Sprint 10 verified these precompile values before invoking MetaEditor and
recorded the regenerated binary metadata and parsed `0 errors, 0 warnings`
result. Because runtime acceptance exposed a source defect, Sprint 12 must
compile the corrected source again before renewed human evidence.

### Sprint 10 Compile Evidence

The frozen precompile hashes above were verified unchanged immediately before
the initial acceptance compile. The real `/compile` command completed with the
following evidence:

| Artifact/result | Evidence |
| --- | --- |
| MetaEditor result | `0 errors, 0 warnings, 10804 ms elapsed, cpu='X64 Regular'` |
| Compile helper result | `PASS` |
| Wine process return code | `1`; retained as a wrapper discrepancy because the parsed MetaEditor result is clean |
| `HFT_Grid_AI.ex5` | 234,334 bytes; modified `2026-08-07 11:44:19.120503799 -0400`; SHA-256 `5773fd16cca6d4fd487c0354b206dde259f9a05ce843bee9f8eb2479ec4b60ac` |
| `logs/compile/agentic-build.log` | 23,148 bytes; modified `2026-08-07 11:44:19.121503764 -0400`; SHA-256 `98616607f9c6e54a9c03b8d804d985fea5477b923996c74e5a7a4d99b52bf52e` |

The changed binary size, timestamp, and hash prove that MetaEditor regenerated
the V11 `.ex5`. No intermediate Sprint 1-9 compile was performed. This compile
remains valid evidence for the failed candidate, but it is superseded by the
required Sprint 12 compile after the lifecycle correction.

## First Human Run Audit - Failed Acceptance

### Evidence Identity

- Symbol and setup: `XAUUSD`, `EXNESS_SESSION`, Macro `H1`, Micro `M3`, export
  enabled, run ID `test_run_1`.
- Tester interval: `2026.06.08 00:00:00` through
  `2026.07.31 20:57:59` broker time.
- Debug evidence: external Common Files `query_debug.txt`, 5,742 lines,
  SHA-256 `1bf4ce10897438f3187f3190fc5f0487a3ab412e931a2318c0522292515511e0`.
- V11 evidence: eight raw TSV files under external Common Files
  `PivotFractalV11/runs/test_run_1/`, approximately 232 KB.
- Raw query and TSV evidence was inspected read-only and remains unedited.

### Deterministic Exness Time - Pass

All 327 available broker/analysis/offset timestamp triplets satisfy:

```text
analysis_time = broker_time + offset_minutes
```

Every observed offset is `0`. That is correct for XAUUSD across the June-July
2026 UK-DST interval. Static source review confirms that `XAU`, `XAG`, `XPT`,
and `XPD` prefixes use the UK calendar, including suffixed broker symbols. The
analysis offset is `-60` outside UK DST and `0` from the last Sunday of March at
01:00 through the last Sunday of October before 01:00. Broker time remains the
causal clock; normalization is export-only.

This run empirically covers the summer branch. The season-independent behavior
comes from the explicit yearly calendar calculation and symbol-prefix mapping;
a future winter or boundary sample remains useful additional broker evidence,
not a known defect.

### Query Debug Trade Consistency - Pass

The file contains one session header and the following complete event sets:

| Event/result | Rows |
| --- | ---: |
| `PIVOT_ATTEMPT` | 1,922 |
| `PIVOT_SEND_RESULT` | 1,910 |
| Successful sends | 1,909 |
| Failed sends | 1 |
| Pre-send denials | 12 |
| `PIVOT_TERMINAL` | 1,909 |
| Broker TP | 951 |
| Broker SL | 957 |
| Manual tester-end close | 1 |

Read-only reconciliation found zero duplicate or missing event IDs and zero
identity, direction, geometry, normalized-volume, quote-money, 1R, attempt
status, terminal-set, terminal-sign, or binary-label inconsistencies. Every
successful send has one terminal event. The one failed send is consistently
audited as retcode `10016`, `Invalid stops`; all twelve no-send attempts are
explicit `DENIED` rows with unavailable request geometry.

The real broker lane therefore remains internally consistent. This does not
make the V11 research export acceptable because the export lifecycle fails
independently after the first few windows.

### Partial V11 Structure - Valid Before Failure

The run writes exactly the eight strict V11 filenames. Before exporter failure
it records three windows, five origins, 142 trials, 128 virtual outcomes, 19
execution checks, and four broker outcomes. The valid prefix contains:

- five origins with exactly sixteen index-0 matrix cells each;
- the exact four-SL-policy by TP `1,2,3,5` Cartesian product for every origin;
- 57 re-entry rows with contiguous chain indices;
- five parity shadows, four parity outcomes, and four strict parity pairs;
- four strict parity terminal matches and zero mismatches;
- no duplicate identity, row-integrity, or state-cap error.

These facts demonstrate that the matrix geometry and chain behavior reached
runtime, but they cannot authorize research use of a truncated failed run.

### Blocking V11 Failure And Root Cause

`run_summary.tsv` reports `completion_status=NATURAL` but
`export_status=FAILED`, `referential_integrity_error_count=2`, only three
window rows, and only five origin rows despite the broker log continuing
through July. Strict validation fails with fourteen active trials missing
outcomes: thirteen matrix trials and one broker-parity shadow.

The first failure is deterministic lifecycle control flow:

1. A valid H1 window expires and `PivotV11RecordWindow()` exports then removes
   its pending origins.
2. A broker position belonging to one exported origin can remain open beyond
   that H1 boundary.
3. Normal broker reconciliation continues calling `PivotV11UpdateOrigin()` on
   the bounded active `PivotSignal`.
4. The exporter no longer finds the removed pending origin, raises
   `UPDATE_ORIGIN_NOT_FOUND`, and disables all later V11 writes.

Concrete evidence is broker signal `broker_13479693207490312625`: it opens at
`2026.06.08 02:01:28`, its origin window expires at `03:00:00`, and it closes
at `05:30:53`. The secondary referential error is
`PARITY_OUTCOME_MISSING` during summary generation because the already-disabled
exporter cannot finish the outstanding parity shadow.

There is also an observability defect: `PivotV11MarkFailed()` prints the first
failure but does not append `PIVOT_V11_EXPORT_FAILED` to `query_debug.txt` when
file logging is enabled. The failed debug file therefore contains no direct
exporter-failure event even though the summary records failure.

### Corrective Disposition

Sprint 10 stops closeout and preserves this evidence. Sprint 11 adds explicit
`origin_export_finalized` state to active signals, marks it only after a window
record succeeds, allows later updates to no-op only for that explicit state,
keeps unknown origins fail-closed, and writes the first exporter failure once
through the existing query-debug logger. Sprint 11 uses static and existing
Python validation only. Sprint 12 performs the sole corrective compile and
waits for a fresh unique real-tick V11 run before commit or archive.

## Precompile Validation Record

The frozen candidate has the following non-compiler evidence:

- Python compileall: pass.
- Full Python contract suite: 22 tests pass.
- Exact MQL5/Python V11 header parity: eight files pass.
- Exact manifest key/fixed-token parity: 48 keys pass.
- Deterministic V11 fixture: validation, build, and audit pass.
- Fixture derived counts: 18 matrix-long rows, one initial-wide origin, 16
  eligible virtual rows, 16 policy chains, and one calibration pair.
- Training support guard: expected fail-closed result
  `Not enough rows: 16 < 500`.
- Broker safety sweep: one `OrderSend`, one `OrderCheck`, FOK only, no
  `TRADE_ACTION_SLTP`, and no trade mutation in matrix modules.
- Resource/cleanup sweep: two cached Bands handles, export-gated creation,
  deinit censoring before summary, state reset, and frontend isolation.
- `git diff --check`: pass.

These checks support the release-candidate freeze but do not replace the final
MetaEditor compile or human real-tick evidence.

## Fixed Human Setup

Use `Every tick based on real ticks`. Keep the following fixed between the
export-disabled and export-enabled performance runs:

| Setting | Required value/evidence |
| --- | --- |
| Symbol | Record exact broker symbol, including suffix |
| Broker/session | Record broker and `Broker_Session` |
| Macro/Micro | `PERIOD_H1` / `PERIOD_M3`, unless the evidence states another valid fixed pair |
| Lot mode | `EXECUTION_LOT_REFERENCE_BALANCE_PERCENT` |
| Lot size | `0.01` |
| Tester interval | Same start/end broker timestamps for both performance runs |
| Deposit/leverage | Same values for both runs |
| Logs | `Enable_Logs=false`, `Enable_File_Logs=false` for performance evidence |
| Export run | `Enable_Signal_Feature_Export=true` and unique `Signal_Feature_Run_Id` |
| Control run | `Enable_Signal_Feature_Export=false` |
| EA instances | One instance for the account/symbol |
| Account mode | Hedging for broker execution acceptance |

Record tester settings, start/end timestamps, terminal build, broker server,
symbol properties, and screenshots or broker-history references outside Git.

## Runtime Acceptance Sequence

### 1. Macro Window And Origin Identity

- [ ] Previous completed Macro shift `1` owns PP/S1..S3/R1..R3.
- [ ] Active-window times are broker-native and no missing candle is synthesized.
- [ ] PP above/below/equal arming follows one fixed role per window.
- [ ] Identity is `(symbol, Macro timeframe, active bar open, level)` and first
  trigger consumes it even when routing or execution fails.
- [ ] Same-tick path order remains deterministic for downward and upward moves.

### 2. Initial Sixteen-Cell Matrix

Select at least one feature-complete origin and join `signal_origins.tsv` to
`virtual_trials.tsv` by `origin_id`.

- [ ] Exactly 16 `trial_role=MATRIX`, `reentry_index=0` rows exist.
- [ ] The Cartesian product is exactly four SL policies by TP `1,2,3,5`.
- [ ] `policy_id` and `trial_id` are unique and stable.
- [ ] Structural cells copy the structural risk route; volatility cells use
  frozen `origin_micro_band_width_0 * 0.13/0.21/0.34` before normalization.
- [ ] Buy trial entry is Ask and exit side is Bid; sell entry is Bid and exit
  side is Ask.
- [ ] Risk rounds outward to whole trade ticks and TP is exact integer R from
  normalized risk.
- [ ] Minimum risk is spread plus `max(stops, freeze)` plus one trade tick.
- [ ] Failed feature, geometry, distance, or money plans remain explicit
  ineligible rows and never become broker orders.

### 3. Independent TP Chains And Re-entry

Use naturally observed chains where available. Keep each policy chain separate
by `(origin_id, sl_policy, tp_r_multiple)`.

- [ ] A `TP_FIRST` chain is terminal and never reopens.
- [ ] Only `SL_FIRST` permits the same chain's next generation.
- [ ] Retry indices are contiguous and limited to `0..3`.
- [ ] `preceding_loss_count`, parent trial, source outcome, and next trial links
  reconcile exactly.
- [ ] Retry entry uses the observed executable quote, not the prior SL threshold.
- [ ] Frozen origin width remains unchanged while retry features are fresh.
- [ ] At most one next generation per policy chain is created on one tick.
- [ ] Closed chain nominal R equals the sum of its terminal trial R values.

### 4. Pivot Boundary, Gap, Expiry, And Censoring

- [ ] Buy `PP/S1/S2` retries remain more than one trade tick above `S1/S2/S3`
  for both entry and proposed SL.
- [ ] Sell `PP/R1/R2` retries remain more than one trade tick below `R1/R2/R3`
  for both entry and proposed SL.
- [ ] Equality and gap-through suppress the old-context retry.
- [ ] `S3`/`R3` use the index-3 cap without an outer boundary.
- [ ] An active trial may finish after origin expiry, but no new retry starts.
- [ ] Run-end active rows become `CENSORED` and never receive a binary target.
- [ ] `active_state_peak <= 2048` and `state_capacity_failed=0` in accepted runs.

### 5. Unchanged Broker Lane

- [ ] One consumed identity can cause at most one real structural 1R send.
- [ ] Observation and fresh pre-send checks are distinct; only fresh facts
  authorize `OrderSend`.
- [ ] Requests are `TRADE_ACTION_DEAL` with `ORDER_FILLING_FOK`.
- [ ] Broker SL/TP stay immutable; no trailing, break-even, partial close,
  resize, or `TRADE_ACTION_SLTP` occurs.
- [ ] Reconciliation remains symbol/magic/ticket owned.
- [ ] Broker deal history alone populates actual fill, close, gross, commission,
  swap, fee, net, budget R, and execution R.
- [ ] Frontend displays real positions only and nonvisual mode creates no chart
  objects.

### 6. Broker-Parity Calibration

- [ ] Every accepted send creates one `BROKER_PARITY` trial after acceptance.
- [ ] Denied and failed sends create no parity row.
- [ ] Parity entry, SL, TP, and normalized volume equal the submitted request.
- [ ] Parity is outside the sixteen-cell matrix, retries, policy support, and ML.
- [ ] Each closed broker outcome with `parity_trial_id` joins one parity trial
  and one parity outcome.
- [ ] Manual, mixed, stop-out, expert, other, feature-incomplete, and censored
  pairs have explicit calibration exclusions.
- [ ] Every strict eligible pair agrees on TP versus SL. Any unexplained
  mismatch blocks acceptance.
- [ ] Timing, entry/exit price, virtual gross, broker gross/execution-R, and
  actual cost deltas are reviewed as distributions, not assumed equal.

### 7. Deterministic Time And Features

- [ ] Broker time owns windows, triggers, retries, orders, outcomes, and splits.
- [ ] Analysis time and offset follow the configured fixed/Exness DST policy.
- [ ] Micro `%B 0..5`, Macro pivot `%B 0..5`, shift-0 Micro width, and shift-1
  Macro width reproduce from the recorded Bands facts.
- [ ] One trigger batch shares one origin feature snapshot; retry processing
  captures at most one shared retry snapshot per tick.
- [ ] Missing features affect research eligibility only, never broker admission.

## Static Fallback For Market-Unreachable Cases

Human real-tick evidence remains mandatory overall, but a specific rare branch
may use named static evidence when the selected market interval cannot reach it:

| Branch | Required static evidence |
| --- | --- |
| Outward tick normalization and integer R | `NormalizePivotTrialRiskOutward`, `BuildPivotTrialStopAndTakeProfit`, validator mutations |
| Next-pivot boundary equality/gap | `PivotTrialBoundaryEligible`, `PivotTrialReentryBoundaryEligible`, schema boundary mutations |
| TP-consumed chain cannot reopen | `ConfigurePivotTrialContinuation`, TP-retry rejection test |
| Origin expiry blocks only new retry | `PivotTrialOriginWindowActive`, continuation validator |
| Index-3 extreme cap | `PIVOT_TRIAL_MAX_REENTRY_INDEX`, continuation validator |
| Run-end censoring | `BuildPivotTrialRunEndOutcome`, `FinalizePivotTrialMatrixForExport` |
| Capacity failure | `AppendPivotTrialActiveState`, state-cap summary validation |
| Failed send has no parity | Post-acceptance call order in `SendPivotMarketOrder`, parity schema mutations |

Record the exact function/test reference and why natural market evidence was not
available. Static fallback cannot replace broker lifecycle, parity, natural-run,
performance, DST, or chart acceptance.

## Strict V11 Research Commands

```bash
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV11/runs"
export PIVOT_RUN_ID="<run_id>"
export PIVOT_DATASET_ID="<dataset_id>"
export PIVOT_AUDIT_ID="<audit_id>"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --dataset-id "$PIVOT_DATASET_ID"

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --audit-id "$PIVOT_AUDIT_ID" \
  --minimum-group-support 30

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --model-id <model_id>
```

The raw run must contain exactly eight files. Acceptance requires
`completion_status=NATURAL`, `export_status=OK`, zero duplicate/referential/row
integrity errors, no state-cap failure, and no strict parity mismatch.

## Evidence Record

Sprint 10 records the failed first run. Sprint 12 replaces pending/failing
acceptance values with a fresh unique run without overwriting this evidence:

| Evidence | Result |
| --- | --- |
| Final source commit | Pending Sprint 11 correction and Sprint 12 acceptance |
| Compile result and elapsed time | Initial candidate pass: `0 errors, 0 warnings`, 10,804 ms; Wine process return code `1` recorded as a wrapper discrepancy; corrective compile pending Sprint 12 |
| Postcompile `.ex5` size/mtime/SHA-256 | 234,334 bytes; `2026-08-07 11:44:19.120503799 -0400`; `5773fd16cca6d4fd487c0354b206dde259f9a05ce843bee9f8eb2479ec4b60ac` |
| Symbol, broker, tester interval | Failed run: XAUUSD, Exness/`EXNESS_SESSION`, `2026.06.08 00:00:00` through `2026.07.31 20:57:59` |
| V11 run ID and folder size | Failed run: `test_run_1`, approximately 232 KB |
| Windows/origins/matrix/retry/parity rows | Failed run: 3 / 5 / 137 / 57 / 5; export truncated |
| TP/SL/censored/ineligible counts | Failed run matrix: 39 TP / 85 SL / 0 censored / 0 ineligible; 13 active matrix outcomes missing |
| Policy-chain terminal counts | Failed run: 39 TP complete / 10 structural SL / 6 re-entry cap / 12 next-pivot boundary / 0 origin-expired / 0 run-end censored / 0 ineligible |
| Broker outcomes and exclusions | Exported prefix: 4 outcomes, 4 binary eligible, 3 TP, 1 SL, 0 excluded; query debug full run: 951 TP, 957 SL, 1 manual |
| Strict parity pairs/matches/mismatches/exclusions | Failed exported prefix: 4 / 4 / 0 / 0; one active parity outcome missing after exporter failure |
| Active-state peak/cap status | Failed run: 25 / 2048, no capacity failure |
| Dataset/audit/model artifact IDs and sizes | Pending |
| Export-disabled elapsed time | Pending |
| Export-enabled elapsed time and overhead | Pending |
| Human chart/broker-history observations | Broker/query consistency passes; V11 research acceptance fails |
| Static fallbacks used | Pending |

## Blocking Conditions

Stop closeout and preserve evidence when any of the following occurs:

- MetaEditor reports any error or warning, or `.ex5` is not regenerated.
- The broker lane sends more than one order per consumed identity, modifies
  protection, loses ticket ownership, or mixes virtual and actual money facts.
- The matrix is not exactly sixteen index-0 cells for a declared origin.
- Retry indices skip/duplicate, TP reopens, or a boundary/expiry rule is wrong.
- V11 strict validation, build, audit, or support guards fail.
- A strict eligible parity pair has an unexplained TP/SL mismatch.
- State capacity, duplicate identity, referential integrity, row integrity, or
  export status fails.
- Performance or file growth is unbounded or operationally unacceptable.

Final acceptance remains offline-research-only. Older-engine positions must be
flat, the account must be hedging, and one EA instance per account/symbol is
required before any separately authorized future deployment.
