# Extremum Engine Statistics Flow

This is the active workflow for the always-on M1 `EXTREMUM_V1` engine and
schema v7 statistics.

## Engine Contract

- Stoch Structure slot `0` is the provisional source.
- `BOTTOM` creates only bullish attempts; `PEAK` creates only bearish attempts.
- The existing M1 `high_1`/`low_1` breakout remains the execution trigger.
- M1 and macro moving averages do not confirm or deny the signal.
- A cycle remains open while the provisional extremum type is unchanged.
- A deeper price/time for the same type creates a revision in the same cycle.
- Fibonacci anchors are frozen from completed slots `1` and `2` at cycle start.
- Depth is raw and may be below `0` or above `100`; MQL5 does not clamp it.
- Intrinsic attempts are recorded after valid geometry and before operational gates.

```text
cycle -> revision -> intrinsic attempt
                         |-> operational admission
                         |-> ENGINE_SIMULATION outcome
                         `-> optional broker-confirmed outcome
```

Operational blocks never create broker outcomes. Simulated profit never
satisfies broker outcome predicates or overwrites broker tickets, volume,
entry/close prices, or realized profit.

## Export

Enable `Enable_Signal_Feature_Export` and use a unique
`Signal_Feature_Run_Id`. MT5 writes under:

```text
Common\Files\DeterministicSignalML\runs\<run_id>\
```

Schema v7 files:

- `engine_cycles.tsv`: one finalized/censored row per cycle.
- `engine_revisions.tsv`: one point-in-time row per observed revision.
- `engine_attempts.tsv`: one terminal/censored row per intrinsic attempt.
- `signal_admissions.tsv`: operational and broker admission events.
- `signal_features.tsv`: broker-entered feature snapshot.
- `signal_outcomes.tsv`: broker-confirmed signal outcomes only.
- `signal_leg_outcomes.tsv`: broker-confirmed leg/ticket outcomes.
- `run_manifest.tsv` and `run_summary.tsv`: contract and counts.

## Validate And Build

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export RUNS_ROOT="$MT5_COMMON_FILES/DeterministicSignalML/runs"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$RUNS_ROOT" \
  --run-id <schema_v7_run_id> \
  --dataset-id <schema_v7_dataset_id> \
  --schema-version 7 \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --target-family broker_1r \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$RUNS_ROOT" \
  --run-id <schema_v7_run_id> \
  --dataset-id <schema_v7_dataset_id> \
  --schema-version 7 \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite
```

Use `--target-family engine_simulated_1r` to build a separate research matrix
from simulated paths. Never combine that matrix with `broker_1r`.

## Human Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id <schema_v7_dataset_id> \
  --audit-id <schema_v7_audit_id> \
  --overwrite
```

The audit derives nearest Fibonacci level, Fibonacci distance, point-range
buckets, attempt profitability, cycle sequences, and monthly stability. It
reports attempt count and distinct cycle count, marks sparse groups, and keeps
`ENGINE_SIMULATION` and `BROKER_CONFIRMED` in separate lanes. Price range in
points is structural size, not traded volume.

## Research Training

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <schema_v7_dataset_id> \
  --model-id <schema_v7_model_id> \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --overwrite
```

All rows from `symbol + engine_timeframe + extremum_cycle_id` stay in one
chronological partition. Point-in-time features include current depth, attempt
and revision indexes, frozen range, revision distances, structure, session,
and cyclical time. Final depth, finalization time, cycle result, and later
revision facts are labels/audit facts and are excluded from training.

Schema v7 model artifacts are research-only until a later plan explicitly sets
`runtime_approval=APPROVED_FOR_MT5_RUNTIME`. Old v4/v5/v6 artifacts and
unapproved v7 artifacts fail closed in SHADOW/FILTER. FILTER remains Strategy
Tester-only and may only deny an otherwise admissible entry.

## Human Strategy Tester Matrix

Before accepting the active plan, a human must verify:

- one PEAK and one BOTTOM cycle;
- a deeper same-cycle revision;
- attempt 1 and attempt 2 at different raw depths;
- no-trigger/revision expiration;
- session or spread block retained in the census;
- one broker entry and broker-confirmed close;
- an open cycle censored at run end;
- old and unapproved ML artifacts fail closed;
- export-disabled versus schema-v7 elapsed time and output growth are acceptable.

MetaEditor compile and Python fixtures do not replace this visual/runtime gate.
