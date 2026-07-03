# Base EA Product Copy

## Product

- Name: `HFT Grid AI - Foundation EA`
- Type: `Core product`
- SKU: `base_ea`

## Short Copy Block

`HFT Grid AI Foundation gives you the core MT5 Expert Advisor baseline: licensing, account controls, risk protections, Stoch Structure context, broker-aware execution boundaries, and a clean base for future strategies.`

## Medium Copy Block

`The Foundation EA is the refounded baseline for HFT Grid AI. It focuses on a smaller, cleaner execution core before new strategies are added. The product keeps essential controls such as license validation, account scoping, spread guards, session filters, risk protection, and strategy context.`

`For non-traders: this is the main application layer. It prepares the EA to evaluate market context and broker conditions before any strategy attempts real execution. Future strategies can be added on top of this foundation without carrying old legacy feature assumptions.`

## Inputs Explained

### License and account

- `EA_License_Key`: activation key. If invalid or expired, the EA does not start.
- `Custom_Magic`: unique ID used to separate this EA's broker positions from others.
- `Max_Spread`: blocks execution when trading cost is too high.
- `Min_Range_Points`: minimum market movement threshold for strategy foundations.

### Protection

- `Protection_Risk_Mode`: controls account protection behavior.
- `Protection_Risk_Drawdown_Type`: defines how drawdown is measured.
- `Protection_Risk_Drawdown_Value`: maximum allowed drawdown value.
- `Account_Size`: fallback account-size reference for risk math.
- `Market_Close_Guard_Timeframe`: timeframe used by market-close guard logic.

### Strategy context

- `Strategy_Timeframe`: timeframe used by strategy context.
- `Stoch_Structure_Period_Type`: Stoch Structure sensitivity.
- `Strategy_Direction_Mode`: allows buys, sells, or both.
- `Signal_Concurrency_Mode`: controls whether one or multiple signals may run.

### Risk and range foundation

- `Strategy_Range_Mode`: range source used by the execution foundation.
- `Strategy_Range_Points`: fixed point range used when point-based range mode is selected.
- `Lot_Type`: lot sizing mode using execution lot type values.
- `Lot_Strategy_Size`: base lot size or risk budget depending on lot mode.
- `Lot_Multiplier`: level-to-level lot scaling multiplier for execution legs.
- `Signal_Lot_Strategy`: future-compatible signal lot adjustment mode.
- `TP_Percent`: target-profit scale while risk/range semantics are simplified.
- `Daily_Signal_Limit`: maximum daily signal count.
- `Daily_Signal_Limit_Mode`: daily limit enforcement mode.

## Access Rule

- Base foundation controls do not require a removed legacy feature add-on.
- A valid key with a future expiry timestamp is always required.

## Validation Model

This refoundation uses phase-level MT5 compile validation for implementation phases. Custom MQL5 test harnesses are not part of the active validation model.
