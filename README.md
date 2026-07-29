# HFT Grid AI

MetaTrader 5 Expert Advisor for deterministic pivot-fractal market-data
collection and a small broker execution path. The entrypoint is
`HFT_Grid_AI.mq5`.

## Active Flow

```text
previous completed M1 Bid close
-> cached classic pivots from completed M15/M30/H1/H4/D1 candles
-> first live Bid touch for each timeframe/window/level identity
-> six-timeframe Stoch Structure and raw %B snapshot
-> immutable structural entry/SL/TP/trailing route
-> fresh broker eligibility and OrderCheck
-> one hedging-account market position
-> ticket-owned trailing, reconciliation, and broker-confirmed outcome
-> optional strict schema V9 export
```

Each pivot timeframe refreshes only when its broker-native active bar changes
or a controlled data-read retry is due. The source is always shift `1`; the EA
does not build synthetic candles. `M1` provides side context and research
features but no pivot levels.

Previous M1 Bid close above a level followed by live Bid at/below it creates a
buy touch. Previous close below followed by live Bid at/above it creates a sell
touch. Equality is neutral. Buy orders execute at Ask, sell orders at Bid, and
the touched pivot remains separate from the broker fill.

## Inputs

The public surface is intentionally fixed:

- `Broker_Session`
- `Lot_Type`, `Lot_Strategy_Size`
- `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`
- `Enable_Logs`, `Enable_File_Logs`

Pivot timeframes and formulas are internal. Removed license, account,
protection, user-session, spread-threshold, direction/concurrency, multi-leg,
runtime ML/pattern, and legacy settings are not supported as aliases.

## Identity And Routes

One immutable identity is `(symbol, pivot timeframe, active bar open, level)`.
Its first touch is consumed even when execution is denied or fails. Equal
prices from different timeframes remain independent identities; same-tick gaps
are processed nearest crossed price first with stable timeframe/level ties.

Allowed routes use a broker-side structural stop, terminal pivot target, and
captured-level trailing. Stops moved to the entry pivot are structural, not
guaranteed monetary break-even. Buy `R3` and sell `S3` have no forward level
and are recorded as `NO_FORWARD_LEVEL` without a send.

## Broker Safety

The fresh pre-send result is authoritative. Execution requires:

- hedging account mode, actual open broker session, and allowed symbol mode;
- account, terminal, expert, and MQL trading permissions;
- valid Bid/Ask, point size, structural geometry, stops, and freeze distance;
- valid normalized volume, free margin, and `OrderCheck`;
- accepted send result and symbol/magic/ticket reconciliation.

Spread is recorded but has no user threshold. Pivot prices are not adjusted to
force broker acceptance. After a fill, broker facts own ticket, volume, entry,
SL/TP, close state, and realized profit.

## Broker And Analysis Time

`FIXED_TIME_SESSIONS` leaves timestamps unchanged. `EXNESS_SESSION` preserves
broker time and shifts winter analysis timestamps by `-60` minutes on the
applicable US or UK DST calendar. Broker time always owns bars, touches,
sessions, orders, trailing, and reconciliation; analysis time is export-only.

## Schema V9 Research

When export is enabled, MT5 writes nine strict TSV files under:

```text
Common\Files\PivotFractalV9\runs\<run_id>\
```

The export covers pivot windows and levels, first-touch attempts, six context
rows per complete attempt, broker checks, trailing events, broker-confirmed
outcomes, manifest, and summary. Research features contain only trigger-time
facts: Stoch Structure slots `0..2` and raw `%B` shifts `0..5` for `M1`,
`M15`, `M30`, `H1`, `H4`, and `D1`.

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV9/runs> \
  --run-id <v9_run_id> \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV9/runs> \
  --run-id <v9_run_id> \
  --dataset-id <v9_dataset_id> \
  --target-family broker_outcome \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <v9_dataset_id> \
  --audit-id <v9_audit_id> \
  --overwrite
```

DuckDB/Parquet and XGBoost tooling is offline research only. No current code
loads a model into MT5 or lets research artifacts alter broker execution.

## Validation Policy

- No custom MQL5 harnesses, test modules, test EAs/scripts, or MQL5 CI.
- Multi-sprint MQL5 changes use static review per sprint and one final real
  MetaEditor compile with `0 errors, 0 warnings`.
- Human Strategy Tester/chart validation is required at final integration.
- Existing Python tests validate the V9 research contract, not MQL5 runtime.

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
