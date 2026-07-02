# HFT Grid AI Refoundation Roadmap

**Generated**: 2026-07-02  
**Status**: Draft for implementation planning  
**Estimated complexity**: High  
**Validation policy**: MT5 compile gate only, once at the end of each implementation phase

## Purpose

Refound HFT Grid AI into a clean MQL5 Expert Advisor foundation for future agentic strategy integration. This roadmap intentionally removes legacy strategy features, legacy tests, grid-specific public naming, and custom test infrastructure so the project can converge on a smaller, deterministic, broker-aware execution core.

This document is the master roadmap. It is not the atomic implementation plan. Each implementation phase must create its own `$planner` plan before code changes begin.

## Operating Rules

- Implement one phase at a time.
- Before implementing a phase, create a phase-specific `$planner` plan under `docs/plans/`.
- Do not create or keep custom MQL5 tests, test harnesses, or agentic CI for this refoundation.
- Do not compile after every atomic task or sprint.
- Compile only once at the end of each implementation phase, unless a phase is documentation-only.
- Use MT5 portable/headless compile first whenever possible.
- If portable/headless compile cannot run because of environment or profile constraints, fall back to normal MetaEditor compile.
- Treat compiler warnings as failures unless a temporary exception is explicitly documented in the active phase plan.
- Do not leave deprecated shims, aliases, or legacy compatibility paths for removed features.
- Preserve trading safety controls: license, spread, broker constraints, margin, drawdown/protection, session filters, magic-number scope, and real broker position reconciliation.

## Target Architecture

The refounded EA should follow this flow:

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

The source of truth is split by lifecycle:

- Before a real trade exists, the EA uses local simulated execution state with broker conditions applied.
- After a real trade exists, the broker position becomes the only source of truth for ticket, volume, entry price, close state, and profit.
- Local state may plan, predict, and reconcile, but must not override known broker facts.

## Scope

In scope:

- Remove legacy tests and harnesses.
- Remove the five legacy feature input groups:
  - `Candle Structure Filter`
  - `Support Resistance Retest Chain`
  - `Structure Trailing Addon`
  - `Structure Compound Context`
  - `Grid Strategy Settings`
- Remove these strategy-context inputs:
  - `Structure_Fibonacci_Levels`
  - `Structure_Trigger_Entry`
  - `Structure_Touch_Policy`
- Keep Stoch Structure as the structural context source.
- Simplify risk management into strategy-range-compatible foundations.
- Remove public and internal `GRID_` domain naming where it represents the removed grid feature model.
- Build a stable mock strategy foundation for later strategy integration.
- Keep non-mentioned input groups working for future strategies.
- Update `AGENTS.md`, `README.md`, and required docs to match the new foundation.
- Optimize hot paths for Strategy Tester runs using real ticks.

Out of scope:

- Designing the final production strategy rules.
- Adding new custom tests or a new test harness.
- Adding CI for MQL5 compile/test execution.
- Preserving removed feature compatibility.
- Keeping deprecated input aliases.

## Validation Gate

Each implementation phase closes with a single compile gate:

1. Portable/headless MetaEditor compile from the detected MT5 root.
2. Normal MetaEditor compile fallback if portable/headless is unavailable or blocked.
3. Parse the compile log for warnings and errors.
4. Record the compile command and log path in the phase completion notes.

Documentation-only phases do not require MT5 compile, but must still include a review checklist.

Expected compile target:

```text
HFT_Grid_AI.mq5
```

Expected root layout:

```text
<MT5_ROOT>/MQL5/Experts/HFT_Grid_AI
```

## Roadmap Phases

### Phase 0: Foundation Contract

**Goal**: Convert this roadmap into an agreed implementation contract before touching code.  
**Planner output**: `docs/plans/phase-00-foundation-contract-plan.md`  
**Compile**: Not required unless code changes are introduced.  
**Suggested commit**: `docs: define refoundation contract`

Deliverables:

- Confirm the final list of removed inputs, features, tests, and docs.
- Decide whether legacy product-copy docs are deleted immediately or archived first.
- Define the new domain vocabulary for strategy, execution, range, lot sizing, and broker reconciliation.
- Confirm the final compile command strategy for this workstation.

Acceptance criteria:

- Roadmap decisions are reflected in the phase plan.
- Ambiguous scope items are either decided or explicitly deferred.
- No code changes are made unless the phase plan says so.

### Phase 1: Contributor And Product Docs Reset

