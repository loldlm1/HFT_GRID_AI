# Plan: Phase 0 Foundation Contract

**Generated**: 2026-07-02  
**Estimated Complexity**: Medium  
**Roadmap Phase**: Phase 0  
**Primary Output**: Refoundation contract decisions before implementation  
**Validation Policy**: Documentation review only; no MT5 compile unless code changes are introduced

## Overview

Phase 0 converts `ROADMAP.md` into an agreed implementation contract before touching production code, tests, scripts, or active product documentation. The outcome is a small set of explicit decisions that remove ambiguity for later phases: what is deleted, what is archived, what vocabulary replaces the grid domain, what validation command will be used, and what Phase 1 must update.

This plan intentionally avoids MQL5 code changes, test creation, test harness updates, and CI work. It prepares the repository for the refoundation phases that follow.

## Prerequisites

- `ROADMAP.md` exists and is accepted as the master roadmap.
- Working tree starts from a clean state or only contains this Phase 0 plan.
- No code implementation begins until Phase 0 decisions are recorded.
- MT5 root is expected at `C:\Program Files\MetaTrader 5-1`, but Phase 0 only confirms the compile command shape.

## Non-Goals

- Do not edit `.mq5` or `.mqh` files.
- Do not delete tests, scripts, docs, or add-on files in Phase 0.
- Do not run custom tests or create new tests.
- Do not implement the new execution foundation.
- Do not preserve deprecated behavior through compatibility shims.

## Batch Execution Record

### Sprint 1 Completion: Scope Freeze

**Status**: Completed  
**Validation**: Documentation review only; no MT5 compile required.  
**Commit target**: `docs: define phase 0 refoundation scope`

Confirmed deletion scope:

- Remove input group `Candle Structure Filter`.
- Remove input group `Support Resistance Retest Chain`.
- Remove input group `Structure Trailing Addon`.
- Remove input group `Structure Compound Context`.
- Remove input group `Grid Strategy Settings`.
- Remove input `Structure_Fibonacci_Levels`.
- Remove input `Structure_Trigger_Entry`.
- Remove input `Structure_Touch_Policy`.
- Do not keep deprecated input aliases or compatibility shims for these removed settings.

Confirmed preserved input/control surface for future-strategy foundations:

- License key and account settings remain in scope.
- Protection/risk controls remain in scope, but Phase 5 will simplify strategy range semantics.
- Session time filters remain in scope.
- Strategy timeframe, Stoch Structure period, direction mode, and concurrency mode remain in scope unless a later phase explicitly changes them.
- Developer debug controls remain in scope.
- Stoch Structure remains the structural context source.

Confirmed validation policy:

- Delete legacy custom MQL5 tests and harnesses in Phase 2.
- Do not create new custom tests or agentic CI during this refoundation.
- Validate implementation phases with one MT5 compile gate at phase end.
- Do not compile documentation-only phases.

### Sprint 2 Completion: Documentation Inventory Decisions

**Status**: Completed  
**Validation**: Documentation inventory review only; no MT5 compile required.  
**Commit target**: `docs: classify legacy documentation for refoundation`

Active add-on documentation classification:

| Path | Decision | Phase |
| --- | --- | --- |
| `docs/addons/base.md` | Rewrite for foundation baseline | Phase 1 |
| `docs/addons/README.md` | Rewrite as active docs index | Phase 1 |
| `docs/addons/session-time-filter.md` | Keep and update only if wording references removed flows | Phase 1 |
| `docs/addons/input-migration-2026-02-17.md` | Archive or delete from active docs; default delete if not needed for audit history | Phase 1 |
| `docs/addons/candle-structure-filter.md` | Delete from active docs | Phase 1 |
| `docs/addons/support-resistance-retest-chain.md` | Delete from active docs | Phase 1 |
| `docs/addons/structure-trailing.md` | Delete from active docs | Phase 1 |
| `docs/addons/grid-strategy-settings.md` | Delete from active docs | Phase 1 |
| `docs/addons/compound-trend-ride.md` | Delete from active docs | Phase 1 |
| `docs/addons/compound-pullback-continue.md` | Delete from active docs | Phase 1 |
| `docs/addons/compound-reversal-early.md` | Delete from active docs | Phase 1 |
| `docs/addons/compound-breakout-ready.md` | Delete from active docs | Phase 1 |
| `docs/addons/compound-volatility-trap.md` | Delete from active docs | Phase 1 |

