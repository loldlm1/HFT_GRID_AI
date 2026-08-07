# Pivot Trial Matrix V11 Acceptance Preparation - 2026-08-07

## Status And Boundary

**Status**: Release candidate prepared; final MetaEditor compile and human
real-tick Strategy Tester acceptance are pending Sprint 10.

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
- Compile mode reserved for Sprint 10: real `/compile`, not `/s`.
- Sprints 1-9 add no MQL5 test harness, test EA/script, CI module, or automated
  Strategy Tester orchestration.

### Precompile Binary Evidence

MetaEditor was intentionally not invoked for this V11 candidate before Sprint
10. The existing binary and compile log predate the V11 source commits:

| Artifact | Size | Modified | SHA-256 |
| --- | ---: | --- | --- |
| `HFT_Grid_AI.ex5` | 163,068 bytes | `2026-08-06 21:32:25.797037875 -0400` | `f080092b463e6ddd648407b7d8d955d841e75ca90be4464cd3e16c45c870dec8` |
| `logs/compile/agentic-build.log` | 20,834 bytes | `2026-08-06 20:50:14.605711269 -0400` | `b62a593f578bd09465ff307caf01c5748bffc0db1498f25c4c5e192dc83d9b32` |

Sprint 10 must verify these precompile values before invoking MetaEditor, then
record the regenerated binary metadata and parsed `0 errors, 0 warnings` result.

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

Fill this table during Sprint 10 without inventing unavailable values:

| Evidence | Result |
| --- | --- |
| Final source commit | Pending |
| Compile result and elapsed time | Pending |
| Postcompile `.ex5` size/mtime/SHA-256 | Pending |
| Symbol, broker, tester interval | Pending |
| V11 run ID and folder size | Pending |
| Windows/origins/matrix/retry/parity rows | Pending |
| TP/SL/censored/ineligible counts | Pending |
| Policy-chain terminal counts | Pending |
| Broker outcomes and exclusions | Pending |
| Strict parity pairs/matches/mismatches/exclusions | Pending |
| Active-state peak/cap status | Pending |
| Dataset/audit/model artifact IDs and sizes | Pending |
| Export-disabled elapsed time | Pending |
| Export-enabled elapsed time and overhead | Pending |
| Human chart/broker-history observations | Pending |
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
