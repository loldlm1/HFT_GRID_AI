# Extremum Engine Statistics Flow

This is the active operator workflow for the always-on M1 `EXTREMUM_V1`
collector, schema v8 exports, broker execution checks, and research tooling.

## Runtime Genealogy

- Stoch Structure slot `0` is the provisional source.
- `BOTTOM` creates bullish attempts; `PEAK` creates bearish attempts.
- The existing M1 `high_1`/`low_1` breakout is the trigger.
- Same-type deeper extrema create revisions; a type transition closes the
  cycle.
- Completed slots `1` and `2` freeze the cycle range.
- Intrinsic attempts are recorded after valid geometry and before operational
  denial.
- Broker checks are captured at observation and refreshed before filters and
  again immediately before `OrderSend`.

```text
cycle -> revision -> intrinsic attempt
                         |-> ATTEMPT_OBSERVED broker facts
                         |-> simulated path label
                         |-> PRE_FILTER / PRE_SEND / SEND_RESULT checks
                         `-> optional broker-confirmed outcome
```

Simulation facts never create broker outcomes or overwrite broker tickets,
volume, prices, SL/TP, close state, or realized profit.

## Time Contract

Every schema v8 event retains broker time, analysis time, and offset minutes.

- `FIXED_TIME_SESSIONS`: analysis time equals broker time.
- `EXNESS_SESSION`: winter analysis time is broker time minus 60 minutes under
  the instrument's US or UK DST calendar.
- Broker time owns chronology, durations, session checks, and execution.
- Analysis time owns session/weekday/cyclical features, normalized calendar
  grouping, and pattern matching.
- Duplicate analysis times are ordered by broker time and stable event ID.

## Export Files

Set `Enable_Signal_Feature_Export=true` and provide a unique
`Signal_Feature_Run_Id`. MT5 writes to:

```text
Common\Files\DeterministicSignalML\runs\<run_id>\
```

Schema v8 contains exactly these active tables:

- `run_manifest.tsv`: run/config identity, time policy, and feature policy.
- `engine_cycles.tsv`: finalized or censored cycles.
- `engine_revisions.tsv`: point-in-time revisions.
- `engine_attempts.tsv`: intrinsic attempts and separate simulated path facts.
- `execution_checks.tsv`: observation, pre-send, send-result, and lifecycle
  broker facts.
- `signal_features.tsv`: broker-entered feature snapshots.
- `signal_outcomes.tsv`: broker-confirmed outcomes only.
- `run_summary.tsv`: final counts and `export_status`.

Keep `Enable_Logs=false` and `Enable_File_Logs=false` for normal evidence runs.
File logs are a separate diagnostic/performance lane. A manually stopped run
may help debugging but is not an accepted dataset; require natural completion,
`run_summary.tsv`, `export_status=OK`, and strict validation.

## Validate And Build

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export RUNS_ROOT="$MT5_COMMON_FILES/DeterministicSignalML/runs"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$RUNS_ROOT" \
  --run-id <schema_v8_run_id> \
  --dataset-id <schema_v8_dataset_id> \
  --schema-version 8 \
  --feature-set-id schema_v8_extremum_engine_xgb \
  --target-family broker_1r \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$RUNS_ROOT" \
  --run-id <schema_v8_run_id> \
  --dataset-id <schema_v8_dataset_id> \
  --schema-version 8 \
  --feature-set-id schema_v8_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite
```

Use `--target-family engine_simulated_1r` for a separate simulation dataset.
Never combine it with `broker_1r`. Current tooling rejects schemas v4-v7 and
does not migrate historical rows.

## Human Audit And Pattern Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id <schema_v8_dataset_id> \
  --audit-id <schema_v8_audit_id> \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/pattern_audit.py \
  --dataset-id <schema_v8_dataset_id> \
  --audit-id <schema_v8_pattern_audit_id> \
  --overwrite
```

The extremum audit reports Fibonacci proximity, raw depth, range-point buckets,
attempt profitability, cycle sequences, and stability. The pattern audit uses
analysis time for matching while retaining broker time for parity evidence.
Selected playback files are Strategy Tester-only and may deny only after
broker eligibility passes.

## Research Training

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <schema_v8_dataset_id> \
  --model-id <schema_v8_model_id> \
  --feature-set-id schema_v8_extremum_engine_xgb \
  --overwrite
```

All rows from `symbol + engine_timeframe + extremum_cycle_id` remain in one
chronological split group. Only attempt-time facts may be features; future
revision/finalization facts are labels or audit data. Training fails closed
when sample or class support is insufficient.

Schema v8 exports remain `RESEARCH_ONLY_NOT_APPROVED`. No model is approved for
MT5 runtime.

## Human Strategy Tester Matrix

Use the same symbol, model, deposit, broker, and inputs for comparison. Record
the exact observed broker time rather than assuming a schedule.

1. `FIXED_TIME_SESSIONS`: confirm broker and analysis timestamps are identical.
2. `EXNESS_SESSION`, US30 winter: test 2026-01-12 through 2026-01-13; verify an
   observed `14:30` broker open maps to `13:30`, offset `-60`.
3. `EXNESS_SESSION`, US30 summer: test 2026-07-13 through 2026-07-14; verify an
   observed `13:30` broker open stays `13:30`, offset `0`.
4. US DST boundaries: inspect 2026-03-06/2026-03-09 and
   2026-10-30/2026-11-02 without fabricating missing bars.
5. UK metal exceptions: inspect 2026-03-27/2026-03-30 and
   2026-10-23/2026-10-26 for an `XAU`, `XAG`, `XPT`, or `XPD` symbol.
6. Observe one PEAK, one BOTTOM, a deeper revision, multiple attempt depths,
   source expiration, and run-end censoring.
7. Confirm closed actual session, unsupported account mode, invalid stops or
   freeze distance, invalid volume, insufficient margin, and `OrderCheck`
   failures are exported and never sent.
8. Confirm one admissible order carries broker-side SL/TP, reconciles by owned
   ticket, and produces one broker-confirmed close outcome.
9. Confirm nonvisual testing creates no chart objects; visual mode shows only
   bounded entry/SL/TP lines.
10. Compare export disabled versus schema v8 export enabled with file logs off;
    record elapsed time, counts, folder bytes, and final status.

MetaEditor compilation and Python fixtures do not replace this human gate.
