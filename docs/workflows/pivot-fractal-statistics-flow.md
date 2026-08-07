# Pivot Fractal Statistics Flow

This is the active operator workflow for the always-on `PIVOT_FRACTAL_V2`
collector, strict schema V10 export, broker execution checks, immutable 1R
positions, and offline research tooling.

## Runtime Identity

- Defaults are Macro `H1` and Micro `M3`; both are configurable within the
  validated explicit-timeframe boundary.
- The immediately previous completed Macro broker candle at shift `1` creates
  the seven-level classic pivot ladder for the active Macro bar.
- One identity is `(symbol, Macro timeframe, active bar open, level)`.
- `S1..S3` trigger buy attempts when live Bid is at or below the support.
  `R1..R3` trigger sells when live Bid is at or above the resistance.
- PP is armed once from the first strict Bid side for that Macro window and
  triggers only on the return side. Initial equality waits for departure.
- Buy execution uses fresh Ask; sell execution uses fresh Bid. Pivot, trigger,
  request, fill, terminal, and close prices remain separately observable.
- First trigger consumes identity even when route construction, broker checks,
  `OrderCheck`, or `OrderSend` fails.

```text
Macro window -> seven ordered levels -> consumed attempt
                                      |-> shared Micro/Macro band snapshot
                                      |-> candidate-specific Macro pivot %B
                                      |-> observation/pre-send/send facts
                                      `-> optional broker-confirmed outcome
```

## Time Contract

Every time-bearing V10 fact retains broker time, analysis time, and offset.

- `FIXED_TIME_SESSIONS`: analysis time equals broker time.
- `EXNESS_SESSION`: winter analysis time is broker time minus 60 minutes under
  the symbol's US or UK DST calendar.
- Broker time owns bars, identity, trigger order, sessions, durations, orders,
  and reconciliation.
- Analysis time is export-only for research calendar features and grouping.
- Duplicate analysis timestamps are ordered by broker time and stable identity.

## Feature Snapshot

V10 uses fixed built-in Bands parameters: period `21`, shift `0`, deviation
`2.0`, SMA, and `PRICE_WEIGHTED`.

- Micro `%B 0..5`: shift `0` uses trigger Bid; shifts `1..5` use matching
  completed weighted prices.
- Macro pivot `%B 0..5`: every numerator is the immutable touched pivot price.
- Micro bandwidth: raw and normalized shift `0` at the observed trigger tick.
- Macro bandwidth: raw and normalized shift `1` cached with the Macro source.
- `%B = 100 * (price - lower) / (upper - lower)` and is not clipped.
- Missing or noncausal features mark the attempt incomplete but do not change
  execution authorization.

## Route And Risk Facts

The structural SL matrix is:

| Trigger | Direction | Structural SL |
| --- | --- | --- |
| `PP`, `S1`, `S2`, `S3` | Buy | `S1`, `S2`, `S3`, `S3 - (S2 - S3)` |
| `PP`, `R1`, `R2`, `R3` | Sell | `R1`, `R2`, `R3`, `R3 + (R3 - R2)` |

The authoritative pre-send TP is exactly one normalized price-distance R from
fresh Ask for a buy or fresh Bid for a sell. Broker SL/TP are immutable after
fill. No trailing or SL/TP modification events exist.

Reference-percentage mode uses a fixed `1,000,000` account-currency reference.
The default `0.01` percent requests a `100` unit risk budget before downward
volume normalization. Quote expected SL/TP money and budget utilization are
stored because broker volume steps and instrument profit conversion can make
money R differ from price-distance R.

## Export Files

Set `Enable_Signal_Feature_Export=true` and provide a unique
`Signal_Feature_Run_Id`. Initialization fails closed if the run folder cannot
be created safely. MT5 writes to:

```text
Common\Files\PivotFractalV10\runs\<run_id>\
```

Schema V10 contains exactly:

- `run_manifest.tsv`: engine/config, timeframes, Bands, trigger, route, lot,
  time, feature, cohort, and approval policies.
- `pivot_windows.tsv`: Macro source candle, seven wide raw/trade levels, PP
  arming, cached shift-1 Macro bands, validity, and terminal state.
- `signal_attempts.tsv`: consumed trigger, route/request geometry, Micro and
  Macro pivot band facts, completeness, denial, and send status.
- `execution_checks.tsv`: ordered observation, pre-send, send, ownership, and
  terminal broker facts.
- `signal_outcomes.tsv`: broker-confirmed entry/close, immutable SL/TP,
  slippage, costs, P&L, R values, close classification, and binary eligibility.
- `run_summary.tsv`: row/cohort/exclusion/censoring counts, integrity status,
  export status, and completion status.

Keep `Enable_Logs=false` and `Enable_File_Logs=false` for normal evidence runs.
A manually stopped or outstanding-position run is useful for diagnosis but is
`CENSORED`. Accepted evidence requires `completion_status=NATURAL`,
`export_status=OK`, and strict validation with no integrity errors.

## Validate And Build

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV10/runs"
export PIVOT_RUN_ID="<run_id>"
export PIVOT_DATASET_ID="<dataset_id>"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --dataset-id "$PIVOT_DATASET_ID"
```

