# Plan: Broker Outcome Profit R Alignment

**Generated**: 2026-07-09
**Estimated Complexity**: Medium

## Overview

The latest `xauusd_2025_dataset_1` audit shows that broker-confirmed partial
TP outcomes are structurally correct, but `signal_outcomes.tsv` can report
`terminal_reason=BROKER_PROFIT` with a negative `profit_r`. The broker result is
correct; the ambiguity comes from `profit_r` being calculated from entry price
to the final close price instead of normalized broker net profit.

## Sprint 1: Align Broker Outcome R

**Goal**: Make signal-level `profit_r` represent broker net R whenever a
broker-confirmed outcome has a valid expected SL loss.
**Commit**: `fix: align broker outcome profit r`
**Demo/Validation**:
- Compile the EA with MetaEditor.
- Validate existing run artifacts; old runs may warn until regenerated.
- Human reruns Strategy Tester and verifies `BROKER_PROFIT` rows have positive
  `profit_r` and `BROKER_LOSS` rows have negative `profit_r`.

### Task 1.1: Export Broker Net R
- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Prefer `raw_profit / expected_sl_loss` for signal-level
  broker-confirmed outcomes. Fall back to price-derived R only when monetary
  risk is unavailable.
- **Dependencies**: Existing broker close reconciliation and risk telemetry.
- **Acceptance Criteria**:
  - Partial TP signal outcomes align `terminal_reason` with `profit_r` sign.
  - Leg outcome `profit_r` remains per-ticket broker net R.
  - Path columns keep their price-path semantics.
- **Validation**: MetaEditor compile and human Strategy Tester rerun.

### Task 1.2: Add Artifact Warning
- **Location**: `tools/deterministic_signal_ml/validate_phase1_run.py`
- **Description**: Warn when broker terminal reason and exported signal-level
  `profit_r` sign disagree.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Existing runs expose the ambiguity as a warning.
  - Future regenerated runs should not warn on broker sign mismatch.
- **Validation**: `build_dataset.py --validate-only`.

## Testing Strategy

- Agent validation:
  - MetaEditor compile with `0 errors, 0 warnings`.
  - `build_dataset.py --validate-only` against the current run.
- Human validation:
  - Rerun Strategy Tester with file logs enabled.
  - Confirm `signal_outcomes.tsv` broker sign consistency and unchanged
    feature/outcome/leg cardinality.

## Potential Risks & Gotchas

- Existing `xauusd_2025_dataset_1` files will keep old `profit_r` semantics
  until the tester regenerates them.
- Path labels and `max_favorable_r` remain price-path statistics; they should
  not be conflated with broker net P/L.
- Broker slippage can still make actual R differ from ideal target multiples.

## Rollback Plan

- Revert the exporter helper and validation warning, restoring price-derived
  signal-level `profit_r`.
