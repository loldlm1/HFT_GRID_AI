# HFT Grid AI

MetaTrader 5 Expert Advisor for causal Macro pivot collection, nested Deep research,
paired-timeframe indicator capture, and one structural Macro 1R broker execution
lane. The entrypoint is `HFT_Grid_AI.mq5`.

| Identity | Value |
| --- | --- |
| EA property version | `1.40` |
| Export schema | Strict `14`, twelve TSV files |
| Signal source | `PIVOT_FRACTAL_V2` |
| Default periods | Micro M3, Deep M10, Macro H1 |

Classic pivots come from previous completed broker candles. Macro origins capture
Macro + Deep features and eight structural/midpoint research lanes. Deep events
capture Deep + Micro features in both directions during active Macro lifecycles,
with ALIGNED/OPPOSED parent links and shared 1R/2R/3R trials. The independently
checked broker lane uses FOK, immutable structural protection and a fresh-quote
1R target. Research and export never control live broker execution. Fatal research
errors stop the Strategy Tester and invalidate its dataset.

Offline Python tools validate V14, build typed native-grain datasets, audit support
and leakage, and train explicitly selected H1 or deep candidates. The separate
Exness source tool prepares historical ticks and records native/broker comparison
evidence. Neither tool creates a runtime model or authorizes live deployment.

The independent `Candle_Pattern_Discovery.mq5` adds Micro Harami/Engulfing
discovery, ATR stops, both directions and one broker-SL re-entry. Its separate
[Candle contract and tools](tools/candle_pattern_ml/README.md) capture Macro/Micro
features and support independent pattern/direction research with first-N entry
allowances. Pivot V14 retains its existing entrypoint and dataset.

## Where To Go

- [Current status and evidence](docs/README.md): active work, accepted inputs and remaining gates.
- [Runtime contract](docs/architecture/market-data-broker-executor.md): inputs, pivots, lanes, broker safety, time and schema.
- [Environment and validation](docs/environment/mt5-agentic-workflows.md): setup, compilation and existing checks.
- [V14 research tool](tools/deterministic_signal_ml/README.md): validate, build, audit and train.
- [Exness source tool](tools/exness_tick_history/README.md): prepare, import, capture and compare.
- [Project instructions](AGENTS.md): maintenance and contribution boundaries.

Private exports, datasets, terminal evidence and compiled binaries remain local.
Start any operational work from the current-status index; a compile or research
acceptance record does not authorize live trading.