Repeat `--run-id` to assemble compatible runs. The builder rejects mixed
configuration, timeframe, Bands, lot, reference-balance, feature-set, or
currency contracts.

The output contains typed copies of all six tables plus:

- `research_matrix.parquet`: one row per feature-complete consumed attempt,
  including operationally denied and nonbinary facts;
- `binary_outcomes.parquet`: only feature-complete, fully closed, consistent
  broker TP/SL rows, with `1=TP` and `0=SL`.

## Audit And Train

```bash
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --audit-id <audit_id> \
  --minimum-group-support 30

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --model-id <model_id>
```

The audit separates integrity/operations from strict binary performance and
can group by trigger time, level, direction, normalized Micro volatility,
Micro `%B`, and Macro pivot `%B`. Human bins are report-only.

Training uses normalized continuous trigger-time features, fixed seeds, a
purged chronological holdout, and expanding walk-forward folds. Rows sharing
the same `(symbol, Macro timeframe, active Macro bar open)` stay together
across duplicate runs. A training outcome must close strictly before the next
validation boundary.

The deterministic ablation order is base level/direction/time, normalized
widths, Micro `%B`, then Macro pivot `%B`. Output is
`OFFLINE_RESEARCH_ONLY`; no MT5 loader, runtime model export, research-based
send filter, or pattern playback exists.

## Outcome Interpretation

Only a feature-complete, fully closed position with one consistent owned
`BROKER_TP` or `BROKER_SL` reason receives a binary target. Manual, mixed,
stop-out, expert, other, denied, failed-send, and censored facts remain in raw
and audit tables but are not treated as losses.

Do not filter the primary binary cohort using realized P&L or slippage. Those
facts occur after the trigger and are diagnostics. A result such as `+130` or
`-150` must be decomposed into quote expectation, budget utilization, entry
and exit slippage, commission, swap, and fees rather than labeled generically
as volatility slippage.

## Human Strategy Tester Matrix

Use `Every tick based on real ticks` and keep symbol, broker, tester period,
deposit, and inputs fixed for comparable runs. Record actual broker timestamps.

1. Confirm defaults `H1/M3`, invalid timeframe rejection, causal H1 window
   changes, shift-1 sources, retry behavior, and no synthetic candles.
2. Exercise `Bid <= S1/S2/S3` buys, `Bid >= R1/R2/R3` sells, exact touches,
   already-marketable starts, and gap-through batches.
3. Exercise PP initial above, below, and equal states; confirm one fixed role,
   return trigger behavior, stable path order, and one consumed identity.
4. Confirm buy request/fill semantics use Ask and sell semantics use Bid while
   trigger and pivot prices remain distinct.
5. Reproduce selected weighted Bands, Micro `%B 0..5`, Macro pivot `%B 0..5`,
   and raw/normalized bandwidth formulas without clipping.
6. Observe at least PP, one inner support, one inner resistance, and one extreme
   route; statically review any route not reached by market data.
7. Confirm exact normalized price-distance 1R, fixed `100` default budget,
   downward volume normalization, FOK policy, margin, stops/freeze,
   `OrderCheck`, and fail-closed denial paths.
8. Confirm broker SL/TP never changes after fill and TP/SL/manual/mixed/other
   outcomes reconcile by owned ticket with correct costs and slippage signs.
9. Validate the natural six-file V10 run, build/audit/train flow, binary and
   excluded counts, causal splits, and human filtering dimensions.
10. Verify `FIXED_TIME_SESSIONS` and `EXNESS_SESSION` DST cases, bounded visual
    entry/SL/TP lines, and zero chart work in nonvisual mode.
11. Compare export disabled and enabled with file logs off over the same 1-3
    market days; record elapsed time, rows, folder bytes, and final status.

MetaEditor compilation, Python fixtures, and static review do not replace this
human gate.
