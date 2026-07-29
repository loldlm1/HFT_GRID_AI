# HFT Grid AI

MetaTrader 5 Expert Advisor focused on deterministic M1 market-data collection
and one broker execution path. The entrypoint is `HFT_Grid_AI.mq5`.

## Active Flow

```text
M1 Stoch Structure slot 0
-> extremum cycle/revision/attempt
-> observation broker checks
-> schema v8 market-data facts
-> M1 high/low breakout
-> fresh pre-send broker checks
-> optional tester-only research filter
-> one hedging-account position with broker SL and fixed 1R TP
-> ticket-first reconciliation and broker-confirmed outcome
```

`BOTTOM` creates bullish attempts and `PEAK` creates bearish attempts. A deeper
same-type provisional extremum creates a revision in the current cycle; a type
change finalizes the cycle. Completed slots `1` and `2` freeze the cycle range.

## Inputs

The public surface is intentionally small:

- `Broker_Session`
- `Lot_Type`, `Lot_Strategy_Size`
- `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`
- `ML_Inference_Mode`, `ML_Model_Export_Id`
- `Enable_Pattern_Audit_Overlay`, `Pattern_Audit_Set_Id`
- `Enable_Logs`, `Enable_File_Logs`

Removed license, account, protection, user-session, spread-threshold,
direction/concurrency, multi-leg, and legacy risk settings are not supported as
aliases.

## Broker Safety

Every observed attempt records current broker eligibility. The EA refreshes
the same facts immediately before sending and requires:

- hedging account mode and an open actual broker session;
- allowed symbol trade mode and account/terminal/MQL trade permissions;
- valid bid/ask, stops/freeze geometry, broker-side SL/TP, and fixed 1R target;
- valid volume min/max/step, margin, and `OrderCheck`;
- accepted send retcode plus symbol/magic/ticket reconciliation.

Spread is recorded as a fact but is not compared with a user threshold.
Non-hedging accounts remain collection-only.

## Broker Time And Analysis Time

`FIXED_TIME_SESSIONS` leaves timestamps unchanged. `EXNESS_SESSION` keeps raw
broker time and additionally normalizes winter analysis time by `-60` minutes
on the applicable US or UK DST calendar. For example, US30 broker time `14:30`
in winter is stored with analysis time `13:30`; summer `13:30` remains
`13:30`.

Normalization affects exports, calendar features, research grouping, and
pattern matching only. Bar scheduling, actual-session checks, durations, and
orders always use broker time.

## Schema V8 Research

When export is enabled, MT5 writes eight schema v8 TSV files under:

```text
Common\Files\DeterministicSignalML\runs\<run_id>\
```

The contract includes cycle, revision, attempt, broker-check, feature, outcome,
manifest, and summary facts. Broker and simulated targets stay separate.

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <runs_root> \
  --run-id <schema_v8_run_id> \
  --dataset-id <schema_v8_dataset_id> \
  --schema-version 8 \
  --feature-set-id schema_v8_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id <schema_v8_dataset_id> \
  --audit-id <schema_v8_audit_id> \
  --overwrite
```

No schema v8 model is approved for MT5 runtime. Shadow mode is passive;
filter mode and pattern playback are Strategy Tester-only denials after broker
eligibility passes.

## Validation Policy

- No custom MQL5 harnesses, test modules, test EAs/scripts, or MQL5 CI.
- Multi-sprint MQL5 changes use static review per sprint and one final real
  MetaEditor compile with `0 errors, 0 warnings`.
- Human Strategy Tester/chart validation is required at final integration.
- Existing Python schema tests validate research tooling, not MQL5 runtime.

Agentic compile at the final gate:

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
- `docs/workflows/extremum-engine-statistics-flow.md`: export and research flow.
- `docs/workflows/deterministic-signal-ml-inference-flows.md`: runtime ML limits.
- `docs/environment/mt5-agentic-workflows.md`: paths, compile, and artifacts.
- `docs/plans/archive/` and `docs/research/archive/`: immutable history.
