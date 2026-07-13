# HFT Grid AI

MetaTrader 5 Expert Advisor foundation with one always-on M1 extremum engine,
broker-aware execution planning, strict risk controls, and schema v7 research
telemetry.

Entrypoint: `HFT_Grid_AI.mq5`.

## Active Engine

- Engine identity: `EXTREMUM_V1`.
- Timeframe: fixed `PERIOD_M1`.
- Source: provisional Stoch Structure extremum slot `0`.
- Direction: `BOTTOM -> BULLISH`, `PEAK -> BEARISH`.
- Entry: existing M1 `high_1`/`low_1` breakout.
- Moving averages: no M1 or macro confirmation and no shifted visual ownership.
- Engine enable inputs: none; the retired `Enable_Strategy_*` inputs are not
  compatibility aliases and must not be restored.

A same-type deeper extremum creates a revision inside the same cycle. A type
transition finalizes the cycle. Fibonacci anchors are frozen at cycle start
from completed structural slots `1` and `2`.

## Safety Boundary

The engine proposes intrinsic attempts. It does not bypass:

- license and entitlement checks;
- direction, session, daily-limit, and concurrency gates;
- spread, market status, stops/freeze, volume, and margin checks;
- drawdown/protection controls;
- symbol/magic scoping and broker reconciliation.

Before a broker position exists, local execution state owns the candidate. Once
a real position exists, broker facts own ticket, volume, entry, close state,
and realized profit.

## Schema V7 Statistics

With `Enable_Signal_Feature_Export=true`, MT5 writes to:

```text
Common\Files\DeterministicSignalML\runs\<run_id>\
```

The export records cycles, revisions, intrinsic attempts, admissions,
broker-entered features, broker-confirmed signal outcomes, and broker-confirmed
leg outcomes. Attempts are captured after valid geometry and before operational
gates, so denied opportunities remain in the census.

`ENGINE_SIMULATION` results are stored only as simulated attempt facts. They do
not create broker outcomes or overwrite tickets, volume, prices, close flags,
or realized profit.

## Research Flow

Use `docs/workflows/extremum-engine-statistics-flow.md` for the complete flow.

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <runs_root> \
  --run-id <schema_v7_run_id> \
  --dataset-id <schema_v7_dataset_id> \
  --schema-version 7 \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id <schema_v7_dataset_id> \
  --audit-id <schema_v7_audit_id> \
  --overwrite
```

The audit maps raw depths to human Fibonacci proximity, compares point-range
buckets, preserves attempt order within cycles, and keeps simulated and broker
profitability in separate lanes. XGBoost splits keep each cycle in one
chronological partition and exclude final-cycle facts from features.

No schema v7 model is approved for MT5 runtime. Historical multi-strategy
artifacts and unapproved v7 research artifacts fail closed.

## Validation

- MQL5 implementation phases require one real MetaEditor compile with
  `0 errors, 0 warnings`.
- Python contracts use compact `unittest` fixtures and DuckDB readback.
- Custom MQL5 tests and agentic CI are not part of the repository policy.
- Strategy Tester/chart validation is human-in-the-loop.
- MetaEditor `/s` is syntax-only and does not prove `.ex5` regeneration.

Agentic compile:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" \
  --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" \
  --log "logs/compile/agentic-build.log" \
  --mode compile
```

## Documentation

- `AGENTS.md`: repository safety and implementation rules.
- `docs/architecture/execution-foundation.md`: lifecycle ownership.
- `docs/workflows/extremum-engine-statistics-flow.md`: active engine workflow.
- `docs/workflows/deterministic-signal-ml-inference-flows.md`: ML runtime boundaries.
- `docs/environment/mt5-agentic-workflows.md`: paths, compile, and artifacts.
- `docs/plans/archive/extremum-engine-cycle-statistics-2026-07-11/`: completed
  extremum engine and schema v7 statistics plan.
- `docs/plans/archive/` and `docs/research/archive/`: immutable historical work.