Product-copy documentation classification:

| Path Pattern | Decision | Phase |
| --- | --- | --- |
| `docs/product_copy/README.md` | Rewrite or delete if product copy is no longer maintained in-repo | Phase 1 |
| `docs/product_copy/en/README.md` | Rewrite or delete with parent product-copy decision | Phase 1 |
| `docs/product_copy/es/README.md` | Rewrite or delete with parent product-copy decision | Phase 1 |
| `docs/product_copy/en/base-ea.md` | Rewrite for foundation baseline | Phase 1 |
| `docs/product_copy/es/base-ea.md` | Rewrite for foundation baseline | Phase 1 |
| `docs/product_copy/en/addon-session-time-filter.md` | Keep and update if product-copy docs remain | Phase 1 |
| `docs/product_copy/es/addon-session-time-filter.md` | Keep and update if product-copy docs remain | Phase 1 |
| `docs/product_copy/en/addon-candle-structure-filter.md` | Delete | Phase 1 |
| `docs/product_copy/es/addon-candle-structure-filter.md` | Delete | Phase 1 |
| `docs/product_copy/en/addon-support-resistance-retest-chain.md` | Delete | Phase 1 |
| `docs/product_copy/es/addon-support-resistance-retest-chain.md` | Delete | Phase 1 |
| `docs/product_copy/en/addon-structure-trailing.md` | Delete | Phase 1 |
| `docs/product_copy/es/addon-structure-trailing.md` | Delete | Phase 1 |
| `docs/product_copy/en/addon-grid-strategy-settings.md` | Delete | Phase 1 |
| `docs/product_copy/es/addon-grid-strategy-settings.md` | Delete | Phase 1 |
| `docs/product_copy/en/addon-compound-*.md` | Delete | Phase 1 |
| `docs/product_copy/es/addon-compound-*.md` | Delete | Phase 1 |

Scripts and generated artifacts classification:

| Path | Decision | Phase |
| --- | --- | --- |
| `scripts/run_mql5_tests.sh` | Delete; do not repurpose into compile helper unless a later phase explicitly requests it | Phase 2 |
| `tests/` | Delete all custom test wrappers, harness files, and case includes | Phase 2 |
| `logs/test-runner/` | Delete or ignore with the old harness cleanup | Phase 2 or Phase 8 |
| `logs/compile/` | Keep only if used for phase compile logs | Phase 8 |
| root `.ex5` generated artifacts | Review and clean only in final cleanup | Phase 8 |

Phase 1 should remove active docs for deleted features before code deletion begins, so contributors do not follow stale product behavior while the refoundation is underway.

### Sprint 3 Completion: New Domain Contract

**Status**: Completed  
**Validation**: Documentation review only; no MT5 compile required.  
**Commit target**: `docs: define execution foundation vocabulary`

Confirmed replacement vocabulary:

| Legacy Term | Foundation Term | Decision |
| --- | --- | --- |
| `GridLotTypes` | `LotTypes` | Use generic lot type enum. |
| `GRID_LOT_SIZE` | `LOT_FIXED_SIZE` | Preserve numeric value `0`. |
| `GRID_LOT_PERCENTAGE_BASED` | `LOT_PERCENTAGE_BASED` | Preserve numeric value `1`. |
| `GRID_LOT_CURRENCY_BASED` | `LOT_CURRENCY_BASED` | Preserve numeric value `2`. |
| `GridOrderState` | `ExecutionLegState` | Use for one planned/simulated/real execution unit. |
| `grid_orders` | `execution_legs` | Use for arrays of execution units. |
| grid planner | execution planner | Owns strategy-neutral execution planning. |
| grid lifecycle | execution lifecycle | Owns activation, reconciliation, completion, and cleanup. |
| grid sequence | execution sequence | Use when multiple execution legs belong to one strategy signal. |
| base grid distance | strategy range distance | Use for range-based strategy foundation. |
| grid visualization | execution visualization | Keep only if frontend remains useful after feature removal. |

