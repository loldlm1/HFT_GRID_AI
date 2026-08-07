# HFT Grid AI

MetaTrader 5 Expert Advisor for deterministic Macro/Micro pivot-band market
data collection and one small broker execution path. The entrypoint is
`HFT_Grid_AI.mq5`.

## Active Flow

```text
real broker tick
-> reconcile the single real broker lane and active virtual trials
-> one classic pivot ladder from the previous completed Macro candle
-> live-Bid virtual support/resistance trigger
-> shared Micro/Macro weighted-Bands snapshot
-> immutable structural SL plus fresh quote 1R TP
-> fresh broker eligibility and OrderCheck
-> one FOK hedging-account market position
-> ticket-first reconciliation without trailing
-> independent 4 x 4 virtual SL/TP matrix with bounded volatility re-entries
-> optional strict schema V11 export and broker-parity calibration
```

The defaults are Macro `H1` and Micro `M3`. The Macro source is always shift
`1`; the EA follows broker-native bars and never synthesizes missing candles.
Micro shift `0` describes volatility at the observed trigger tick.

## Inputs

The public surface is intentionally fixed:

- `Broker_Session`, `Macro_Timeframe`, `Micro_Timeframe`
- `Lot_Type`, `Lot_Strategy_Size`
- `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`
- `Enable_Logs`, `Enable_File_Logs`

Macro and Micro must be explicit supported timeframes, must differ, and Micro
must be shorter than Macro. Removed licensing, account, protection,
user-session, spread-threshold, direction/concurrency, multi-leg, runtime
ML/pattern, and legacy settings are not supported as aliases.

## Triggers And Routes

Identity is `(symbol, Macro timeframe, active Macro bar open, level)`. Its first
trigger is consumed even when routing, broker checks, `OrderCheck`, or
`OrderSend` fails.

- `S1..S3` are buy-only virtual limits: trigger on live `Bid <= support`.
- `R1..R3` are sell-only virtual limits: trigger on live `Bid >= resistance`.
- PP first observed above arms a future support buy; first observed below arms
  a future resistance sell. Equality waits for a strict departure.
- Buy requests use fresh Ask; sell requests use fresh Bid.

| Trigger | Direction | Structural SL |
| --- | --- | --- |
| `PP` armed as support | Buy | `S1` |
| `S1` | Buy | `S2` |
| `S2` | Buy | `S3` |
| `S3` | Buy | `S3 - (S2 - S3)` |
| `PP` armed as resistance | Sell | `R1` |
| `R1` | Sell | `R2` |
| `R2` | Sell | `R3` |
| `R3` | Sell | `R3 + (R3 - R2)` |

The authoritative TP is rebuilt from the fresh pre-send quote at exactly one
normalized price-distance R. Broker SL and TP are never modified after fill;
there is no trailing or break-even path.

## Virtual Research Matrix

When export is enabled, every consumed pivot origin also declares sixteen
virtual trials without creating additional broker orders:

| SL policy | Risk distance | TP chains | Re-entry |
| --- | --- | --- | --- |
| `STRUCTURAL` | Existing structural stop | `1R`, `2R`, `3R`, `5R` | None |
| `MICRO_BW_13` | Trigger Micro width x `0.13` | `1R`, `2R`, `3R`, `5R` | Up to 3 |
| `MICRO_BW_21` | Trigger Micro width x `0.21` | `1R`, `2R`, `3R`, `5R` | Up to 3 |
| `MICRO_BW_34` | Trigger Micro width x `0.34` | `1R`, `2R`, `3R`, `5R` | Up to 3 |

The full shift-0 Micro Bands width is frozen at the origin. Stops normalize
outward to the symbol trade-tick grid, TP uses the normalized risk ticks, and
each cell must satisfy:

```text
risk points >= spread + max(stops level, freeze level) + one trade tick
```

Virtual buys enter at Ask and resolve on Bid; sells enter at Bid and resolve on
Ask. Each TP multiple owns an independent retry chain. Only that chain's
`SL_FIRST` may create its next generation, and a reached TP never reopens.
Inner-level retries stop before the next outward pivot; `S3` and `R3` use only
the fixed three-retry cap. Invalid, boundary-blocked, expired, capacity-failed,
and censored states remain explicit research facts.

## Bands And Sizing

