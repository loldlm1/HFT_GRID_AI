# Execution Foundation Architecture

## Purpose

This document defines the target execution foundation for the HFT Grid AI refoundation. It is implementation-guiding documentation, not the final strategy specification.

The goal is to provide a stable base where future strategies can be integrated without carrying legacy sequencing, removed entry-policy inputs, or removed add-on assumptions.

## Target Flow

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

## Lifecycle Ownership

### Phase 6 Implementation Status

Phase 6 is implemented as of 2026-07-02. Active execution now has a broker execution snapshot/eligibility contract for local decisions and a broker position reconciliation layer for real-position source of truth.

### Phase 7 Performance Status

Phase 7 is implemented as of 2026-07-03. Active execution now reuses execution-owned indicator handles, releases indicator handles deterministically, bounds Stoch Structure buffer reads, keeps broker reconciliation ticket-first, reserves hot-path logging/frontend arrays, and throttles chart refresh in visual/live tick paths.

### Before Real Execution

Before a real broker position exists, local execution simulation owns candidate and planned execution state.

Local simulation must apply broker-relevant conditions before it marks an execution candidate as actionable:

- current bid/ask and spread
- broker stops level
- broker freeze level
- symbol volume min/max/step
- margin availability
- market status and close-only state
- session filters
- license and entitlement gates
- drawdown/protection controls
- symbol and magic-number scope

The local result is a deterministic execution decision, not a broker-confirmed position.

### After Real Execution

After a real broker position exists, broker state is the source of truth for:

- position ticket
- symbol
- magic-number scope
- position type
- volume
- entry price
- current close state
- realized and broker-confirmed profit data

Local state may reconcile against broker state, but it must not overwrite broker facts.

## Core State Concepts

The foundation should use strategy-neutral naming:

- `strategy candidate`: a potential signal produced by future strategy logic.
- `execution plan`: a broker-aware plan derived from a candidate.
- `execution leg`: one planned, simulated, or real execution unit.
- `broker snapshot`: the current broker position/order facts used for reconciliation.
- `execution lifecycle`: activation, send, reconciliation, completion, and cleanup.
- `broker execution snapshot`: current bid/ask, spread, constraints, permissions, volume, and margin facts used before local activation.
- `broker position snapshot`: scoped real position facts selected by ticket first, then by symbol, magic number, direction, and execution comment fallback.

Legacy strategy-specific names should be removed or isolated to historical artifacts scheduled for deletion.

## Future Strategy Integration Baseline

Future strategies should enter the foundation as strategy candidates and let the execution planner apply range, broker, session, protection, and license gates. They should not open, close, or resize broker positions directly.

Strategy-specific statistics should distinguish local simulated decisions from broker-confirmed outcomes so future optimization work can audit decision quality without conflating it with broker execution facts.

## Risk And Safety Controls

These controls are foundation-owned and must not be weakened by future strategy work:

- license guard and entitlement checks
- spread guard
- broker stops/freeze constraints
- volume min/max/step normalization
- margin guard
- drawdown/protection limits
- session filter gates
- market status and close-only handling
- symbol and magic-number scoping
- real broker position reconciliation

Future strategies can request execution, but they do not bypass these controls.

## Performance Principles

Real-tick Strategy Tester optimization is a primary constraint. Hot paths must stay bounded.

Implementation phases should preserve these rules:

- Do not create indicator handles on every tick.
- Reuse handles and release them deterministically in deinit paths.
- Do not scan full history on tick paths.
- Avoid repeated `SymbolInfo*`, `PositionSelect*`, and array resizing work when cached or scoped data is sufficient.
- Keep logging quiet by default and gated behind debug inputs.
- Do not let chart objects or frontend telemetry affect trading decisions.

## Documentation Boundaries

This document does not define final production strategy rules.

Phase ownership:

- Phase 2 removes legacy custom tests and harnesses from the active repository.
- Phase 3 removes legacy feature inputs and code paths.
- Phase 4 renames the domain to execution foundation public/internal naming.
- Phase 5 simplifies strategy range and risk foundations.
- Phase 6 implements broker-aware local execution state and reconciliation. Completed on 2026-07-02.
- Phase 7 performs the real-tick performance pass. Completed on 2026-07-03.
