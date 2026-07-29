# Pivot Fractal Market Data Collector And Broker Executor Guide

## Purpose

HFT Grid AI caches classic pivot ladders from each immediately previous
completed `M15`, `M30`, `H1`, `H4`, and `D1` broker candle, records strict V9
market and broker facts, and may execute one broker position per admissible
first-touch identity. It runs continuously; there is no user trading-hours
filter.

## Inputs

- `Broker_Session`: unchanged broker timestamps or export-only
  Exness-normalized analysis time.
- `Lot_Type`: fixed lots or account-balance percentage risk.
- `Lot_Strategy_Size`: requested lots in fixed mode; balance-risk percent in
  percentage mode.
- `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`: strict V9
  persistence and run identity.
- `Enable_Logs`, `Enable_File_Logs`: optional diagnostics.

Pivot formulas/timeframes and broker protection are not public controls.

## Execution

The previous completed M1 Bid close establishes which side of each level price
came from. Live Bid detects the first inclusive touch: downward from above is a
buy and upward from below is a sell. Buy requests execute at Ask and sell
requests at Bid.

Each `(symbol, timeframe, active bar open, level)` is consumed once. Allowed
routes use broker-side structural SL, terminal pivot TP, and captured-level
trailing. Hedging mode, actual session, trade permissions, Bid/Ask, geometry,
stops/freeze, volume, margin, `OrderCheck`, send retcode, magic, and ticket
reconciliation must pass. Non-hedging accounts collect facts but send nothing.

## Deterministic Analysis Time

`FIXED_TIME_SESSIONS` leaves time unchanged. `EXNESS_SESSION` preserves broker
time and shifts winter analysis timestamps by `-60` minutes under the symbol
calendar. Analysis time never changes pivot scheduling, touches, or orders.

## Validation

Substantial multi-sprint MQL5 work uses static review during intermediate
sprints, one real MetaEditor compile at final integration, and human Strategy
Tester/chart verification. Custom MQL5 harnesses and CI are not part of the
project.