Research uses two cached built-in Bands handles with period `21`, deviation
`2.0`, SMA, and `PRICE_WEIGHTED`:

- Micro `%B 0..5`; shift `0` uses trigger Bid and current developing bands.
- Macro pivot `%B 0..5`; every numerator is the immutable touched pivot price.
- Micro raw/normalized bandwidth at shift `0`.
- Macro raw/normalized bandwidth from source shift `1`.

`EXECUTION_LOT_REFERENCE_BALANCE_PERCENT` uses a fixed internal reference of
`1,000,000` account-currency units, not live account balance. The default
`Lot_Strategy_Size=0.01` therefore requests a `100` unit risk budget. Volume is
normalized downward; a broker minimum that would exceed the budget blocks the
send. Fixed-lot mode remains separate.

Exact price-distance 1R does not guarantee symmetric or exact monetary
results. Quote expected loss/profit, budget utilization, entry/exit slippage,
commission, swap, fee, and realized gross/net R are stored separately.

## Broker Safety

Only fresh pre-send facts may authorize execution. The EA requires hedging
mode, an open broker session, an allowed symbol mode, trading permissions,
valid Bid/Ask and structural geometry, stops/freeze compliance, supported FOK
full fill, normalized volume, sufficient margin, successful `OrderCheck`, and
ticket/magic ownership reconciliation.

Spread and live account balance are telemetry. Pivot prices are never moved to
force acceptance. Non-hedging accounts continue collecting facts and fail
sends closed.

## Schema V11 Research

When export is enabled, MT5 writes exactly six strict TSV files under:

```text
Common\Files\PivotFractalV11\runs\<run_id>\
```

- `run_manifest.tsv`
- `pivot_windows.tsv`
- `signal_origins.tsv`
- `virtual_trials.tsv`
- `virtual_outcomes.tsv`
- `execution_checks.tsv`
- `broker_outcomes.tsv`
- `run_summary.tsv`

Validate and build with:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV11/runs> \
  --run-id <run_id> \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV11/runs> \
  --run-id <run_id> \
  --dataset-id <dataset_id>
```

The builder emits typed copies of all eight source tables plus
`origin_matrix_long.parquet`, `initial_matrix_wide.parquet`,
`eligible_virtual_trials.parquet`, `policy_chains.parquet`, and
`broker_virtual_calibration.parquet`.

The primary model target is the feature-complete eligible virtual first-touch
result: `1=TP_FIRST`, `0=SL_FIRST`. Sample weight is normalized per origin so
retry-heavy chains do not manufacture support. Broker TP/SL outcomes remain a
separate execution cohort. An accepted real request also creates one
calibration-only parity shadow from its exact submitted geometry and volume;
virtual gross remains counterfactual and has no commission, swap, fee, or net
claim.

DuckDB/Parquet audits and XGBoost are offline research only. Current code does
not load a model into MT5 or let research artifacts alter broker execution.

## Time And Validation

`FIXED_TIME_SESSIONS` leaves analysis time equal to broker time.
`EXNESS_SESSION` preserves broker time and shifts winter analysis timestamps by
`-60` minutes under the documented US/UK DST rules. Broker time always owns
bars, triggers, sessions, orders, and reconciliation; analysis time is
export-only.

- No custom MQL5 harnesses, test modules, test EAs/scripts, or MQL5 CI.
- Multi-sprint MQL5 work uses static review per sprint and one final real
  MetaEditor compile with `0 errors, 0 warnings`.
- Human real-tick Strategy Tester/chart validation is mandatory at final
  integration.
- Existing Python tests validate the V11 research contract, not MT5 runtime.

Final compile command:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" \
  --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" \
  --log "logs/compile/agentic-build.log" \
  --mode compile
```

## Documentation

- `AGENTS.md`: implementation, safety, and validation rules.
- `docs/architecture/market-data-broker-executor.md`: active ownership model.
- `docs/workflows/pivot-fractal-statistics-flow.md`: export and acceptance flow.
- `docs/workflows/pivot-fractal-offline-research-boundaries.md`: offline ML limits.
- `docs/environment/mt5-agentic-workflows.md`: paths, compile, and artifacts.
- `docs/plans/archive/` and `docs/research/archive/`: immutable history.

Live rollout is not authorized. Older-engine positions must be flat before any
future handoff, and only one EA instance may run per account and symbol.