Naming rules for implementation phases:

- Do not introduce `GRID_` aliases for removed public enum values.
- Do not keep compatibility wrappers for removed input names.
- Preserve enum numeric semantics where user configuration compatibility depends on ordinal values.
- Use `strategy`, `execution`, `range`, `leg`, and `broker snapshot` vocabulary for new foundation code.
- Use `grid` only for historical artifacts scheduled for deletion in the same phase plan.

Execution source-of-truth contract:

- Before a real broker position exists, local execution simulation owns candidate state.
- Local simulation must apply broker conditions before activation decisions: spread, stops level, freeze level, volume min/max/step, margin, market status, sessions, license, and protection gates.
- After a real broker position exists, broker state owns ticket, volume, entry price, close state, and realized profit.
- Local execution state may reconcile against broker facts, but must not overwrite broker facts.
- Future statistics must distinguish simulated decisions from broker-confirmed outcomes.

Safety ownership contract:

| Control | Ownership Rule |
| --- | --- |
| License guard | Must remain fail-closed for live/demo paths. |
| Spread guard | Must be checked before simulated or real activation. |
| Broker stops/freeze | Must be normalized through broker-constraint helpers. |
| Volume min/max/step | Must be normalized before local simulation and order send. |
| Margin guard | Must block local activation and real send when insufficient. |
| Drawdown/protection | Must not be weakened while simplifying risk/range inputs. |
| Session filter | Preserved and applied before strategy execution. |
| Market status | Must block disabled/close-only conditions. |
| Magic number/symbol scope | Must isolate broker reconciliation and lifecycle decisions. |

Any later phase that touches these controls must call out risk level in its phase plan and close with the end-of-phase MT5 compile gate.

## Sprint 1: Scope Freeze

**Goal**: Confirm the exact refoundation scope before implementation.  
**Commit**: `docs: define phase 0 refoundation scope`  
**Demo/Validation**:

- Review the scope checklist against `ROADMAP.md`.
- Confirm all removed inputs/features are named explicitly.
- Confirm no code files changed.

### Task 1.1: Confirm Removed Input Surface

- **Location**: `ROADMAP.md`, `docs/plans/phase-00-foundation-contract-plan.md`
- **Description**: Record the final deletion list for the input surface.
- **Dependencies**: None
- **Acceptance Criteria**:
  - The five removed input groups are listed exactly.
  - The three removed strategy-context inputs are listed exactly.
  - The plan states that no deprecated input aliases will remain.
- **Validation**:
  - Manual doc review only.

Final deletion list:

- `Candle Structure Filter`
- `Support Resistance Retest Chain`
- `Structure Trailing Addon`
- `Structure Compound Context`
- `Grid Strategy Settings`
- `Structure_Fibonacci_Levels`
- `Structure_Trigger_Entry`
- `Structure_Touch_Policy`

### Task 1.2: Confirm Preserved Input Surface

- **Location**: `ROADMAP.md`, `AGENTS.md`, `README.md`
- **Description**: Identify the input groups and controls that later phases must preserve unless explicitly redesigned.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Preserved groups are documented for Phase 1 docs reset.
  - Stoch Structure remains the structural context source.
  - Account, license, protection, session filter, strategy direction/concurrency, and debug controls are treated as future-strategy-compatible unless a later phase explicitly changes them.
- **Validation**:
  - Manual doc review only.

### Task 1.3: Confirm Legacy Test Policy

