# Plan: Phase 1 Docs Reset

**Generated**: 2026-07-02  
**Estimated Complexity**: Medium  
**Roadmap Phase**: Phase 1  
**Primary Output**: Active contributor, product, and architecture docs aligned with the refoundation  
**Validation Policy**: Documentation review only; no MT5 compile unless this phase is expanded to code changes

## Overview

Phase 1 resets active repository documentation before code movement begins. The goal is to stop the project from instructing contributors to use removed features, removed add-ons, custom MQL5 tests, or legacy grid-specific semantics while later phases refound the EA.

This phase is intentionally documentation-only. It may delete or rewrite markdown docs, but it must not edit `.mq5` or `.mqh` files, remove test infrastructure, modify scripts, or run MT5 compile. If implementation scope expands beyond docs, stop and create a revised phase plan before continuing.

## Prerequisites

- `ROADMAP.md` exists and has been committed.
- `docs/plans/phase-00-foundation-contract-plan.md` exists and has been committed.
- Working tree is clean before Phase 1 execution begins.
- Product-copy policy is decided at the start of Sprint 2:
  - Recommended default: keep only foundation-relevant base/session copy if product copy is still useful in-repo.
  - If product copy is no longer maintained in-repo, delete `docs/product_copy/` during Sprint 2 instead of rewriting it.

## Files Expected To Change

- `AGENTS.md`
- `README.md`
- `ROADMAP.md`
- `docs/addons/base.md`
- `docs/addons/README.md`
- `docs/addons/session-time-filter.md`
- `docs/plans/phase-01-docs-reset-plan.md`

## Files Expected To Be Added

- `docs/architecture/execution-foundation.md`

## Files Expected To Be Deleted Or Removed From Active Docs

- `docs/addons/candle-structure-filter.md`
- `docs/addons/support-resistance-retest-chain.md`
- `docs/addons/structure-trailing.md`
- `docs/addons/grid-strategy-settings.md`
- `docs/addons/compound-trend-ride.md`
- `docs/addons/compound-pullback-continue.md`
- `docs/addons/compound-reversal-early.md`
- `docs/addons/compound-breakout-ready.md`
- `docs/addons/compound-volatility-trap.md`
- `docs/addons/input-migration-2026-02-17.md` unless explicitly kept for audit history
- `docs/product_copy/en/addon-candle-structure-filter.md`
- `docs/product_copy/es/addon-candle-structure-filter.md`
- `docs/product_copy/en/addon-support-resistance-retest-chain.md`
- `docs/product_copy/es/addon-support-resistance-retest-chain.md`
- `docs/product_copy/en/addon-structure-trailing.md`
- `docs/product_copy/es/addon-structure-trailing.md`
- `docs/product_copy/en/addon-grid-strategy-settings.md`
- `docs/product_copy/es/addon-grid-strategy-settings.md`
- `docs/product_copy/en/addon-compound-*.md`
- `docs/product_copy/es/addon-compound-*.md`

## Non-Goals

- Do not edit MQL5 source files.
- Do not delete `tests/` or `scripts/run_mql5_tests.sh`; Phase 2 owns test infrastructure removal.
- Do not run MT5 compile for this docs-only phase.
- Do not create custom tests, CI, or validation scripts.
- Do not preserve removed feature docs as active documentation.
- Do not introduce deprecated aliases or migration promises that conflict with the roadmap.

## Sprint 1: Contributor Guidance Reset

**Goal**: Rewrite contributor-facing rules so future work follows the refoundation contract.  
**Commit**: `docs: reset contributor guidance for refoundation`  
**Demo/Validation**:

- `AGENTS.md` no longer describes the current project as a grid EA.
- `AGENTS.md` no longer instructs contributors to use custom MQL5 tests.
- Include pipeline and coding style remain explicit.
- No `.mq5` or `.mqh` files changed.

### Task 1.1: Rewrite Purpose And Entrypoint Guidance

- **Location**: `AGENTS.md`
- **Description**: Update the project purpose from grid EA to a refounded strategy/execution foundation while preserving `HFT_Grid_AI.mq5` as the entrypoint.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Purpose mentions future strategy integration and broker-aware execution.
  - Entrypoint remains `HFT_Grid_AI.mq5`.
  - Removed feature groups are not described as active behavior.
- **Validation**:
  - Manual review of `AGENTS.md`.

### Task 1.2: Update Include Pipeline Rules

- **Location**: `AGENTS.md`
- **Description**: Keep the ordered include chain but update the lifecycle wording to match the new foundation.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Existing include order remains visible.
  - Rules still prohibit sibling include drift.
  - Data flow uses strategy/execution/risk/frontend vocabulary, not grid-specific flow.
- **Validation**:
  - Manual review against `ROADMAP.md`.

### Task 1.3: Replace Test Automation Rules

