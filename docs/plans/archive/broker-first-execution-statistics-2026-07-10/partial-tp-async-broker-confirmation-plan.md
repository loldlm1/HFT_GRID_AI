# Plan: Partial TP Async Broker Confirmation

**Generated**: 2026-07-09
**Estimated Complexity**: Medium

## Overview

The latest `xauusd_2025_dataset_1` Strategy Tester run confirmed that
`PARTIAL_TP_R_MULTIPLES` exported one signal-level row per logical signal, but
the three broker legs were often filled across following ticks. This plan keeps
the broker-first multi-ticket model while reducing tick drift in tester partial
entries and deferring signal statistics until broker entry evidence exists for
all legs.

## Sprint 1: Audit And Async Batch Admission

**Goal**: Quantify the tester artifact drift and send partial TP legs as one
tester async batch without changing live execution semantics.
**Commit**: `fix: batch partial tp tester entries`
**Demo/Validation**:
- Audit `Common/Files/DeterministicSignalML/runs/xauusd_2025_dataset_1`.
- Compile the EA with `tools/mt5/compile_mt5.py`.
- Human reruns Strategy Tester and verifies leg entry times are no longer
  spread across following ticks.

### Task 1.1: Confirm Current Dataset Shape
- **Location**: Strategy Tester Common Files run artifacts.
- **Description**: Count signal features, signal outcomes, leg outcomes,
  admissions, and per-signal leg entry deltas.
- **Dependencies**: Existing user run with file logs enabled.
- **Acceptance Criteria**:
  - Signal-level rows remain one row per logical signal.
  - Leg-level rows remain three rows per closed signal in partial mode.
  - Entry-time deltas identify whether broker legs drift across ticks.
- **Validation**: Compact TSV/log parser summary.

### Task 1.2: Add Tester-Only Async Batch Sends
- **Location**:
  - `services/trading_signals/execution_lifecycle.mqh`
  - `services/trading_signals/execution_controller.mqh`
- **Description**: Use async broker sends only when partial TP mode is enabled
  in the Strategy Tester. Keep normal live execution synchronous.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Broker/risk admission checks still run before every leg.
  - Live/non-tester behavior remains synchronous.
  - A send failure closes/fails the partial batch fail-closed.
- **Validation**: MetaEditor compile and human tester rerun.

## Sprint 2: Broker Confirmation And Statistics Gating

**Goal**: Prevent signal statistics from being exported before all broker legs
are confirmed, and reconcile async fills promptly from trade transactions.
**Commit**: `fix: gate partial tp stats on broker confirmation`
**Demo/Validation**:
- Compile the EA.
- Human reruns Strategy Tester with file logs enabled.
- Verify no feature row is exported before all three leg broker entries are
  confirmed.

### Task 2.1: Defer Deterministic Entry Statistics
- **Location**: `services/trading_signals/execution_controller.mqh`
- **Description**: Finalize feature, pattern, ML shadow, and entry log export
  only after every opening leg has broker entry evidence.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Partial TP features are signal-level and exported once.
  - Leg-level outcomes remain broker-derived.
  - Async batches fail closed if broker entry confirmation times out.
- **Validation**: Compile plus rerun audit.

### Task 2.2: Reconcile On Trade Transactions
- **Location**:
  - `services/trading_signals/tick_signals_manager.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**: Reconcile active signals and retry deferred statistics when
  MT5 emits trade transactions.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Async fills can attach tickets before the next strategy tick.
  - Existing magic-number and symbol-scoped reconciliation remains unchanged.
- **Validation**: Compile and manual Strategy Tester rerun.

## Testing Strategy

- Agent validation: MetaEditor compile through `tools/mt5/compile_mt5.py`.
- Human-in-loop validation: rerun one-month Strategy Tester visual/non-visual
  with `File_Logs` enabled and audit the refreshed run directory plus
  `query_debug.txt`.

## Potential Risks & Gotchas

- MT5 can still apply broker-side slippage or execution-price differences; the
  goal is to avoid EA-side sequential tick drift, not to fake a single fill.
- Async market requests that fill and close very quickly rely on trade
  transaction reconciliation to capture the ticket before cleanup.
- The Strategy Tester report will still show three broker positions per logical
  signal because that is now the intentional broker-side representation.

## Rollback Plan

- Revert the tester-only async path and `OnTradeTransaction` reconciliation
  wiring, returning partial TP entry sends to the previous synchronous loop.
