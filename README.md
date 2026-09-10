# HFT Grid AI

MetaTrader 5 Expert Advisor for causal H1 pivot collection, nested M10 research,
configured-Micro indicator capture, and one structural H1 1R broker execution
lane. The entrypoint is `HFT_Grid_AI.mq5`.

| Identity | Value |
| --- | --- |
| EA property version | `1.30` |
| Export schema | Strict `13`, twelve TSV files |
| Signal source | `PIVOT_FRACTAL_V2` |
| Default periods | Micro M3, Deep M10, Macro H1 |

Classic pivots come from previous completed broker candles. Consumed H1 origins
can declare eight structural/midpoint research lanes; shared M10 events capture
one Micro feature vector and parent-scoped 1R/2R/3R outcomes. The independently
checked broker lane uses FOK, immutable structural protection and a fresh-quote
1R target. Research and export never control broker execution.

Offline Python tools validate V13, build typed native-grain datasets, audit support
and leakage, and train explicitly selected H1 or deep candidates. The separate
Exness source tool prepares historical ticks and records native/broker comparison
evidence. Neither tool creates a runtime model or authorizes live deployment.

## Where To Go

- [Current status and evidence](docs/README.md): active work, accepted inputs and remaining gates.
- [Runtime contract](docs/architecture/market-data-broker-executor.md): inputs, pivots, lanes, broker safety, time and schema.
- [Environment and validation](docs/environment/mt5-agentic-workflows.md): setup, compilation and existing checks.
- [V13 research tool](tools/deterministic_signal_ml/README.md): validate, build, audit and train.
- [Exness source tool](tools/exness_tick_history/README.md): prepare, import, capture and compare.
- [Project instructions](AGENTS.md): maintenance and contribution boundaries.

Private exports, datasets, terminal evidence and compiled binaries remain local.
Start any operational work from the current-status index; a compile or research
acceptance record does not authorize live trading.