- **Location**: `ROADMAP.md`, `README.md`, `AGENTS.md`, `docs/plans/`
- **Description**: Record the validation policy for the refoundation.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Custom MQL5 tests and harnesses are out of scope.
  - Existing tests are scheduled for deletion in Phase 2.
  - Validation is MT5 compile only at the end of implementation phases.
  - No compile is required for documentation-only phases.
- **Validation**:
  - Manual doc review only.

## Sprint 2: Documentation Inventory Decisions

**Goal**: Decide how to handle active docs that describe removed features.  
**Commit**: `docs: classify legacy documentation for refoundation`  
**Demo/Validation**:

- Produce a delete/archive/update decision list for docs that mention removed features.
- Do not modify or delete the docs in Phase 0 unless the user explicitly expands scope.

### Task 2.1: Classify Active Add-On Docs

- **Location**: `docs/addons/`
- **Description**: Decide whether each legacy add-on document should be deleted, archived, or rewritten in Phase 1/3.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Removed-feature docs are assigned one of: `delete`, `archive`, `rewrite`, `keep`.
  - `grid-strategy-settings`, `candle-structure-filter`, `support-resistance-retest-chain`, `structure-trailing`, and compound add-on docs are explicitly classified.
- **Validation**:
  - Manual doc inventory only.

### Task 2.2: Classify Product Copy Docs

- **Location**: `docs/product_copy/`
- **Description**: Decide whether translated product copy tied to removed features is deleted or archived.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - English and Spanish product-copy files are classified consistently.
  - Phase 1 has a clear instruction for active product docs.
- **Validation**:
  - Manual doc inventory only.

### Task 2.3: Classify Scripts And Generated Artifacts

- **Location**: `scripts/`, `logs/`, root generated files
- **Description**: Decide which automation remains useful after tests are removed.
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - `scripts/run_mql5_tests.sh` is classified as delete, archive, or repurpose.
  - Compile-only helper needs are recorded for later phases.
  - Generated `.ex5` and log cleanup policy is deferred to Phase 8 unless urgent.
- **Validation**:
  - Manual inventory only.

## Sprint 3: New Domain Contract

**Goal**: Define the vocabulary and ownership boundaries used by later implementation phases.  
**Commit**: `docs: define execution foundation vocabulary`  
**Demo/Validation**:

- Review the vocabulary table and confirm that it avoids legacy grid/Fibonacci coupling.
- Confirm that broker truth and local simulation are separate concepts.

### Task 3.1: Define Replacement Vocabulary

- **Location**: `ROADMAP.md`, future `AGENTS.md`, future architecture docs
- **Description**: Create a vocabulary table for the new foundation.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - `GridLotTypes` replacement name is selected.
  - `GRID_LOT_*` replacement enum values are selected.
  - Execution state names do not imply the removed grid strategy.
  - The vocabulary does not introduce Fibonacci assumptions.
- **Validation**:
  - Manual review against naming rules.

Suggested vocabulary to confirm:

| Legacy Term | Proposed Term |
| --- | --- |
| `GridLotTypes` | `LotTypes` |
| `GRID_LOT_SIZE` | `LOT_FIXED_SIZE` |
| `GRID_LOT_PERCENTAGE_BASED` | `LOT_PERCENTAGE_BASED` |
| `GRID_LOT_CURRENCY_BASED` | `LOT_CURRENCY_BASED` |
| `GridOrderState` | `ExecutionLegState` |
| `grid_orders` | `execution_legs` |
| grid planner | execution planner |
| grid lifecycle | execution lifecycle |
| grid sequence | strategy signal or execution sequence |

### Task 3.2: Define Execution Source Of Truth

- **Location**: future architecture doc, future `AGENTS.md`
- **Description**: Record the lifecycle ownership rule for local and broker state.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Before real execution, local simulation applies broker conditions and owns candidate state.
  - After real execution, broker position state owns ticket, volume, price, close state, and profit.
  - Local state may reconcile with broker facts but cannot overwrite broker facts.
- **Validation**:
  - Manual review against `ROADMAP.md`.

### Task 3.3: Define Safety Control Ownership

