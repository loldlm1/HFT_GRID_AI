# Pivot Fractal Statistics Flow

This is the active operator workflow for the always-on `PIVOT_FRACTAL_V2`
collector, strict schema V11 export, one immutable structural 1R broker lane,
virtual SL/TP policy trials, parity calibration, and offline research tooling.

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
Macro window -> seven ordered levels -> consumed origin
                                     |-> shared Micro/Macro band snapshot
                                     |-> sixteen virtual policy trials
                                     |   `-> independent volatility retry chains
                                     |-> unchanged structural 1R broker attempt
                                     |   `-> accepted-request parity shadow
                                     `-> separate virtual/broker outcomes
```

## Time Contract

Every time-bearing V11 fact retains broker time, analysis time, and offset.

- `FIXED_TIME_SESSIONS`: analysis time equals broker time.
- `EXNESS_SESSION`: winter analysis time is broker time minus 60 minutes under
  the symbol's US or UK DST calendar.
- Broker time owns bars, identity, trigger order, sessions, durations, orders,
  and reconciliation.
- Analysis time is export-only for research calendar features and grouping.
- Duplicate analysis timestamps are ordered by broker time and stable identity.

## Feature Snapshot

V11 uses fixed built-in Bands parameters: period `21`, shift `0`, deviation
`2.0`, SMA, and `PRICE_WEIGHTED`.

- Micro `%B 0..5`: shift `0` uses trigger Bid; shifts `1..5` use matching
  completed weighted prices.
- Macro pivot `%B 0..5`: every numerator is the immutable touched pivot price.
- Micro bandwidth: raw and normalized shift `0` at the observed trigger tick.
- Macro bandwidth: raw and normalized shift `1` cached with the Macro source.
- `%B = 100 * (price - lower) / (upper - lower)` and is not clipped.
- Missing or noncausal features mark the research snapshot incomplete but do not change
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

The virtual origin matrix is fixed and internal:

| SL policy | Stop construction | TP multiples | Retries |
| --- | --- | --- | --- |
| `STRUCTURAL` | Existing structural route | `1`, `2`, `3`, `5` | None |
| `MICRO_BW_13` | Origin Micro width x `0.13` | `1`, `2`, `3`, `5` | `1..3` after own SL |
| `MICRO_BW_21` | Origin Micro width x `0.21` | `1`, `2`, `3`, `5` | `1..3` after own SL |
| `MICRO_BW_34` | Origin Micro width x `0.34` | `1`, `2`, `3`, `5` | `1..3` after own SL |

The full shift-0 Micro Bands width is frozen at index `0` and reused by each
retry. Stops round outward to the trade-tick grid; TP is rebuilt from the
normalized risk ticks. A cell is active only when:

```text
risk points >= spread + max(stops level, freeze level) + trade tick points
```

Virtual buy entry is Ask and exit first touch is Bid. Virtual sell entry is Bid
and exit first touch is Ask. Each TP multiple owns its own chain, so TP1 can
finish while TP2/TP3/TP5 remain active. Only an `SL_FIRST` outcome may create
that same chain's next generation.

