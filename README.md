# HFT Grid AI Refoundation

**Platform:** MetaTrader 5 (MQL5)
**Entrypoint:** `HFT_Grid_AI.mq5`
**Current focus:** refounded EA foundation for future strategy integration

HFT Grid AI is being refounded into a smaller, broker-aware MT5 Expert Advisor foundation. The active work removes legacy strategy features and grid-specific public domain naming before new strategies are integrated.

## Current Docs

- `ROADMAP.md`: master refoundation roadmap.
- `docs/plans/phase-00-foundation-contract-plan.md`: completed foundation contract plan.
- `docs/plans/phase-01-docs-reset-plan.md`: active docs reset plan.
- `docs/architecture/execution-foundation.md`: target local/broker execution foundation.
- `AGENTS.md`: contributor rules for the current refoundation.

## Validation Model

- Documentation-only phases do not run MT5 compile.
- Implementation phases compile once at phase end.
- Portable/headless MetaEditor compile is preferred.
- Normal MetaEditor compile is the fallback.
- Legacy custom MQL5 tests, test harnesses, and agentic CI are not part of the active validation model.

Preferred compile command shape for implementation phases:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\phase-build.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

Fallback:

```powershell
& $metaeditor /s /compile:$entrypoint /log:$log
```

## Refoundation Scope

Removed feature groups:

- `Candle Structure Filter`
- `Support Resistance Retest Chain`
- `Structure Trailing Addon`
- `Structure Compound Context`
- `Grid Strategy Settings`

Removed individual inputs:

- `Structure_Fibonacci_Levels`
- `Structure_Trigger_Entry`
- `Structure_Touch_Policy`

Preserved foundation areas:

- License and account settings.
- Protection/risk controls.
- Session time filters.
- Strategy timeframe, Stoch Structure period, direction mode, and concurrency mode unless a later phase changes them explicitly.
- Developer debug controls.
- Stoch Structure as the structural context source.

## Execution Direction

The target lifecycle is:

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

Before a real broker position exists, local simulation owns candidate state and applies broker conditions. After a real position exists, broker state owns ticket, volume, entry price, close state, and profit.

## Repository Layout

- `HFT_Grid_AI.mq5`: EA entrypoint.
- `services/`: ordered include pipeline and EA services.
- `indicators/`: indicator sources used by the EA.
- `docs/`: active roadmap, plans, architecture, and product docs.

Legacy custom tests and the old test runner were removed in Phase 2. The active validation path is MT5 compile at implementation phase end.