- **Location**: `AGENTS.md`
- **Description**: Remove the old `*_test.mq5` runner instructions and replace them with compile-only phase validation.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - No `run_mql5_tests.sh`, `TEST_PASS`, `TEST_FAIL`, matrix smoke, or harness guidance remains as active instruction.
  - Docs say implementation phases compile once at phase end.
  - Docs say docs-only phases do not compile.
- **Validation**:
  - Search `AGENTS.md` for stale test-runner terms.

### Task 1.4: Add Safety And Naming Rules

- **Location**: `AGENTS.md`
- **Description**: Add concise rules for no deprecated shims, no public `GRID_` domain, local/broker source of truth, and non-weakened safety controls.
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - `GRID_` is documented as legacy naming to remove, not an active naming target.
  - Local simulation vs broker truth rules are summarized.
  - License, spread, margin, broker constraints, drawdown/protection, session, market status, magic-number, and symbol scoping remain protected.
- **Validation**:
  - Manual review against Phase 0 safety ownership contract.

## Sprint 2: Product And Add-On Docs Reset

**Goal**: Remove active docs for deleted features and rewrite remaining product docs around the foundation.  
**Commit**: `docs: reset active product docs`  
**Demo/Validation**:

- Active docs no longer advertise removed add-ons/features.
- Product-copy handling is consistent across English and Spanish.
- No code, tests, or scripts changed.

### Task 2.1: Rewrite Active Add-On Index

- **Location**: `docs/addons/README.md`
- **Description**: Replace the old add-on index with a foundation docs index.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Removed feature docs are not linked.
  - Remaining docs point to foundation baseline and session filter if retained.
  - The index clearly states the refoundation is compile-validated, not test-harness validated.
- **Validation**:
  - Manual link/path review.

### Task 2.2: Rewrite Foundation Baseline Doc

- **Location**: `docs/addons/base.md`
- **Description**: Rewrite base EA documentation around the new foundation contract.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Describes the EA as a strategy/execution foundation.
  - Lists preserved controls at a high level.
  - Does not mention removed grid/Fibonacci/add-on feature behavior as active.
- **Validation**:
  - Search for removed feature terms in `docs/addons/base.md`.

### Task 2.3: Review Session Filter Doc

- **Location**: `docs/addons/session-time-filter.md`
- **Description**: Keep the session filter doc if it remains strategy-neutral, but remove stale references to removed flows.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Session filter remains documented as preserved strategy-neutral behavior.
  - No removed feature or test-runner instructions remain.
- **Validation**:
  - Manual review and targeted search.

### Task 2.4: Delete Removed Feature Add-On Docs

- **Location**: `docs/addons/`
- **Description**: Delete active docs for removed feature groups and compound add-ons.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Deleted files match the Phase 0 classification.
  - `docs/addons/input-migration-2026-02-17.md` is deleted unless an explicit audit exception is recorded.
  - `docs/addons/README.md` has no dead links.
- **Validation**:
  - `Get-ChildItem docs/addons`
  - Search active docs for deleted filenames.

### Task 2.5: Reset Or Delete Product Copy

- **Location**: `docs/product_copy/`
- **Description**: Apply the chosen product-copy policy.
- **Dependencies**: Task 2.4
- **Acceptance Criteria**:
  - If product copy remains active, base/session copy is rewritten in both English and Spanish and removed-feature copy is deleted.
  - If product copy is not maintained in-repo, the full `docs/product_copy/` tree is deleted.
  - English and Spanish handling is consistent.
- **Validation**:
  - `Get-ChildItem -Recurse docs/product_copy` if retained.
  - Search active docs for deleted feature terms.

## Sprint 3: Architecture Foundation Doc

**Goal**: Add a concise architecture doc that captures the execution foundation and source-of-truth rules.  
**Commit**: `docs: add execution foundation architecture`  
**Demo/Validation**:

- `docs/architecture/execution-foundation.md` exists.
- The doc is implementation-guiding but not over-specific.
- It does not describe final strategy rules.

### Task 3.1: Create Architecture Directory And Doc

- **Location**: `docs/architecture/execution-foundation.md`
- **Description**: Create a foundation architecture document for future phases.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - Document contains the target lifecycle flow.
  - Document defines local simulated execution ownership.
  - Document defines broker position source of truth.
  - Document defines protected safety controls.
- **Validation**:
  - Manual review against `ROADMAP.md` and Phase 0 plan.

### Task 3.2: Define Documentation Boundaries

- **Location**: `docs/architecture/execution-foundation.md`
- **Description**: State what belongs in docs now versus future implementation phases.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Final strategy rules are explicitly out of scope.
  - Phase 2 owns tests removal.
  - Phase 3+ own code and input deletion.
  - Phase 6 owns actual local/broker execution implementation.
- **Validation**:
  - Manual review only.

### Task 3.3: Add Performance Guidance

