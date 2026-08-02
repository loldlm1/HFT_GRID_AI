# Plan: Pivot HFT Immediate Entry And Campaign Consumption

**Generated**: 2026-08-02
**Status**: Completed
**Completed**: 2026-08-02
**Complexity**: Critical / trading-sensitive
**Execution**: Sprints 1-4 in order, one validated commit per Sprint

## Objective

Simplify Pivot HFT exits to one Bollinger-width risk model, make zero
retracement mean immediate guarded entry, and prevent a profitable outer pivot
campaign from reopening an inner level already traversed by the same micro
candle.

## Audit Decision

The repository copies of `query_debug.txt` do not contain the focused Pivot HFT
run: the root file is a legacy October 2025 grid trace and
`logs/query_debug.txt` is a January 2024 Pandora/Fibonacci trace. The current
code nevertheless exposes the reported sequence deterministically:

1. A losing local R1 close can re-arm R1 during the same micro candle.
2. If that candle later reaches R2, detection replaces the R1 campaign with R2.
3. A profitable R2 close marks only R2 completed.
4. The next unoccupied-level scan skips R2 and falls back to R1.

The correction is directional ladder consumption on profitable closes. An R2
winner consumes R1+R2; R3 consumes R1+R2+R3. S2 and S3 apply the symmetric
support rule. This is limited to the winning position's fill micro candle.
Losing local closes retain the existing same-candle retry behavior.

This rule matches the nested pivot geometry: reaching an outer level implies
the candle already traversed the inner same-side levels. Reusing an inner level
after an outer-level win would count the same price excursion as a fresh event
and bias trade frequency toward one candle.

## Fixed Decisions

- Remove `Pivot_HFT_Local_SL_Mode`, `Pivot_HFT_Local_SL_Points`, and
  `Pivot_HFT_TP_Step_Points` from the public input surface.
- Remove the now-redundant SL-mode enum and per-ticket mode field.
- Always resolve initial local SL from the cached previous-closed-bar Bollinger
  full width and `Pivot_HFT_Local_SL_Bands_Width_Percent`.
- Keep `Pivot_HFT_TP_Step_SL_Ratio`, require it to be positive, and default it
  to `1.0`; trailing step is always an immutable initial-SL multiple.
- Keep `Pivot_HFT_Fixed_TP_SL_Ratio = 0.0` as the only zero-disabled exit input.
- Accept `Pivot_HFT_Retracement_Points = 0.0` as immediate entry intent and
  reject negative values during `OnInit`.
- Immediate means the existing guarded market execution path, not a broker
  pending order. Spread, session, daily budget, protection, market status,
  margin, symbol/magic, license, and single-flight gates remain authoritative.
- Add no harness, CI, parser, fixture, or Strategy Tester automation.
- Run the complete MetaEditor compile only in Sprint 4. The user owns manual
  Strategy Tester QA after handoff.

## Sprint 1: Mandatory Bollinger Risk Geometry

**Goal**: Remove redundant exit inputs and make cached band width the sole SL
source.

**Files**: `microservices/core/enums.mqh`,
`services/trading_management/ea_inputs.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_risk_geometry.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/frontend/pivot_hft_panel.mqh`, `HFT_Grid_AI.mq5`, this plan.

**Commit**: `Sprint 1: simplify pivot hft band risk inputs`

### Acceptance Criteria

- The three requested inputs and the obsolete enum have no active-code
  references.
- Band width comes only from the existing cached upper/lower snapshot.
- Initial SL and trailing step remain immutable per ticket.
- Step ratio must be positive; fixed TP ratio remains non-negative.
- Server-side SL/TP remain zero and no indicator handle is added.
- Static diff/reference checks pass; no full compile or tester run occurs.

## Sprint 2: Zero-Retracement Immediate Intent

**Goal**: Interpret zero retracement as immediate entry after campaign
admission.

**Files**: `services/trading_signals/pivot_hft_detection.mqh`,
`services/frontend/pivot_hft_panel.mqh`, `HFT_Grid_AI.mq5`.

**Commit**: `Sprint 2: enable immediate zero retracement entries`

### Acceptance Criteria

- `0.0` transitions a newly armed or retryable campaign to order-wait without
  waiting for price movement.
- Positive retracement preserves current directional extreme/threshold logic.
- Negative retracement fails initialization.
- Entry still passes through every existing execution guard and fill
  verification path.
- Audit output distinguishes immediate from distance-triggered intent.
- Static flow/diff checks pass; no full compile or tester run occurs.

## Sprint 3: Profitable Pivot-Ladder Consumption

**Goal**: Make an outer-level winner consume traversed inner levels from the
same directional candle event.

**Files**: `services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`.

**Commit**: `Sprint 3: consume inner pivot levels after wins`

### Acceptance Criteria

- Profitable R2/R3 and S2/S3 closes mark the appropriate same-side ladder
  occupied for the position's fill micro candle.
- R1/S1 winners consume only themselves.
- Opposite-side levels and other micro candles are untouched.
- Losing local closes preserve same-candle reattempt behavior.
- A bounded finalization audit records the consumed mask/levels.
- Static lifecycle, symbol/magic, daily-outcome, and diff checks pass; no full
  compile or tester run occurs.

## Sprint 4: Documentation And Final Compile

**Goal**: Align user guidance, compile the integrated EA once, and repair any
compile defects.

**Files**: `README.md`, `docs/guides/pivot-hft-strategy-inputs.md`, this plan,
plus only implementation files requiring compile fixes.

**Commit**: `Sprint 4: document and validate pivot hft refinements`

### Acceptance Criteria

- Active documentation lists the simplified inputs, immediate-zero behavior,
  formulas, and profitable ladder-consumption rule.
- Optimization guidance has no inactive mode/point dimensions.
- The exact portable MetaEditor compile finishes with zero errors and zero
  warnings; `BUILD.log` is inspected and removed.
- No Strategy Tester run or test infrastructure is added.
- Final status/diff review finds no unrelated changes or generated artifacts.

## Final Compile Command

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /portable /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

## Execution Record

| Sprint | Status | Commit | Validation |
| --- | --- | --- | --- |
| 1 | Complete | `d7980e1` | No obsolete active references; diff and indicator/send ownership reviewed |
| 2 | Complete | `995ac3a` | Immediate/positive trigger branches, init validation, and guard path reviewed |
| 3 | Complete | `643e80a` | Profitable ladder mask, losing retry branch, and finalization scopes reviewed |
| 4 | Complete | This Sprint 4 commit | MetaEditor: `0 errors, 0 warnings` in `9218 ms`; final diff/status review |

## Completion Notes

- MetaEditor was launched with `/portable`, `/compile`, and `/log` through a
  waited hidden process so the current UTF-16 build log could be inspected.
- The integrated EA compiled with `0 errors, 0 warnings`; no compile repair was
  required.
- `BUILD.log` was removed after inspection. No harness, CI module, parser,
  fixture, or Strategy Tester run was added or executed.
- The repository log files available during the audit belonged to older grid
  and Pandora/Fibonacci runs, so the R1/R2 defect decision used the current
  deterministic campaign/finalization code path. The user's new manual tester
  run remains the runtime evidence gate.
