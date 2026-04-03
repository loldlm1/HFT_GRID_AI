# Plan: EURUSD Immediate Close Bug Research

**Generated**: 2026-04-02
**Estimated Complexity**: Medium

## Overview
Investigate a bug where EURUSD opens a position and then closes it almost immediately on the next tick, while XAUUSD and US30 do not show the same behavior under similar workflows. The current evidence comes from [query_debug.txt](/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/query_debug.txt), which already captures EA inputs plus grid lifecycle events.

The strongest current lead is not a session-force-close path. The observed sequence is:
- `LEVEL_REACHED`
- `LEVEL_CLOSE_ALL`
- `GRID_STOP_LEVEL_LIMIT`

That points to the grid controller deciding the active level has already satisfied the stop-limit close condition immediately after entry. The research must determine whether:
- this is intended behavior for the exact `Grid_Level_Stop_Limit=1` semantics in this setup,
- the next-level trigger is becoming true too early on EURUSD only,
- or structure/fibonacci price resolution is producing an invalid next-level state for that day.

The research should stay lean:
- deterministic non-visual backtest first,
- compact action-oriented logs only,
- no large raw tick dumps,
- preserve current production behavior until the root cause is proven.

The logging improvements should be generalized and reusable for future bug investigations. This research should not introduce a one-off EURUSD-only debug mode. The target is a compact debug artifact that remains broadly useful across symbols and scenarios.

## Known Reproduction Context
- Source artifact: `logs/query_debug.txt`
- Failing symbol: `EURUSD`
- Observed failing timestamp: `2024-01-03 14:54:01`
- Same setup reportedly worked on the prior day
- Confirmed bug setup from the log:
  - `Session_NewYork_Filter_Mode=2`
  - `Session_NewYork_Filter_Time_Range=13:30-15:00`
  - `Session_Time_Dst_Mode=1`
  - `Grid_Level_Stop_Limit=1`
  - `Points_Range_Setup=30`
  - `Base_Strategy_Type=2`
  - `Strategy_Direction_Mode=1`

## External References
- MQL5 `OnTick()` is event-driven per new tick, so the immediate-close investigation must be tied to exact tick-to-tick state transitions rather than bar-level assumptions.
- MQL5 `TimeCurrent()` and tester-time behavior should be treated as tester/server-time derived state, not assumed wall-clock progression.
- Targeted `Print` and compact file logging are suitable for deterministic tester debugging; large `CopyTicks()` dumps should be avoided unless the compact instrumentation fails to discriminate causes.

## Prerequisites
- Preserve the current include chain and service ordering from `AGENTS.md`.
- Do not change live behavior while adding research instrumentation.
- Keep `query_debug.txt` compact and action-based.
- Use deterministic non-visual Strategy Tester runs as the primary reproduction method.
- Capture the exact EA input snapshot plus the effective spread context at the top of the debug artifact for every research run.

## Sprint 1: Freeze The Failing Scenario And Research Hypotheses
**Goal**: Lock down the exact scenario, hypotheses, and comparison matrix before adding more instrumentation.
**Demo/Validation**:
- A single research note or plan artifact clearly states the failing timestamp, expected behavior, and ranked hypotheses.
- The comparison matrix covers failing EURUSD day, nearby passing EURUSD day, and control symbols.

### Task 1.1: Normalize The Current Evidence From `query_debug.txt`
- **Location**: `logs/query_debug.txt`, `services/trading_signals/grid_order_logging.mqh`
- **Description**: Extract the exact ordered actions, active inputs, and timestamps from the current debug artifact into a concise research checklist.
- **Dependencies**: None
- **Acceptance Criteria**:
  - The failing sequence is explicitly documented as `LEVEL_REACHED -> LEVEL_CLOSE_ALL -> GRID_STOP_LEVEL_LIMIT`.
  - The active EA inputs relevant to the close path are listed.
  - The research distinguishes between signal gating, forced-close logic, and grid lifecycle logic.
- **Validation**:
  - Manual review against `query_debug.txt`.

### Task 1.2: Rank The Root-Cause Hypotheses
- **Location**: research notes, code references in `services/trading_signals/*.mqh`
- **Description**: Formalize the main hypotheses to test in order:
  - next-level limit predicate becomes true immediately after L1 execution,
  - EURUSD-specific structure/fibonacci resolution yields an unstable or degenerate next-level price,
  - point-size / broker-distance behavior changes the trigger outcome on EURUSD only,
  - session or protection logic is a false lead and should be deprioritized unless contradicted by new logs.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Hypotheses are ordered by likelihood and tied to exact code locations.
  - The plan explicitly notes that no `Session filter close:` reason is present in the current log.
- **Validation**:
  - Manual review.

