# Candle Pattern Discovery

Independent `CANDLE_PATTERN_ATR_V1` producer, current schema `2`, feature set
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

Defaults: Macro H1, Micro M3, `Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`,
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

The reader explicitly accepts original fixed-only schema 1 and schema 2. It
rejects unknown versions, missing/extra mode keys, invalid reference configuration,
ratio-dependent sizing and submitted stop risk above the reference budget. Old
runs are never relabeled or rewritten. Django consumer `95e5821` is still pinned
to schema 1 and must adopt the updated contract before importing schema 2.

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