- **Location**: `docs/architecture/execution-foundation.md`
- **Description**: Add real-tick performance principles that future implementation phases must preserve.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Mentions bounded tick work.
  - Mentions indicator handle reuse.
  - Mentions no full-history scans on tick paths.
  - Mentions gated logging.
- **Validation**:
  - Manual review only.

## Sprint 4: Roadmap And README Alignment

**Goal**: Make the active project docs point to the new roadmap, phase plan, and validation model.  
**Commit**: `docs: align roadmap and readme for phase 1`  
**Demo/Validation**:

- `README.md` describes the current refoundation state.
- `ROADMAP.md` marks Phase 1 as planned/active or references the Phase 1 plan.
- Active docs no longer tell contributors to run the old custom test system.

### Task 4.1: Rewrite README

- **Location**: `README.md`
- **Description**: Replace legacy product/test/add-on content with concise refoundation guidance.
- **Dependencies**: Sprints 1-3
- **Acceptance Criteria**:
  - Quick start says compile with MetaEditor/MT5, not run custom tests.
  - Removed feature docs are not advertised.
  - Links point to `ROADMAP.md`, Phase 0 plan, Phase 1 plan, and architecture doc.
  - The old lot/TP model section is removed or clearly marked obsolete only if needed for transition notes.
- **Validation**:
  - Search `README.md` for stale terms: `TEST_PASS`, `TEST_FAIL`, `run_mql5_tests`, removed add-on names.

### Task 4.2: Mark Roadmap Progress

- **Location**: `ROADMAP.md`
- **Description**: Update roadmap status so Phase 0 is complete and Phase 1 has an implementation plan.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Phase 0 completion is noted.
  - Phase 1 plan path is linked or named.
  - Roadmap still says compile once at implementation phase end.
- **Validation**:
  - Manual review.

### Task 4.3: Final Stale Reference Sweep

- **Location**: Active markdown docs
- **Description**: Search active docs for stale removed-feature/test-runner references and either remove or classify them.
- **Dependencies**: Tasks 4.1-4.2
- **Acceptance Criteria**:
  - No active docs instruct use of deleted feature groups.
  - No active docs instruct use of custom MQL5 tests as the current validation path.
  - References to old terms only appear in roadmap/phase plans as deletion targets or historical context.
- **Validation**:
  - Use `rg` over `*.md` for removed feature names, `run_mql5_tests`, `TEST_PASS`, `TEST_FAIL`, and public `GRID_` naming.

## Phase 1 Acceptance Criteria

- `AGENTS.md` reflects the refounded project contract.
- `README.md` no longer describes removed features as active.
- Active add-on/product docs are deleted or rewritten according to Phase 0 classification.
- `docs/architecture/execution-foundation.md` exists and captures local/broker source-of-truth rules.
- `ROADMAP.md` references Phase 1 progress and the Phase 1 plan.
- No `.mq5` or `.mqh` files are changed.
- No `tests/` or `scripts/run_mql5_tests.sh` files are deleted in this phase.
- No MT5 compile is run because Phase 1 is documentation-only.

## Validation Strategy

Documentation-only validation:

```powershell
git status --short
git diff --check
rg "run_mql5_tests|TEST_PASS|TEST_FAIL|Candle Structure Filter|Support Resistance Retest Chain|Structure Trailing Addon|Structure Compound Context|Grid Strategy Settings|Structure_Fibonacci_Levels|Structure_Trigger_Entry|Structure_Touch_Policy" -g "*.md"
```

Expected validation result:

- `git diff --check` has no whitespace errors.
- `rg` results are either absent from active docs or appear only in roadmap/phase-plan deletion context.
- No MT5 compile command is run.

If a code file changes accidentally, stop, revert only the accidental Phase 1 code change, and keep Phase 1 documentation-only.

## End-Of-Phase Commit

If Sprint commits are batched instead of committed separately, use:

```text
docs: reset project guidance for refoundation
```

If Sprint commits are kept separate, use the commit messages listed under each Sprint.

## Potential Risks And Gotchas

- Deleting active docs before updating indexes can leave broken links; update indexes in the same Sprint.
- Product copy exists in English and Spanish; handle both consistently.
- Some removed feature names may remain in roadmap/phase plans as intentional historical context. Do not treat those as active-doc failures.
- Shared license documentation under `services/shared/` may mention add-ons for broader service behavior. Do not edit shared-service docs in Phase 1 unless they are clearly EA-active docs.
- `AGENTS.md` currently contains test automation guidance. Removing it too late can mislead later implementation work.
- Documentation-only scope is easy to accidentally expand into scripts/tests cleanup. Leave `tests/` and `scripts/` for Phase 2.

## Rollback Plan

- Restore deleted markdown files from git if the product documentation policy changes.
- Revert only Phase 1 documentation commits if the docs reset direction is rejected.
- If code or script files are touched accidentally, revert those files immediately and continue docs-only work.
- If product-copy maintenance remains undecided, pause Sprint 2 before deleting or rewriting `docs/product_copy/`.

