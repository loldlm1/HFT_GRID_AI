# Candle Pattern Discovery

Independent `CANDLE_PATTERN_ATR_V1` producer, current schema `3`, feature set
`candle_pattern_macro_micro_v1`. Pivot V14 intake and research remain separate.
The [accepted proposal](../../candle-pattern-discovery-proposal.md) owns rationale;
the [project index](../../docs/README.md) owns current acceptance status.

## Producer Contract

`Candle_Pattern_Discovery.mq5` discovers Harami/Engulfing using two completed
Micro candles. Each original creates separate ALIGNED/OPPOSED attempts. Broker
1R uses Micro ATR(13), multiplier 1, shift 1; optional shift 0 and Macro/Micro
Bands/Stochastic captures are research facts. Submitted SL/TP never move after
fill. `fill_deviation_points` is actual minus submitted entry, divided by point.
R2/R3 are virtual; accepted broker requests own separate R1 parity evidence.

Exactly one immediate same-direction re-entry follows a confirmed original
broker SL before expiry. Virtual losses cannot authorize a request. Every entry
owns its actual entry clock plus the full Macro duration. The first executable
quote at/after expiry requests closure; actual close time/price remain separate.
Expiry takes precedence over binary labels, while `broker_reason` retains the
actual platform reason. A missing quote cannot fabricate a fill. Run-end censors,
rejections, invalid geometry/distance/money and capacity states stay non-binary.

Defaults: `Broker_Session=FIXED_TIME_SESSIONS`, Macro H1, Micro M3,
`Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`,
`Lot_Strategy_Size=0.01`, export off. Reference sizing risks 0.01 percent of the
fixed 1,000,000 reference: a 100 account-currency quoted stop budget, independent
of live balance. `EXECUTION_LOT_FIXED_SIZE` interprets the same size input as lots.
Both modes reuse the unchanged Pivot `execution_lot_math.mqh`: reference volume
is budget divided by one-lot `OrderCalcProfit` loss at the ATR stop, capped at the
broker maximum, rounded down to its step, and rejected below its minimum. Each
original and re-entry recalculates against its own fresh entry/ATR stop. Broker
R1, parity R1 and virtual R2/R3 share the normalized volume; target ratio never
resizes the position. Actual fills, gaps and costs can differ from quoted risk.

Export requires a fresh
safe run ID. Magic `26092201` and the `CANDLE_PATTERN_ATR_V1` comment isolate
ownership. Restart refuses existing owned exposure; no adoption or live rollout
is supported by this handoff. FOK requests receive fresh session, permissions,
geometry, stops/freeze, volume, profit, margin and OrderCheck gates. Uncertain
ownership retains its broker record and blocks further entries. Reconciliation
never retries an uncertain entry or close. Definitively cancelled close orders
may retry the remaining owned position after the bounded throttle.

Macro pivots use the previous completed broker candle. Context resets each
Macro candle, records every level's latest touch/role/reclaim/gap evidence, and
chooses latest then outermost. Initial quotes beyond a level count under V14's
normalized touch rule; gap-cross evidence distinguishes them from exact touches.
PP requires strict departure and return. Entry interval uses the executable
Ask/Buy or Bid/Sell; tested context survives a reclaim above support/below
resistance. Signal `%B` uses the frozen decision Bid across shifts; pivot `%B`
uses the active tested level. Neither series is clipped. Indicators use V14's
Bands 21/0/2 weighted price and Stochastic 5/3/3 SMA close/close; SMA5 and slopes
retain shifts 0..5. Optional feature failures never deny broker execution.

Eight exact TSVs live at `Common\\Files\\CandlePatternV1\\runs\\<run_id>\\`:
manifest, Macro windows, signals, attempts/features, trials, execution checks,
outcomes, and summary. `schema_contract.py` owns ordered headers and types.
All causal clocks are integer broker milliseconds. Actual entry Macro opening
owns allowance membership even if a fill crosses a decision-window boundary.
An OK/NATURAL seal, exact counts and unchanged source files are mandatory.
Fatal research errors stop only their tester; a failure marker invalidates a
previous seal if final persistence fails. Retain failed runs; never correct in place.

Schema 2 adds exact manifest keys `lot_type` and `reference_balance`; `lot_size`
remains the configured input, interpreted by that mode. Ordered TSV columns,
engine identity, feature set and directory namespace remain unchanged.
`entry_attempts.requested_volume` is raw requested lots at the decision quote,
never a percentage; it is null when reference sizing cannot be calculated at
that moment. `execution_checks.volume` and `trials.volume` retain the fresh
submitted normalized lots; outcomes retain actual filled volume. The independent
broker calculation never consumes the research snapshot's sizing result.

The reader explicitly accepts original fixed-only schema 1, schema 2 and schema 3. It
rejects unknown versions, missing/extra mode keys, invalid reference configuration,
ratio-dependent sizing and submitted stop risk above the reference budget. Old
runs are never relabeled or rewritten. Django consumer `95e5821` is still pinned
to schema 1 and must adopt the updated contract before importing schemas 2/3.

## Normalized Research Clock

Candle `1.02` adds the export-only `Broker_Session` input. Select `EXNESS_SESSION`
for the prepared Exness UTC/Shift=0 sources. It applies US/New York DST to every
symbol, including metals and suffixed custom symbols. Summer analysis time equals
raw broker time; winter analysis time is broker time minus 60 minutes. Thus the
regular 09:30 New York stock-market open is always 13:30 in normalized session
time, and the conventional 08:00 New York FX-session start is 12:00. London and
other local sessions can shift relative to this New York anchor.

