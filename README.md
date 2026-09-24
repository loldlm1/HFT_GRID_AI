# HFT Grid AI

Reusable model-feature capture for independent MetaTrader 5 strategy engines.
Pivot and Candle share indicators, clocks, pivot context and immutable dataset
services while retaining their own broker and virtual-lifecycle rules.

| Producer | Engine | Dataset |
| --- | --- | --- |
| `HFT_Grid_AI.mq5` | `PIVOT_MACRO_V1` | Common schema 1, ten TSVs |
| `Candle_Pattern_Discovery.mq5` | `CANDLE_PATTERN_ATR_V2` | Common schema 1, eleven TSVs |

Both EAs are version `2.00`. Default roles are Macro H1 / Micro M3, with supported
native periods satisfying `Micro < Macro`. Each role captures shifts 0..5 of
Stochastic 5/3/3 Close/Close K/D, ordinary weighted-price percent B/SMA5 and
ATR13/SMA5. A separate fixed M1 source captures confirmed and live forming
Stochastic structure, including candidates not yet drawn by the reference chart
indicator. Macro pivot intervals and the signal's relation to the latest tested
support/resistance use captured Bid.

Pivot uses previous completed native Macro candles, eight structural/midpoint
virtual lanes and one checked FOK structural 1R broker lane. Its active Deep path
is removed. Candle discovers Micro Harami/Engulfing patterns, uses independent
ATR stops, trades both directions, allows one confirmed-SL re-entry and enforces
each entry's Macro-duration expiry. Both keep submitted SL/TP immutable.

Exports live under `Common/Files/MQL5ModelDatasetV1/runs/<run_id>/`. Raw broker
clocks govern causality; the versioned Exness analysis clock is an export-only
view. Prices retain raw precision, actual milliseconds remain distinct from
second-only clocks, and unknowns are explicit. Optional capture never controls
orders. Fatal research errors invalidate the dataset and stop only its tester.

The shared local Python reader validates this family. Historical Pivot V14 and
Candle 1/2/3 readers and datasets remain separate. No Django changes or runtime
model integration are included.

## Where To Go

- [Current status and evidence](docs/README.md): active work, accepted inputs and remaining gates.
- [Runtime contract](docs/architecture/market-data-broker-executor.md): inputs, pivots, lanes, broker safety, time and schema.
- [Shared dataset contract](docs/architecture/model-feature-dataset.md): fields, feature meaning, grains and new-engine integration.
- [Producer handoff](docs/research/model-feature-producer-handoff.md): version mappings, examples, pins and later backend planning.
- [Environment and validation](docs/environment/mt5-agentic-workflows.md): setup, compilation and existing checks.
- [Shared dataset reader](tools/model_dataset/README.md): validate current exports and generate the machine contract.
- [Historical V14 research](tools/deterministic_signal_ml/README.md) and [Candle research](tools/candle_pattern_ml/README.md): retained readers for old exports.
- [Exness source tool](tools/exness_tick_history/README.md): prepare, import, capture and compare.
- [Project instructions](AGENTS.md): maintenance and contribution boundaries.

Private exports, datasets, terminal evidence and compiled binaries remain local.
Start any operational work from the current-status index; a compile or research
acceptance record does not authorize live trading.