- **Location**: future `AGENTS.md`, future architecture docs
- **Description**: Record which safety controls must not be weakened during later phases.
- **Dependencies**: Task 3.2
- **Acceptance Criteria**:
  - License, spread, margin, broker constraints, drawdown/protection, session filters, market status, and magic-number scope remain mandatory.
  - Any phase touching those controls must call out risk level and compile validation.
- **Validation**:
  - Manual review only.

## Sprint 4: Compile Strategy And Phase 1 Readiness

**Goal**: Prepare the next phase without running implementation or compile work in Phase 0.  
**Commit**: `docs: prepare phase 1 docs reset`  
**Demo/Validation**:

- Confirm the compile command shape.
- Confirm Phase 1 inputs and docs targets are known.
- Confirm Phase 0 produces no code changes.

### Task 4.1: Confirm Compile Command Shape

- **Location**: `ROADMAP.md`, future phase plans
- **Description**: Confirm the command template that future implementation phases will run once at phase end.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Portable/headless command is documented.
  - Normal MetaEditor fallback command is documented.
  - Compile log path is documented.
  - Phase 0 does not run compile unless code changes are accidentally introduced.
- **Validation**:
  - Manual command review only.

Preferred command shape:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\phase-build.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

Fallback command shape:

```powershell
& $metaeditor /s /compile:$entrypoint /log:$log
```

### Task 4.2: Produce Phase 1 Intake Notes

- **Location**: `docs/plans/phase-01-docs-reset-plan.md` when created
- **Description**: List the docs that Phase 1 must update or delete.
- **Dependencies**: Sprints 1-3
- **Acceptance Criteria**:
  - `AGENTS.md` reset topics are listed.
  - `README.md` reset topics are listed.
  - Architecture doc need is recorded.
  - Removed feature docs are classified.
- **Validation**:
  - Manual review only.

### Task 4.3: Record Open Decisions

- **Location**: this plan or the final Phase 0 completion notes
- **Description**: Capture remaining decisions that need user approval before Phase 1.
- **Dependencies**: Sprints 1-4
- **Acceptance Criteria**:
  - Any delete-vs-archive ambiguity is listed.
  - Any naming ambiguity is listed.
  - Any compile-command ambiguity is listed.
- **Validation**:
  - Manual review with user.

## Phase 0 Acceptance Criteria

- The deletion scope is explicit and matches `ROADMAP.md`.
- Preserved input groups are named.
- Legacy test policy is explicit: delete tests, no new custom tests, compile-only validation.
- Documentation delete/archive/rewrite decisions are prepared for Phase 1.
- New domain vocabulary is proposed or confirmed.
- Local simulation vs broker source-of-truth rules are documented.
- Compile command strategy is documented but not executed.
- No `.mq5` or `.mqh` files are changed.
- No test, script, or production file is deleted in Phase 0.

## Testing And Validation Strategy

- No MT5 compile is required for Phase 0 if only documentation files change.
- Use `git status --short` to verify the touched files are documentation-only.
- Review changed docs manually against `ROADMAP.md`.
- After Phase 0 implementation is complete, commit documentation changes with:

```text
docs: define refoundation contract
```

## Potential Risks And Gotchas

- Existing docs heavily describe removed add-ons. Phase 0 should classify them, not rewrite everything at once.
- The `GRID_` rename may expose many hidden dependencies. Phase 0 only confirms vocabulary; Phase 4 handles the actual rename.
- Product copy exists in multiple languages. Deleting one language without the other would create drift.
- License add-on docs and shared license code may not have the same ownership. Phase 0 should classify EA-specific docs separately from shared license service docs.
- Portable/headless compile may be blocked by local MT5 profile state. Phase 0 only confirms the fallback strategy.

## Rollback Plan

- If the Phase 0 plan is rejected, delete or revise only this file.
- If vocabulary decisions change, update this plan and `ROADMAP.md` before Phase 1.
- If the validation policy changes, update `ROADMAP.md` first, then regenerate affected phase plans.
