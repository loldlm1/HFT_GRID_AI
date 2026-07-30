# Pivot Fractal Statistics Flow

This is the active operator workflow for the always-on `PIVOT_FRACTAL_V1`
collector, strict schema V9 export, broker execution checks, trailing, and
offline research tooling.

## Runtime Identity

- Fixed pivot timeframes are `M15`, `M30`, `H1`, `H4`, and `D1`.
- Each window uses only its immediately previous completed broker candle at
  shift `1`; `M1` creates no pivot levels.
- One first-touch identity is `(symbol, pivot timeframe, active bar open,
  level)`. Direction is the result of the first touch.
- Previous completed M1 Bid close establishes side; live Bid detects both
  downward buy touches and upward sell touches. Equality is neutral.
- Buy execution uses Ask and sell execution uses Bid. Intended level, trigger
  prices, request, and broker fill remain separately observable.
- First touch consumes identity even when route admission, broker checks,
  `OrderCheck`, or `OrderSend` fails.

```text
pivot window -> seven ordered levels -> first-touch attempt
                                      |-> six context feature rows
                                      |-> observation/pre-send/send facts
                                      |-> optional ticket-owned trailing events
                                      `-> optional broker-confirmed outcome
```

## Time Contract

Every time-bearing V9 event retains broker time, analysis time, and offset.

- `FIXED_TIME_SESSIONS`: analysis time equals broker time.
- `EXNESS_SESSION`: winter analysis time is broker time minus 60 minutes under
  the symbol's US or UK DST calendar.
- Broker time owns bars, identity, trigger order, sessions, durations, orders,
  trailing, and reconciliation.
- Analysis time is export-only for research calendar features and grouping.
- Duplicate analysis timestamps are ordered by broker time and stable identity.

## Export Files

Set `Enable_Signal_Feature_Export=true` and provide a unique
`Signal_Feature_Run_Id`. MT5 writes to:

```text
Common\Files\PivotFractalV9\runs\<run_id>\
```

Schema V9 contains exactly:

- `run_manifest.tsv`: run/config, engine, pivot, trigger, feature, and approval
  policies.
- `pivot_windows.tsv`: source candle, active lifecycle, validity, and terminal
  status.
- `pivot_levels.tsv`: seven raw and tick-normalized prices per valid window.
- `signal_attempts.tsv`: immutable first-touch, route, and admission facts.
- `signal_features.tsv`: six trigger-time context rows per complete attempt.
- `execution_checks.tsv`: observation, pre-send, send, lifecycle, and broker
  reconciliation facts.
- `trailing_events.tsv`: requested, rejected, retry-pending, and confirmed
  ticket-owned SL progression.
- `signal_outcomes.tsv`: broker-confirmed entry and close facts only.
- `run_summary.tsv`: row counts, integrity counters, `export_status`, and
  completion state.

Feature rows preserve Stoch Structure classifications for slots `0..2` and raw
Bollinger `%B` shifts `0..5` for `M1`, `M15`, `M30`, `H1`, `H4`, and `D1`.
Shift `0` uses trigger Bid against the developing bands; shifts `1..5` use the
matching completed close and bands. Missing features invalidate the export but
never change execution.

Keep `Enable_Logs=false` and `Enable_File_Logs=false` for normal evidence runs.
A manually stopped run can diagnose behavior but is not accepted evidence;
require natural completion, `run_summary.tsv`, `completion_status=NATURAL`,
`export_status=OK`, and strict validation.

## Validate And Build

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV9/runs"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id <v9_run_id> \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id <v9_run_id> \
  --dataset-id <v9_dataset_id> \
  --target-family broker_outcome \
  --overwrite
```

Repeat `--run-id` to assemble several validated runs. Broker-outcome datasets
exclude denied and unfilled attempts. Use `--target-family admission` for a
separate attempt-admission study.

Current tooling accepts only strict schema `9`, engine `PIVOT_FRACTAL_V1`, and
feature set `schema_v9_pivot_fractal_xgb`. Older runs require their historical
code revision and must not be migrated, adapted, or relabeled.

## Offline Retest And Confluence Facts

Each validated build derives six immutable retest contexts for every
first-touch attempt. M1 uses the captured previous completed Bid close. M15,
M30, H1, H4, and D1 use the latest causal valid pivot window's source close at
the anchor trigger. `BUY_RETEST` means the close is above the tested pivot
price, `SELL_RETEST` means below, and equality within `1e-8` is neutral.

Macro side context and actual confluence are different facts:

