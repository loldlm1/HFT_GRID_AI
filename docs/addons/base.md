# Macro/Micro Pivot Market Data Collector And Broker Executor Guide

## Purpose

HFT Grid AI creates one classic pivot ladder from the immediately previous
completed Macro broker candle, records strict schema V10 market and broker
facts, and may execute one broker position per consumed pivot identity. It runs
continuously; there is no user trading-hours filter.

## Inputs

- `Broker_Session`: unchanged broker timestamps or export-only
  Exness-normalized analysis time.
- `Macro_Timeframe`, `Micro_Timeframe`: defaults `H1` and `M3`; both must be
  explicit, distinct, and ordered Micro shorter than Macro.
- `Lot_Type`: fixed lots or fixed-reference-balance percentage risk.
- `Lot_Strategy_Size`: requested lots in fixed mode; reference risk percent in
  percentage mode. Default `0.01` means a `100` account-currency budget from
  the internal `1,000,000` reference.
- `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`: strict V10
  persistence and run identity.
- `Enable_Logs`, `Enable_File_Logs`: optional diagnostics.

Pivot formulas, Bands parameters, and broker protection are not public
controls.

## Execution

The previous completed Macro candle creates `PP`, `S1..S3`, and `R1..R3`.
Live Bid triggers support buys at or below `S1..S3` and resistance sells at or
above `R1..R3`. PP receives one fixed support or resistance role from the first
causal Bid side and triggers only on its return condition.

Each `(symbol, Macro timeframe, active bar open, level)` is consumed once.
Buy requests use fresh Ask and sell requests use fresh Bid. Every allowed route
uses one structural broker SL and a fresh quote-based 1R TP. SL/TP remain
immutable after fill; no trailing or modification path exists.

Hedging mode, actual session, trade permissions, Bid/Ask, geometry,
stops/freeze, FOK support, volume, margin, `OrderCheck`, send retcode, V2 magic,
and ticket reconciliation must pass. Non-hedging accounts collect facts but
send nothing.

## Research Context

Two cached built-in weighted-Bands handles capture Micro `%B 0..5`, Macro pivot
`%B 0..5`, Micro shift-0 bandwidth, and Macro shift-1 bandwidth. Missing
features invalidate research completeness without changing broker execution.

Schema V10 writes six TSV files. Only feature-complete fully closed positions
with one consistent broker TP or SL reason enter the binary cohort. Slippage,
costs, and realized P&L remain outcome diagnostics, not trigger-time features.

## Deterministic Analysis Time

`FIXED_TIME_SESSIONS` leaves time unchanged. `EXNESS_SESSION` preserves broker
time and shifts winter analysis timestamps by `-60` minutes under the symbol
calendar. Analysis time never changes pivot scheduling, triggers, or orders.

## Validation

Substantial multi-sprint MQL5 work uses static review during intermediate
sprints, one real MetaEditor compile at final integration, and human real-tick
Strategy Tester/chart verification. Custom MQL5 harnesses and CI are not part
of the project.
