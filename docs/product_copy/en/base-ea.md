# Base EA Product Copy

## Product

- Name: `HFT Grid AI - Pivot Fractal Market Data Executor`
- Type: `MT5 market-data collector and broker executor`
- SKU: `base_ea`

## Short Copy

`HFT Grid AI turns completed multi-timeframe pivot windows and M1 first touches into deterministic schema V9 market data, broker-safety evidence, and an optional structurally protected execution path.`

## Medium Copy

`The EA continuously calculates classic pivot ladders from the immediately previous completed M15, M30, H1, H4, and D1 broker candles. It uses the previous M1 Bid close and live Bid to record one first touch per timeframe, active window, and level, while keeping raw broker time alongside normalized research time.`

`When execution is eligible, the EA can send one hedging-account market position with a broker-side structural stop, terminal pivot target, and ticket-owned pivot trailing. Actual market session, permissions, Bid/Ask geometry, stops and freeze levels, volume rules, margin, OrderCheck, send results, and broker reconciliation remain mandatory.`

## Inputs Explained

- `Broker_Session`: preserve broker timestamps or add export-only
  Exness-normalized analysis time.
- `Lot_Type`: fixed lot size or account-balance percentage risk.
- `Lot_Strategy_Size`: requested lots in fixed mode; risk percent in balance
  mode.
- Statistics fields: enable strict schema V9 persistence and identify the run.
- Debug fields: optional terminal and file diagnostics.

## Safety Boundary

Non-hedging accounts remain data-collection only. Spread is recorded rather
than compared with a user threshold. No licensing, user session schedule,
drawdown panel, multi-leg grid, partial TP, runtime model control, pattern
playback, or public magic-number setting is part of this product contract.

## Validation Model

The project uses static logic review throughout a multi-sprint change, one
final real MetaEditor compile, and human Strategy Tester/chart acceptance. It
does not maintain custom MQL5 test harnesses or MQL5 CI.