`FIXED_TIME_SESSIONS` remains the default and exports raw time with zero offset.
Exness mode assumes the documented unshifted UTC source; it does not detect or
convert another broker's server timezone. Neither mode changes quotes, bars,
features, raw event order, native Macro allowance membership, order geometry,
position sizing or entry-plus-Macro expiry. No terminal timezone change occurs.

Schema 3 preserves all schema-2 table columns in their original order, then adds
an analysis timestamp and applied offset for every raw timestamp. For example,
`decision_time_msc` gains `decision_analysis_time_msc` and
`decision_analysis_offset_minutes`; `deadline_msc` gains
`deadline_analysis_time_msc` and `deadline_analysis_offset_minutes`. This also
covers source/entry Macro bars, ATR sources, tested pivots, execution checks and
observed/terminal clocks. The summary adds `last_analysis_time_msc` and
`last_analysis_offset_minutes`. Absent clocks have null raw/analysis/offset values;
all present values retain exact integer milliseconds:

```text
analysis_time_msc = broker_time_msc + analysis_offset_minutes * 60000
```

The manifest freezes five new keys:

| Key | Fixed mode | Exness mode |
| --- | --- | --- |
| `broker_session` | `FIXED_TIME_SESSIONS` | `EXNESS_SESSION` |
| `broker_time_basis` | `BROKER_NATIVE` | `UTC_SHIFT_0` |
| `analysis_clock_policy` | `BROKER_FIXED_V1` | `EXNESS_NEW_YORK_V1` |
| `analysis_calendar` | `NONE` | `US_NEW_YORK` |
| `analysis_calendar_coverage` | `NOT_APPLICABLE` | `US_2007_RULES_2007_2099` |

The frozen US rules support broker years 2007-2099: DST starts at 07:00 UTC on
the second March Sunday and ends at 06:00 UTC on the first November Sunday.
Unsupported dates invalidate normalized exports explicitly. The reader checks
offsets independently against IANA `America/New_York`; normalized validation
requires that timezone database. Fixed mode and legacy schemas do not.
Pivot's existing per-symbol US/UK calendar and shared helper are unchanged.

The app must consume the exported clock once for research-hour/date filters,
discovery, autonomous selection, charts, daily grouping and Walk-Forward calendars.
Label it normalized session time. Seasonal jumps or repeated hours never replace
raw timestamps for causal sorting, elapsed durations or Macro allowance keys.
Schemas 1/2 retain unknown clock provenance; do not infer normalization from their
symbol names. Django clock intake and full research integration remain separate
work under its saved plan on `main` in the original application checkout.

## Offline Research

```bash
python3 -m tools.candle_pattern_ml.reader /path/to/CandlePatternV1/runs/RUN_ID
python3 -m tools.candle_pattern_ml.research /path/to/CandlePatternV1/runs/RUN_ID \
  --pattern HARAMI --category ALIGNED --entry-type ALL --allowance 2 \
  --mode STRATEGY --where micro_b_percent_state_0 eq ABOVE
python3 -m unittest discover -s tools/candle_pattern_ml/tests -t .
```

Each cohort chooses exactly one family and direction category. Apply causal
node conditions and entry type before first-N selection within each broker Macro
candle. `0` is unlimited. Only confirmed entered broker attempts consume slots;
ratio rows and rejections do not. Exits never refund slots. R2/R3 outcomes use
the selected attempt membership, with separate counts for ineligible/censored
trials. Parity stays outside the research matrix.

`ANALYSIS` permits recorded children independently; `STRATEGY` requires each
child's original to have been selected under the same policy. Re-entry-only
strategy mode therefore rejects. No conditions on future labels, profit, exit
time, completed duration or ratio are accepted. Shift 0 features are causal
decision snapshots, not completed-candle claims.

The validator and selector stream through a disposable disk-backed SQLite index;
this is not application storage. The consumer uses PostgreSQL. Money remains
Decimal in Python; broker net includes reported costs, virtual net/costs stay
unknown. These observed-fill cohorts do not reproduce counterfactual margin,
fill quality or portfolio-wide budgets. Temporal training must group roots,
directions, ratios and children, and purge overlapping outcome windows.

Generate wire headers only with:

```bash
python3 tools/candle_pattern_ml/schema_contract.py \
  --write-mql-header services/candle_pattern/schema.mqh
```

No new MQL5 test EAs, scripts, CI or external dependencies are required.

## Consumer Workflow

The independent Django implementation is in
`/home/admin/python_projects/hft-grid-ai-orchestrator-candle`, branch
`codex/candle-pattern-discovery`. Its
[contract](/home/admin/python_projects/hft-grid-ai-orchestrator-candle/docs/contracts/candle-pattern-discovery-v1.md)
owns additive migrations, typed PostgreSQL intake and research evidence.
Configure `HFT_CANDLE_INBOX_ROOT` only in the intended isolated environment,
then register the safe run ID at `/datasets/candle/` after a successful seal.
Each root chooses one pattern, direction relationship, entry type and first-N
allowance. A child adds one causal condition before that allowance is applied.
HTML and staff JSON share the saved result; resume controls retain checkpoints.

Rollback producer code with its matching binary independently of source runs.
Consumer baseline is `57fae95e`; additive migration reversal requires an empty
Candle evidence boundary. Once evidence exists, retain its schema/data and use
a forward correction. Never undo V14 data or mutate original Candle exports.
