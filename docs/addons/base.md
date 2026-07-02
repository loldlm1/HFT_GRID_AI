# Base Foundation Guide

## Purpose

HFT Grid AI is being refounded as an MT5 Expert Advisor foundation for future strategy integration. The base product owns licensing, account controls, strategy context, risk controls, execution planning boundaries, and broker-aware safety checks.

This guide describes the foundation baseline only. Final production strategy rules are out of scope until later roadmap phases.

## Included Control Groups

- `EA_License_Key`
- `Account Settings EA`
- `Protection Risk Management`
- `Time Filter Session Manager`
- `Strategy Context`
- `Risk Managment Settings`
- `Developer Debug Settings`

## Preserved Foundation Controls

- License validation and account identity controls.
- Spread and minimum range guards.
- Protection/risk controls, to be simplified around strategy range foundations.
- Session time filters.
- Strategy timeframe, Stoch Structure period, direction mode, and concurrency mode unless a later phase changes them explicitly.
- Lot sizing controls under the future non-grid lot type names.
- Daily signal limits where they remain strategy-neutral.
- Developer debug controls.

## Removed Legacy Feature Controls

The following groups and inputs are not part of the refounded active baseline:

- `Candle Structure Filter`
- `Support Resistance Retest Chain`
- `Structure Trailing Addon`
- `Structure Compound Context`
- `Grid Strategy Settings`
- `Structure_Fibonacci_Levels`
- `Structure_Trigger_Entry`
- `Structure_Touch_Policy`

Do not document these as active features or migration-compatible settings.

## Execution Foundation

The intended lifecycle is:

```text
inputs
-> indicator/context hydration
-> strategy candidate detection
-> local broker-aware execution simulation
-> execution plan
-> optional real broker execution
-> broker position reconciliation
-> protection/risk controls
-> telemetry/frontend
```

Before a real broker position exists, local simulation owns candidate state and must apply broker constraints. Once a real position exists, broker state owns ticket, volume, price, close state, and realized profit.

## Validation

Documentation-only changes do not run MT5 compile. Implementation phases compile once at phase end using MetaEditor, portable/headless first and normal MetaEditor fallback if needed.
