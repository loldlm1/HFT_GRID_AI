# Market Data Collector And Broker Executor Guide

## Purpose

HFT Grid AI observes the fixed M1 Stoch Structure extremum, records schema v8
market and broker facts, and may execute one broker position per admissible
attempt. It runs continuously; there is no user trading-hours filter.

## Inputs

- `Broker_Session`: selects unchanged broker timestamps or Exness-normalized
  analysis timestamps.
- `Lot_Type`: fixed lots or account-balance percentage risk.
- `Lot_Strategy_Size`: lots in fixed mode; balance-risk percent in percentage
  mode.
- Statistics, ML, pattern-audit, and debug fields control their named outputs
  without bypassing broker safety.

## Execution

The EA derives direction from the provisional extremum, waits for the M1
breakout, refreshes actual broker eligibility, and sends one market order with
a structural broker-side stop and fixed 1R take profit. Hedging mode, market
session, permissions, stops/freeze, volume, margin, `OrderCheck`, send retcode,
symbol, magic, and ticket reconciliation must all pass.

Non-hedging accounts continue collecting market facts but do not send orders.
Spread is recorded and not compared with a configurable threshold.

## Deterministic Analysis Time

`FIXED_TIME_SESSIONS` leaves time unchanged. `EXNESS_SESSION` preserves broker
time and shifts winter analysis timestamps by `-60` minutes under the
instrument calendar. This keeps sessions comparable for research and never
changes live scheduling or order timing.

## Validation

Substantial multi-sprint MQL5 work uses static review during intermediate
sprints, one real MetaEditor compile at final integration, and human Strategy
Tester/chart verification. Custom MQL5 harnesses and CI are not part of the
project.
