# Base EA Product Copy

## Product

- Name: `HFT Grid AI - Macro/Micro Pivot Market Data Executor`
- Type: `MT5 market-data collector and broker executor`
- SKU: `base_ea`

## Short Copy

`HFT Grid AI turns one completed Macro pivot window and live Micro weighted-Bands context into deterministic schema V10 market data, broker-safety evidence, and an optional immutable 1R execution path.`

## Medium Copy

`The EA calculates one classic pivot ladder from the immediately previous completed Macro broker candle, default H1. It observes live Bid for support buys and resistance sells, while a default M3 weighted-Bands context captures current volatility and causal %B structure.`

`When execution is eligible, the EA can send one FOK market position on a hedging account with a structural broker stop and a fresh quote-based 1R target. Broker session, permissions, Bid/Ask geometry, stops and freeze levels, volume rules, margin, OrderCheck, send results, immutable SL/TP, and ticket reconciliation remain mandatory.`

## Inputs Explained

- `Broker_Session`: preserve broker timestamps or add export-only
  Exness-normalized analysis time.
- `Macro_Timeframe`, `Micro_Timeframe`: default H1/M3 research horizons.
- `Lot_Type`: fixed lot size or fixed-reference-balance percentage risk.
- `Lot_Strategy_Size`: requested lots in fixed mode; reference risk percent in
  percentage mode. The default `0.01` requests a 100-unit budget from the fixed
  internal `1,000,000` reference, independent of current account balance.
- Statistics fields: enable strict schema V10 persistence and identify the run.
- Debug fields: optional terminal and file diagnostics.

## Research And Outcome Boundary

Schema V10 records Micro and Macro pivot `%B`, normalized bandwidth, broker
checks, immutable execution geometry, slippage, costs, and broker-confirmed
outcomes. Exact price-distance 1R does not promise exact net `+100` or `-100`:
volume steps, instrument conversion, execution, commission, swap, and fees are
reported separately.

Only feature-complete, fully closed, consistent broker TP/SL positions enter
the binary research target. Models remain offline and cannot authorize trades.

## Safety Boundary

Non-hedging accounts remain data-collection only. Spread is recorded rather
than compared with a user threshold. No licensing, user session schedule,
drawdown panel, trailing, multi-leg grid, partial TP, runtime model control,
pattern playback, or public magic-number setting is part of this contract.

## Validation Model

The project uses static logic review throughout a multi-sprint change, one
final real MetaEditor compile, and human real-tick Strategy Tester/chart
acceptance. It does not maintain custom MQL5 test harnesses or MQL5 CI.
