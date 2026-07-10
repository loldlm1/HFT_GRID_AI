# Plan: Partial TP Broker-First Multi-Ticket Execution

**Generated**: 2026-07-09
**Estimated Complexity**: High
**Risk Class**: High, because this changes deterministic entry send, SL/TP placement, broker reconciliation, statistics, and Strategy Tester runtime cleanup.

## Overview

Convert `Partial_TP_Mode=PARTIAL_TP_R_MULTIPLES` from one broker position with EA-managed partial closes into three broker-confirmed hedging legs for the same deterministic signal:

- leg 1: volume slice `0.33`, TP `1R`, SL `-1R`
- leg 2: volume slice `0.33`, TP `2R`, SL `-1R`
- leg 3: volume slice `0.34`, TP `3R`, SL `-1R`

The EA should remain broker-first as far as practical: volume slices must respect broker min/max/step, admission must pass existing broker/risk/session/spread/margin guards, and broker-side SL/TP should be sent with each ticket. Signal-level outcomes remain aggregate broker PnL, while leg-level outcomes provide the clean statistical view for choosing TP levels.

This plan must be executed sprint by sprint. Complete, validate, and commit each sprint before moving to the next sprint when code changes are involved.

## Prerequisites

- Hedging accounts are the target. Netting support is a non-goal for this sprint batch.
- Preserve license, spread, session, protection, margin, market status, volume, stops/freeze, magic-number, and symbol guards.
- Do not add custom MQL5 tests or CI. Validate with MetaEditor compile and human-in-the-loop Strategy Tester.
- Keep schema v6 signal-level files compatible. New leg-level statistics may be additive.

## Sprint 1: Audit And Plan Anchor

**Goal**: Confirm lifecycle change points and record the implementation contract.
**Commit**: `docs: plan broker-first partial tp legs`
**Demo/Validation**:
- Review this plan and the touched lifecycle files.
- No compile required for docs-only changes.

### Task 1.1: Map Current Single-Leg Partial Flow

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Confirm current deterministic flow creates only `leg_index=0` and partial mode uses `PositionClosePartial()`.
- **Acceptance Criteria**:
  - Implementation points are identified before editing.
  - No code changes are mixed into the plan commit.
- **Validation**: Code inspection.

## Sprint 2: Broker-Side Partial TP Legs

**Goal**: In `PARTIAL_TP_R_MULTIPLES`, create and send three broker positions with fixed R-multiple TP and shared SL.
**Commit**: `feat: send partial tp as broker legs`
**Demo/Validation**:
- MetaEditor compile with `0 errors, 0 warnings`.
- Human Strategy Tester visual run with `Partial_TP_Mode=PARTIAL_TP_R_MULTIPLES`.
- Verify three hedging tickets are opened for one signal when broker admission passes.
- Verify each ticket has broker-side SL and its own TP.

### Task 2.1: Build Deterministic Leg Set

- **Location**: `services/trading_signals/execution_controller.mqh`
- **Description**: Replace the partial-mode single-leg setup with three pending `ExecutionLegState` entries sharing entry/SL and using `1R/2R/3R` TP.
- **Acceptance Criteria**:
  - `TP_Percent` continues to control the single TP only when partial mode is off.
  - Partial mode uses fixed R multiples from internal constants.
  - Pending anchor refresh updates all three pending legs together.
- **Validation**: Compile and code review.

### Task 2.2: Split Total Lot Conservatively

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_lot_math.mqh`
- **Description**: Split the total planned lot by `0.33/0.33/0.34`, respecting volume min/step and failing closed when three valid broker tickets are impossible.
- **Acceptance Criteria**:
  - Total assigned volume never exceeds the total planned volume.
  - Small lots that cannot create three valid broker tickets are blocked before send.
  - Risk-plan telemetry remains aggregate.
- **Validation**: Compile plus Strategy Tester admission/log review.

### Task 2.3: Broker-Side SL/TP Admission And Send

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Include leg SL/TP in `OrderCheck()` and pass SL/TP to `CTrade::Buy/Sell`.
- **Acceptance Criteria**:
  - Existing guardrails still run before broker send.
  - Broker check validates the same SL/TP sent to the broker.
  - If any required partial leg fails after prior sends, the EA closes already-sent legs and closes the signal as a failed partial entry.
- **Validation**: Compile plus tester order/admission logs.

## Sprint 3: Broker-Confirmed Leg Statistics

**Goal**: Add additive leg-level stats so TP1/TP2/TP3 can be evaluated from real broker ticket outcomes.
**Commit**: `feat: export broker leg outcomes`
**Demo/Validation**:
- MetaEditor compile with `0 errors, 0 warnings`.
- Small Strategy Tester run with file logs enabled.
- Verify `signal_leg_outcomes.tsv` appears and has one row per broker-confirmed leg close.

### Task 3.1: Store Per-Leg Close Facts

- **Location**: `services/trading_signals/signal_params_struct.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Persist per-leg close volume, close price, close time, realized net profit, and close source from broker history or EA close calls.
- **Acceptance Criteria**:
  - Signal-level aggregate PnL still matches broker-confirmed closes.
  - Leg-level TP flags are marked only when that broker leg closes on its TP side.
- **Validation**: Compile and log review.

### Task 3.2: Export Additive Leg Outcome TSV

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`, `tools/deterministic_signal_ml/README.md`
- **Description**: Write an optional `signal_leg_outcomes.tsv` without changing required schema v6 signal-level files.
- **Acceptance Criteria**:
  - Existing schema v6 builder/validator remains compatible.
  - Leg rows include target R, expected SL loss, net profit, and broker-normalized profit R.
- **Validation**: Compile and Python syntax check for touched tooling/docs if applicable.

## Sprint 4: Pending Signal Invalidation Cleanup

**Goal**: Reduce Strategy Tester tick work and remove stale visual lines when a pending signal reaches SL before broker activation.
**Commit**: `fix: cancel pending deterministic signals at sl`
**Demo/Validation**:
- MetaEditor compile with `0 errors, 0 warnings`.
- Human Strategy Tester visual run where pending signal invalidates before entry.
- Verify the signal is canceled, chart lines are removed by cleanup, and no broker outcome row is written.

### Task 4.1: Add Pending SL Invalidation

- **Location**: `services/trading_signals/execution_controller.mqh`
- **Description**: For pending deterministic signals with no broker exposure, close the signal when the broker exit-side price reaches the stop side before entry activation.
- **Acceptance Criteria**:
  - No broker send is attempted after pending SL invalidation.
  - Cleanup records a lifecycle cancel, not a broker outcome.
  - Visual levels are removed through existing signal cleanup.
- **Validation**: Compile and Strategy Tester visual QA.

## Testing Strategy

- Docs-only sprint: code inspection.
- Implementation sprints: run `python3 tools/mt5/compile_mt5.py --wine --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" --log "<repo>/logs/compile/<sprint>.log" --timeout 180`.
- Final runtime validation remains human-in-the-loop Strategy Tester with file logs enabled.

## Potential Risks & Gotchas

- Three tickets are not atomic. The EA must preflight all legs and close already-sent legs if a later send fails.
- Broker min volume can make three slices impossible for very small lot settings.
- Broker-side SL/TP may be rejected when price gaps make a target too close to current price.
- Signal-level aggregate PnL and leg-level TP potential answer different questions; both should be kept separate.

## Rollback Plan

- Revert the sprint commits in reverse order.
- If broker-side partial legs fail Strategy Tester validation, revert Sprint 2 and Sprint 3 while keeping pending SL invalidation only if it validates independently.