**Goal**: Update project instructions before code movement begins.  
**Planner output**: `docs/plans/phase-01-docs-reset-plan.md`  
**Compile**: Not required for docs-only changes.  
**Suggested commit**: `docs: reset project guidance for refoundation`

Deliverables:

- Rewrite `AGENTS.md` around the new foundation.
- Update `README.md` to remove legacy grid/add-on/test runner guidance.
- Add or update architecture docs for local-and-broker-conditions-first execution.
- Mark this roadmap as active and link phase plans from docs.

Acceptance criteria:

- Docs no longer instruct contributors to use removed tests or removed add-ons.
- Include pipeline and style rules remain clear.
- Validation policy says compile only at the end of a phase.

### Phase 2: Remove Test Infrastructure

**Goal**: Delete legacy custom tests and harnesses so the repository validates by MT5 compile only.  
**Planner output**: `docs/plans/phase-02-remove-tests-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `chore: remove legacy mql5 test harness`

Deliverables:

- Delete `tests/` test wrappers, harness cases, and harness script artifacts that only support custom tests.
- Remove or retire `scripts/run_mql5_tests.sh` if it is only useful for the deleted test system.
- Remove docs that describe the old test workflow.
- Keep compile-related scripts only if they are repurposed as a simple MetaEditor compile gate.

Acceptance criteria:

- No `*_test.mq5` files remain.
- No test harness includes are referenced by production code.
- Docs no longer reference `TEST_PASS`, `TEST_FAIL`, matrix smoke, or custom harness execution.
- `HFT_Grid_AI.mq5` compiles at phase end.

### Phase 3: Remove Legacy Feature Inputs

**Goal**: Remove the five legacy feature groups and three strategy-context inputs from the EA input surface.  
**Planner output**: `docs/plans/phase-03-remove-legacy-inputs-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `refactor: remove legacy strategy input groups`

Deliverables:

- Remove these input groups from `services/trading_management/ea_inputs.mqh`:
  - `Candle Structure Filter`
  - `Support Resistance Retest Chain`
  - `Structure Trailing Addon`
  - `Structure Compound Context`
  - `Grid Strategy Settings`
- Remove:
  - `Structure_Fibonacci_Levels`
  - `Structure_Trigger_Entry`
  - `Structure_Touch_Policy`
- Remove direct code paths that only exist for those inputs.
- Update license add-on mapping so removed features no longer request entitlements.
- Remove product/add-on docs tied only to removed feature groups.

Acceptance criteria:

- Removed inputs no longer appear in MT5 input parameters.
- Removed input names have no production references.
- License policy does not request add-ons for removed features.
- `HFT_Grid_AI.mq5` compiles at phase end.

### Phase 4: Rename The Domain Away From Grid

**Goal**: Replace grid-specific public/internal naming with strategy execution foundation naming.  
**Planner output**: `docs/plans/phase-04-domain-rename-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `refactor: rename grid domain to execution foundation`

Deliverables:

- Replace `GridLotTypes` with a generic lot type enum.
- Replace `GRID_LOT_SIZE`, `GRID_LOT_PERCENTAGE_BASED`, and `GRID_LOT_CURRENCY_BASED` with non-grid enum values while preserving numeric semantics.
- Replace grid-specific lifecycle structs, helpers, logs, comments, and chart object names where the old concept is no longer valid.
- Remove deprecated aliases instead of keeping compatibility wrappers.
- Keep names only where `grid` is part of a file or historical artifact scheduled for deletion in the same phase plan.

Acceptance criteria:

- No `GRID_` enum value remains for the removed strategy model.
- Lot sizing behavior remains compatible under the new enum names.
- Compile errors from rename fallout are resolved in the same phase.
- `HFT_Grid_AI.mq5` compiles at phase end.

### Phase 5: Simplify Strategy Range And Risk Foundation

**Goal**: Create a stable, strategy-neutral risk/range base for future strategies.  
**Planner output**: `docs/plans/phase-05-risk-range-foundation-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `refactor: simplify risk and range foundation`

Deliverables:

- Simplify `Risk Managment Settings` into strategy-range-compatible inputs.
- Keep lot sizing modes working under the new enum names.
- Keep daily signal limits and protection controls only if they remain strategy-neutral.
- Remove old assumptions tied to Fibonacci/grid sequencing.
- Define a mock strategy range model that compiles and gives later strategies a stable contract.

Acceptance criteria:

- Risk/range inputs no longer depend on removed grid/Fibonacci feature semantics.
- Lot sizing still normalizes volume against broker constraints.
- Existing protection behavior is not weakened.
- `HFT_Grid_AI.mq5` compiles at phase end.