- A macro context is a previous-close side snapshot against the anchor price.
- A confluence member is an actual V9 first-touch attempt with its own
  timeframe, level, direction, trigger, and terminal boundary.

Members are available from their trigger through their half-open pivot-window
interval. Mixed directions and nonadjacent timeframe combinations are valid.
Support and resistance labels do not impose trade direction, combinations are
unordered, and no `retest_sequence` is recorded.

Build the optional compact confluence feature lane with:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id <v9_run_id> \
  --dataset-id <confluence_dataset_id> \
  --target-family broker_outcome \
  --research-feature-set-id pivot_first_touch_confluence_v1 \
  --overwrite
```

Without `--research-feature-set-id`, the exact base dataset behavior remains the
default. The opt-in lane adds only five macro retest categories and eleven
bounded trigger-time counts; M1 retest, IDs, pattern tokens, broker decisions,
outcomes, and future facts are not model features.

## Pivot Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <v9_dataset_id> \
  --audit-id <v9_audit_id> \
  --overwrite
```

The audit reports window validity, level/timeframe frequency, complete
direction and reversal coverage, same-tick confluence, causal retest context,
bounded active membership, unordered pair support, admission denials, milestone
progression, structural break-even separately from realized profit, broker
TP/SL/other outcomes, duration, spread, and adverse entry slippage. Pass
`--minimum-group-support <n>` to set the D1-group interpretation threshold.
Atomic member rows remain complete, and exact requested token sets are filtered
without generating a full pattern power set. The audit does not manufacture a
simulated price-path result.

## Offline Training

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <v9_dataset_id> \
  --model-id <v9_model_id> \
  --target-family broker_outcome \
  --overwrite
```

Only trigger-time facts may be model features. Window terminal facts, broker
decisions, sends, trailing, fills, closes, duration, and realized profit are
labels or audit data. Chronological holdout and walk-forward folds keep every
`(run_id, symbol, window_id)` group in one partition for the default base lane.
Opt-in confluence datasets use `research_group_id` so the same symbol/D1 active
broker window stays together across runs. A base-versus-confluence ablation must
use identical target rows and the same D1 group assignments; comparing each
lane's native split directly is not a feature-only comparison.

Output is marked `OFFLINE_RESEARCH_ONLY`. There is no current MT5 loader,
runtime model export, research-based send filter, or pattern playback path.
Current natural-run evidence is recorded in
`docs/research/pivot-retest-confluence-offline-acceptance.md` and is
inconclusive for model promotion.

## Human Strategy Tester Matrix

Use the same symbol, model, broker, deposit, and inputs for comparable runs.
Record actual broker timestamps rather than assuming a schedule.

1. Confirm an `M30` transition such as `09:30` refreshes the new `M15` and
   `M30` windows while unchanged `H1/H4/D1` windows retain their ladders.
2. Confirm shift `1` is always the source; incomplete bars, weekend gaps, and
   session gaps never create synthetic candles.
3. Observe prior M1 close above plus downward Bid touch as buy, below plus
   upward Bid touch as sell, exact equality as neutral, and buy fill at Ask.
4. Exercise exact touch, gap-through, several same-tick crossed levels, equal
   prices across timeframes, identity deduplication, and window expiration.
5. Statically confirm all 14 route rows. Observe at least one `PP`, one inner
   natural, one extreme natural, and one reversal route in each direction;
   confirm buy `R3` and sell `S3` deny as `NO_FORWARD_LEVEL`.
6. Confirm milestone gaps select the strongest stop, no-change milestones do
   not modify, failed modifications keep prior protection and retry, and
   broker TP/SL closes reconcile by owned ticket.
7. Confirm closed actual session, unsupported account mode, disallowed symbol
   mode or permissions, invalid tick/geometry/stops/freeze/volume, insufficient
   margin, `OrderCheck`, and send failures are exported and never bypassed.
8. Confirm every complete attempt has six feature rows with structure slots
   `0..2`, raw `%B 0..5`, and shift `0` matching trigger Bid semantics.
9. `FIXED_TIME_SESSIONS`: verify broker and analysis timestamps are identical.
   For `EXNESS_SESSION`, verify winter/summer US30 and the documented US/UK DST
   boundary dates, including one metal-prefix exception.
10. Confirm nonvisual testing creates no chart objects; visual mode shows only
    bounded entry/current SL/terminal TP lines and compact identity labels.
11. Compare export disabled and enabled with file logs off over the same 1-3
    market days. Record elapsed time, rows, folder bytes, and final status.

MetaEditor compilation and Python fixtures do not replace this human gate.
