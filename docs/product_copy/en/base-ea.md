# Base EA Product Copy

## Product

- Name: `HFT Grid AI - Market Data Executor`
- Type: `MT5 market-data collector and broker executor`
- SKU: `base_ea`

## Short Copy

`HFT Grid AI turns a fixed M1 Stoch Structure extremum stream into deterministic schema v8 market data, broker-safety evidence, and an optional one-position execution path with broker-side protection.`

## Medium Copy

`The EA runs continuously, observes each M1 PEAK and BOTTOM revision, and records the broker facts needed to understand whether an attempt could execute. It keeps raw broker time alongside a normalized analysis clock for comparable research across DST-changing Exness sessions.`

`When execution is eligible, the EA can send one hedging-account position with a structural stop and fixed 1R take profit. Actual market session, permissions, stops and freeze levels, volume rules, margin, OrderCheck, send results, and broker ticket reconciliation remain mandatory.`

## Inputs Explained

- `Broker_Session`: keep broker timestamps unchanged or add Exness-normalized
  analysis time without changing live order timing.
- `Lot_Type`: fixed lot size or account-balance percentage risk.
- `Lot_Strategy_Size`: requested lots in fixed mode; risk percent in balance
  mode.
- Statistics fields: enable schema v8 persistence and identify the run.
- ML fields: disabled, passive shadow scoring, or Strategy Tester-only denial.
- Pattern fields: Strategy Tester-only playback of a selected local audit set.
- Debug fields: optional terminal and file diagnostics.

## Safety Boundary

Non-hedging accounts remain data-collection only. Spread is recorded rather
than compared with a user threshold. No licensing, user session schedule,
drawdown panel, multi-leg grid, partial TP, or public magic-number setting is
part of this product contract.

## Validation Model

The project uses static logic review throughout a multi-sprint change, one
final real MetaEditor compile, and human Strategy Tester/chart acceptance. It
does not maintain custom MQL5 test harnesses or MQL5 CI.