### Phase 6: Broker-Aware Local Execution Foundation

**Goal**: Formalize local-and-broker-conditions-first execution before any final strategy work.  
**Planner output**: `docs/plans/phase-06-broker-aware-local-execution-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `feat: add broker-aware local execution foundation`

Deliverables:

- Separate local simulated execution state from real broker position state.
- Apply broker constraints before local activation decisions:
  - spread
  - stops level
  - freeze level
  - volume min/max/step
  - margin availability
  - market status
  - session filters
  - license/protection gates
- Reconcile real broker positions after order execution.
- Ensure broker facts override local assumptions once a position exists.

Acceptance criteria:

- Local execution can decide deterministically without opening real positions.
- Real positions, once present, become source of truth.
- Broker constraints remain centralized and cheap to refresh.
- `HFT_Grid_AI.mq5` compiles at phase end.

### Phase 7: Real-Tick Performance Pass

**Goal**: Reduce hot-path cost for real-tick Strategy Tester optimization.  
**Planner output**: `docs/plans/phase-07-real-tick-performance-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `perf: optimize real tick execution paths`

Deliverables:

- Avoid repeated indicator handle creation on tick paths.
- Avoid full-history scans in tick paths.
- Reduce repeated `SymbolInfo*`, `PositionSelect*`, and array resizing work.
- Gate noisy logging behind debug flags and tester-aware throttles.
- Keep chart/frontend updates from influencing trading decisions.

Acceptance criteria:

- Indicator handles are initialized, reused, and released deterministically.
- Per-tick work is bounded and easy to inspect.
- Logging is quiet by default.
- `HFT_Grid_AI.mq5` compiles at phase end.

### Phase 8: Final Compile Hardening And Cleanup

**Goal**: Make the refounded project clean, coherent, and ready for future strategy plans.  
**Planner output**: `docs/plans/phase-08-final-compile-hardening-plan.md`  
**Compile**: Required once at phase end.  
**Suggested commit**: `chore: finalize refounded ea baseline`

Deliverables:

- Remove obsolete generated artifacts and stale docs.
- Confirm no removed feature names remain in production code or active docs.
- Confirm compile logs are clean.
- Add final notes for future strategy integration plans.

Acceptance criteria:

- `HFT_Grid_AI.mq5` compiles with no warnings or errors.
- Active docs match the refounded codebase.
- No tests/harness/CI expectations remain.
- Roadmap is updated with completion notes or superseded by a release baseline document.

## Planner Plan Rules

Every phase-specific `$planner` plan must include:

- Phase goal.
- Files expected to change.
- Files expected to be deleted.
- Explicit non-goals.
- Phase-level acceptance criteria.
- Single end-of-phase compile command.
- Compile fallback path.
- Expected commit message.
- Risks and rollback notes.

The phase plan should be detailed enough to execute, but it should not create custom tests or CI. Validation must remain compile-first.

## Compile Command Direction

Preferred compile flow:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\phase-build.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

Fallback compile flow:

```powershell
& $metaeditor /s /compile:$entrypoint /log:$log
```

Phase plans may adjust paths if the local MT5 root changes.

## Risks And Mitigations

- **Hidden legacy coupling**: feature inputs are connected to license policy, frontend, logs, tests, and strategy state. Mitigate by deleting by domain and compiling only after each phase is internally coherent.
- **Rename churn**: removing `GRID_` will touch many files. Mitigate with one dedicated rename phase and no behavior expansion during that phase.
- **Compile latency**: MetaEditor compile can be slow. Mitigate by compiling once per phase, not per atomic task.
- **Broker parity gaps**: local simulation can drift from broker execution. Mitigate by making broker reconciliation explicit and one-way once real positions exist.
- **Docs drift**: current docs describe removed tests and add-ons. Mitigate by resetting docs before deeper code phases.
- **Safety regression**: removing legacy behavior must not weaken license, spread, margin, drawdown, session, or market-status guards. Mitigate by keeping safety controls in scope for review in each phase.

## Completion Definition

The refoundation is complete when:

- Removed input groups and removed individual inputs are absent.
- Legacy test infrastructure is absent.
- Active docs no longer describe removed features as available.
- Public lot type enum values no longer use `GRID_`.
- Strategy/risk foundations compile without relying on grid or Fibonacci semantics.
- Local simulated execution and broker reconciliation have separate, explicit ownership.
- Real-tick hot paths are bounded and inspectable.
- Final MetaEditor compile succeeds with no warnings or errors.