Inner retries must keep both the observed re-entry and proposed SL at least one
trade tick inside the next outward pivot. Gap-through, equality, window expiry,
retry cap, ineligible geometry, and run-end censoring are explicit states.
`S3`/`R3` have no outward boundary and use the same maximum index `3`.

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
Common\Files\PivotFractalV11\runs\<run_id>\
```

Schema V11 contains exactly:

- `run_manifest.tsv`: engine/config, timeframes, Bands, matrix, quote-side,
  distance, retry, capacity, lot, money, cohort, and approval policies.
- `pivot_windows.tsv`: Macro source candle, seven wide raw/trade levels, PP
  arming, cached shift-1 Macro bands, validity, and terminal state.
- `signal_origins.tsv`: consumed identity, trigger quote, frozen origin
  features/width, pivot ladder, structural route, broker-attempt link, and
  origin expiry.
- `virtual_trials.tsv`: matrix or parity identity, entry quote/features,
  normalized geometry, broker-distance facts, hypothetical volume/money,
  eligibility, and continuation references.
- `virtual_outcomes.tsv`: TP/SL/censor first touch, threshold and observed exit,
  gap, duration, nominal R, counterfactual quote gross, and chain terminal data.
- `execution_checks.tsv`: ordered observation, pre-send, send, ownership, and
  terminal broker facts.
- `broker_outcomes.tsv`: broker-confirmed entry/close, immutable SL/TP,
  slippage, costs, P&L, R values, close classification, and binary eligibility.
- `run_summary.tsv`: matrix/parity/broker counts, ineligibility, chain
  terminals, state peak/cap, integrity, export, and completion status.

Keep `Enable_Logs=false` and `Enable_File_Logs=false` for normal evidence runs.
A manually stopped or outstanding-position run is useful for diagnosis but is
`CENSORED`. Accepted evidence requires `completion_status=NATURAL`,
`export_status=OK`, and strict validation with no integrity errors.

## Validate And Build

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV11/runs"
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
configuration, timeframe, Bands, matrix constants, quote sides, distance
policy, retry/capacity policy, lot, reference balance, feature set, or currency.

The output contains typed copies of all eight tables plus:

- `origin_matrix_long.parquet`: every matrix row, including retries,
  ineligible cells, and censored outcomes;
- `initial_matrix_wide.parquet`: one human-readable row per origin with the
  initial sixteen cells; never used directly as model input;
- `eligible_virtual_trials.parquet`: feature-complete eligible matrix
  `TP_FIRST`/`SL_FIRST` rows with the virtual target and per-origin weight;
- `policy_chains.parquet`: one row per policy chain with attempts, losses,
  final status, nominal R, quote gross R, and censoring;
- `broker_virtual_calibration.parquet`: exact parity-shadow/broker pairs with
  agreement, timing, price, gross, execution-R, and actual cost deltas.

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

The audit separates matrix support, virtual policy performance, chain results,
broker execution, and parity calibration. It reports both unique-origin and
trial-row support; retry rows are never presented as independent market
origins. Unexplained eligible TP/SL parity disagreement fails the audit.

Training uses `eligible_virtual_trials.parquet`, fixed seeds, origin-normalized
sample weights, a purged chronological holdout, and expanding walk-forward
folds. Rows sharing one `(symbol, Macro timeframe, active Macro bar open)` stay
together across duplicate runs. A training trial must terminate strictly
before the next validation boundary.

The deterministic ablation order is policy/level/direction/time, normalized
widths, Micro `%B`, then Macro pivot `%B`. Output is
`OFFLINE_RESEARCH_ONLY`; no MT5 loader, runtime model export, research-based
send filter, or pattern playback exists.

## Outcome Interpretation

The primary virtual target is `1` for feature-complete eligible `TP_FIRST` and
`0` for feature-complete eligible `SL_FIRST`. Ineligible and censored rows have
no target. Nominal policy value must consider the TP multiple, for example
`p(TP) * tp_r_multiple - (1 - p(TP))`; win rate alone is insufficient.

The broker target remains separate: only a feature-complete, fully closed
position with one consistent owned `BROKER_TP` or `BROKER_SL` reason qualifies.
Manual, mixed, stop-out, expert, other, denied, failed-send, and censored facts
remain auditable and are not treated as losses.

Virtual quote gross is counterfactual `OrderCalcProfit` output. It contains no
commission, swap, fee, latency, slippage, or net-profit claim. Broker deal
history remains the sole authority for actual gross, costs, net, and realized
execution R. Parity shadows are calibration-only and excluded from model and
policy cohorts.

Do not select either target cohort using realized P&L or slippage. Those facts
occur after entry and are diagnostics. A broker result such as `+130` or `-150`
must be decomposed into quote expectation, budget utilization, entry and exit
slippage, commission, swap, and fees rather than labeled generically as
volatility slippage.

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
9. Verify one origin declares all sixteen index-0 cells, exact integer-R TP,
   explicit ineligible cells, and independent TP-chain consumption.
10. Observe volatility retries, one-generation-per-tick behavior, next-pivot
    boundary suppression, gap-through handling, origin expiry, index-3 cap,
    and run-end censoring; use named static evidence for unreachable cases.
11. Confirm accepted sends create one exact-geometry parity shadow, denied or
    failed sends create none, and strict TP/SL pairs have no unexplained
    terminal mismatch.
12. Validate the natural eight-file V11 run, long/wide/chain/calibration
    build, audit/train support guards, causal splits, and human filtering.
13. Verify `FIXED_TIME_SESSIONS` and `EXNESS_SESSION` DST cases, bounded real
    position visuals, and zero chart work in nonvisual mode.
14. Compare export disabled and enabled with file logs off over the same 1-3
    market days; record elapsed time, peak state, rows, folder bytes, and final
    status.

MetaEditor compilation, Python fixtures, and static review do not replace this
human gate.