### Task 1.3: Define The Reproduction Matrix
- **Location**: test checklist, Strategy Tester presets if needed
- **Description**: Define the minimal deterministic matrix:
  - EURUSD failing day (`2024-01-03`)
  - EURUSD previous passing day (`2024-01-02`, or exact known passing date)
  - XAUUSD control run
  - US30 control run
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - The matrix uses the exact same EA inputs unless a comparison requires a single-variable change.
  - The matrix explicitly records whether each run is visual or non-visual.
- **Validation**:
  - Research checklist review.

## Sprint 2: Add Compact Lifecycle Instrumentation
**Goal**: Make the close path explain itself precisely without flooding logs.
**Demo/Validation**:
- `query_debug.txt` shows why the controller considered the next level eligible and why the stop-limit close path executed.
- The logs remain compact enough to inspect manually.

### Task 2.1: Instrument The Next-Level Trigger Decision
- **Location**: `services/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Add targeted, reusable debug output around `GridShouldActivateNextLevelLimit(...)` so the log captures:
  - current price used for evaluation,
  - `next_level_price`,
  - `entry_reference_price`,
  - direction,
  - whether the next-level trigger condition evaluated true,
  - the exact trigger branch taken.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Logging is emitted only when debug/file logging is enabled.
  - The log line is compact and single-purpose.
  - The instrumentation does not dump every tick indiscriminately; it only logs around candidate activation transitions.
  - The instrumentation is generic enough to help future lifecycle bugs, not hardcoded to this EURUSD case.
- **Validation**:
  - Reproduction run produces a compact next-level diagnostic line near the failing timestamp.

### Task 2.2: Instrument The Stop-Limit Close Predicate
- **Location**: `services/trading_signals/grid_order_controller.mqh`, `services/trading_signals/grid_order_helpers.mqh`
- **Description**: Add explicit debug lines for:
  - `active_level_index`
  - display level
  - `Grid_Level_Stop_Limit`
  - `ShouldBlockNextLevelByStopLimit(...)` result
  - whether the controller chose `GridCloseAllLevels(...)` or `BuildGridOrderForSignal(...)`
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - The log can prove whether the immediate close is caused by intended stop-limit semantics or by an unexpected early next-level trigger.
  - The instrumentation is action-oriented and does not create noisy per-tick traces.
  - The emitted fields are generic lifecycle diagnostics usable beyond this single bug.
- **Validation**:
  - `query_debug.txt` or equivalent debug log shows the stop-limit decision alongside the close event.

### Task 2.3: Instrument Fibonacci / Structure Price Resolution For The Active Level
- **Location**: `services/trading_signals/grid_order_helpers.mqh`
- **Description**: Add compact diagnostics around the structure-derived grid pricing path, including:
  - resolved peak price
  - resolved bottom price
  - `current_is_bottom`
  - computed fibonacci entry/next-level prices
  - fallback branch usage if structure resolution fails
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - The log makes it obvious whether EURUSD on the failing day resolved a suspicious next-level price.
  - The instrumentation is emitted only for active signal construction / activation paths, not every general helper call.
  - The instrumentation remains generic and readable for future structure/fibonacci investigations.
- **Validation**:
  - Failing run produces a concise structure-resolution trace near the problem moment.

### Task 2.4: Ensure The Input Snapshot Remains In The Debug Artifact
- **Location**: current debug logging path that writes `logs/query_debug.txt`
- **Description**: Verify and, if needed, tighten the startup snapshot so every research run writes the relevant EA inputs plus effective spread context before the lifecycle trace begins. Keep the header generic and compact rather than adding large tester-environment dumps.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `query_debug.txt` begins with the runtime-relevant inputs for the run.
  - Session/DST, grid limit, and range inputs are included.
  - Spread context is included.
  - The header stays easy to read and broadly useful across future bug investigations.
- **Validation**:
  - Manual review of a fresh research run artifact.

## Sprint 3: Deterministic Non-Visual Reproduction And Comparative Analysis
**Goal**: Reproduce the failure deterministically and compare failing vs passing scenarios with the new compact instrumentation.
**Demo/Validation**:
- The bug is reproduced non-visually on EURUSD with the same close sequence.
- A nearby passing EURUSD day and control symbols provide contrast without changing the setup.

### Task 3.1: Create A Minimal Repro Procedure For The Failing EURUSD Day
- **Location**: reproducible tester notes, optional preset/config artifact
- **Description**: Define and save the exact non-visual tester procedure for the failing scenario, including symbol, timeframe, date, spread model, and relevant inputs.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Another contributor can rerun the same scenario and produce the same debug artifact.
  - The procedure references the exact failing timestamp `2024-01-03 14:54:01`.
- **Validation**:
  - One non-visual rerun reproduces the failing close sequence.

### Task 3.2: Compare Against The Previous Passing EURUSD Day
- **Location**: debug artifact comparison notes
- **Description**: Run the same setup on the nearest known-good EURUSD day before the failure and compare:
  - structure range
  - next-level price
  - stop-limit predicate
  - event ordering
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - The comparison identifies the first meaningful divergence between passing and failing days.
  - The result distinguishes data-driven divergence from code-path divergence.
- **Validation**:
  - Side-by-side compact log comparison.

### Task 3.3: Run Symbol Controls On XAUUSD And US30
- **Location**: debug artifact comparison notes
- **Description**: Re-run the same research instrumentation on control symbols to confirm whether the divergence is:
  - symbol-point-size related,
  - structure-resolution related,
  - or specific to EURUSD data shape on that day.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Control runs are performed with the same instrumentation and a documented setup delta only where symbol properties force it.
  - The analysis calls out which values differ materially.
- **Validation**:
  - Compact comparison table or notes from the produced logs.

## Sprint 4: Convert The Research Into A Failing Test And Fix Direction
**Goal**: Translate the confirmed root cause into a stable regression target and a bounded implementation proposal.
**Demo/Validation**:
- A failing test case or deterministic harness scenario captures the bug semantics.
- The research ends with a concrete fix direction, not only observations.

### Task 4.1: Decide Whether The Behavior Is Semantic Or Defective
- **Location**: `services/trading_signals/grid_order_controller.mqh`, `services/trading_signals/grid_order_helpers.mqh`
- **Description**: Based on the new evidence, decide whether:
  - `Grid_Level_Stop_Limit=1` is behaving exactly as designed and user expectations need correction,
  - or the next-level trigger / structure price resolution is prematurely arming the close path.
- **Dependencies**: Sprint 3
- **Acceptance Criteria**:
  - The conclusion is tied to specific log evidence and code branches.
  - Ambiguity between “expected semantics” and “bug” is removed.
- **Validation**:
  - Reviewable conclusion note.

### Task 4.2: Add Or Extend A Deterministic Test Case
- **Location**: likely one or more of:
  - `tests/harness/cases/grid_order_lifecycle_level_stop_limit_test_case.mqh`
  - `tests/harness/cases/structure_entry_trigger_test_case.mqh`
  - `tests/harness/cases/structure_fibonacci_entry_levels_test_case.mqh`
- **Description**: Convert the confirmed failing behavior into a deterministic test that reproduces the wrong next-level/close decision without requiring a full market replay.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - The test isolates the failing decision branch.
  - The test name and assertions describe the bug in domain terms.
  - The test fails before the fix and passes after the fix.
- **Validation**:
  - Harness compile and runtime.

### Task 4.3: Draft The Bounded Fix Proposal
- **Location**: fix note or follow-up plan
- **Description**: Produce a short implementation proposal based on the confirmed cause, such as:
  - tighten `GridShouldActivateNextLevelLimit(...)` semantics,
  - prevent stop-limit close when no valid deeper level price exists,
  - or correct structure/fibonacci next-level price resolution on EURUSD-like ranges.
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - The proposed fix is minimal and tied to the failing test.
  - The proposal includes regression risk notes for XAUUSD and US30.
- **Validation**:
  - Review against research evidence.

## Testing Strategy
- Start with deterministic non-visual tester reruns of the exact failing timestamp.
- Keep logs compact and event-driven:
  - input snapshot plus spread at startup
  - signal init
  - level activation
  - next-level trigger decision
  - stop-limit decision
  - final close reason
- Avoid full tick dumps unless compact instrumentation cannot separate the hypotheses.
- Compare failing EURUSD day against:
  - the previous passing EURUSD day
  - XAUUSD
  - US30
- Convert the final root cause into a harness regression test instead of relying only on log inspection.

## Potential Risks & Gotchas
- The current `query_debug.txt` shows action order but not the internal boolean decisions that led to `GRID_STOP_LEVEL_LIMIT`; without targeted instrumentation the root cause may remain ambiguous.
- `Grid_Level_Stop_Limit=1` may be semantically correct in code but mismatched to trading expectations. The research must separate “wrong behavior” from “wrong configuration meaning.”
- EURUSD may expose a point-size or broker-distance edge that control symbols mask. Symbol controls are necessary, but they are not enough without a nearby passing EURUSD comparison.
- Structure/fibonacci helpers are used in multiple places. Instrumentation should avoid broad helper spam and focus on the active signal path only.
- Strategy Tester runs can be data-sensitive across dates; the plan must preserve the exact date window and input snapshot for every research run.

## Rollback Plan
- Remove any temporary research-only logging once the root cause is confirmed and covered by a regression test.
- Keep any improved input snapshot logging if it remains compact and broadly useful.
- Revert any instrumentation that increases log volume without materially improving diagnosis.
- If a deterministic tester helper or preset is added only for the research phase, archive it or remove it after the fix is merged and covered by tests.
