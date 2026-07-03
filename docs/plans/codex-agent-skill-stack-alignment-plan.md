# Plan: Codex Agent Skill Stack Alignment

**Generated**: 2026-07-03
**Estimated Complexity**: Medium
**Primary Output**: `AGENTS.md` and active docs aligned with the local Codex skill stack under `C:\Users\loldlm\.codex\skills`
**Validation Policy**: Documentation/static review only; no MT5 compile unless production `.mq5` or `.mqh` files change
**Status**: Completed

## Completion Evidence

- **Completed**: 2026-07-03.
- **Sprint 1**: AGENTS skill-selection contract validated against the local skill stack and MQL5 safety/compile rules.
- **Sprint 2**: README, architecture, addon, and product-copy docs validated for active/archived planning boundaries without leaking contributor-only workflow.
- **Sprint 3**: the completed multi-phase planning file is absent, only this plan remains active under `docs/plans/`, and Phase 0-8 plans remain archived under `docs/plans/archive/refoundation-baseline-2026-07-03/`.
- **Commit evidence**: structural archive/alignment changes are in commit `7aeca51`; this plan records final execution evidence.
- **MT5 compile**: not run because this sprint batch is docs-only and no `.mq5` or `.mqh` files changed.

## Overview

This plan aligns the repository instructions with the actual Codex skill stack available on this workstation. The goal is to make future agentic engineering sessions start from the right skills, validation rules, and MQL5-specific guardrails without depending on the now-completed refoundation roadmap file.

The active planning source after this cleanup is this plan plus `AGENTS.md`. Completed refoundation Phase 0-8 plans are archived as historical context and should not be treated as active work.

## Current Skill Stack Baseline

Relevant local skills in `C:\Users\loldlm\.codex\skills`:

- `mql5-production-engineering`: primary skill for MQL5 source, MetaEditor compile, trading safety, indicator lifecycle, broker/risk controls, and Strategy Tester performance.
- `token-saver-orchestrator`: use RTK and token-efficient shell practices for noisy git/search/build output.
- `planner`: create sprint-based implementation plans with validation and commit discipline.
- `semantic-audit`: use for repository-wide meaning drift, naming, documentation, and contract consistency audits where needed.
- `devops-release-production-engineering`: use only for deployment/release packaging concerns, not for MQL5 strategy behavior.
- Language/framework production skills (`typescript-production-engineering`, `python-django-production-engineering`, `rails-production-engineering`, `elixir-phoenix-production-engineering`, `flutter-production-engineering`, `postgres-production-engineering`) are secondary and should be used only if matching files or tasks are introduced.

## Prerequisites

- Refoundation Phase 0 through Phase 8 are completed and archived.
- The completed refoundation roadmap file has been removed after Phase 8 completion.
- Working tree is clean before execution.
- No custom MQL5 tests, harnesses, or CI are reintroduced.
- Compile remains phase-end only for implementation changes touching MQL5 source.

## Files Expected To Change

- `AGENTS.md`
- `README.md`
- `docs/architecture/execution-foundation.md`
- `docs/addons/*.md` only if active guidance references old planning model
- `docs/product_copy/**/*.md` only if active guidance references old planning model
- `docs/plans/codex-agent-skill-stack-alignment-plan.md`

## Files Expected To Be Deleted

None expected after this plan is created.

Completed refoundation plans should remain archived. The completed roadmap file should not be recreated unless the project starts a new multi-phase roadmap.

## Non-Goals

- Do not change production MQL5 behavior.
- Do not design final strategy rules.
- Do not add custom tests, harnesses, scripts, or CI.
- Do not compile for docs-only changes.
- Do not edit archived plans except to add archive status metadata if required.
- Do not make every available skill mandatory; use only the skills that match the task.

## Sprint 1: Skill Stack Inventory And Instruction Contract

**Goal**: Define how future Codex agents choose and apply local skills for this MQL5 repository.
**Commit**: `docs: align agent instructions with codex skills`
**Demo/Validation**:
- `AGENTS.md` lists the active skill-selection rules.
- `mql5-production-engineering` and `token-saver-orchestrator` are clearly primary for MQL5 work.
- `planner` rules are scoped to future planning requests.

### Task 1.1: Inventory Local Skills

- **Location**: `C:\Users\loldlm\.codex\skills`, `AGENTS.md`
- **Description**: Confirm the relevant local skills and classify them as primary, situational, or out-of-scope for this repository.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Primary skills for MQL5 work are documented.
  - Situational skills are not presented as always-on requirements.
  - Skill paths are not over-specified in a way that breaks portability.
- **Validation**:
  ```powershell
  Get-ChildItem C:\Users\loldlm\.codex\skills -Directory
  rg "mql5-production-engineering|token-saver-orchestrator|planner|semantic-audit" AGENTS.md
  ```

### Task 1.2: Replace Roadmap-Centric Planning Rules

- **Location**: `AGENTS.md`, `README.md`
- **Description**: Replace references to the completed roadmap file and phase-owned plans with the new post-refoundation planning model.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Active docs no longer point to the completed roadmap file.
  - `docs/plans/` is described as active plan plus archive history.
  - Future large changes must create a new `$planner` plan.
- **Validation**:
  ```powershell
  rg "Current (roadmap|planning model)" AGENTS.md README.md docs/architecture docs/addons docs/product_copy
  ```

### Task 1.3: Preserve MQL5 Safety And Validation Rules

- **Location**: `AGENTS.md`
- **Description**: Keep the MQL5 safety rules from the refounded baseline while aligning wording with the skills stack.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - License, spread, broker constraints, margin, session, protection, magic-number, and broker reconciliation controls remain explicit.
  - Compile policy remains phase-end only.
  - Docs-only changes do not compile.
- **Validation**:
  ```powershell
  rg "License|spread|broker|margin|session|protection|magic|reconciliation|compile" AGENTS.md
  ```

## Sprint 2: Active Documentation Alignment

**Goal**: Make active docs describe the final baseline and skill-driven workflow without reopening the refoundation roadmap.
**Commit**: `docs: update baseline docs for skill-driven workflow`
**Demo/Validation**:
- `README.md` points to active docs and archived plans correctly.
- Architecture docs remain focused on execution foundation, not agent workflow details.
- Product docs do not inherit contributor-only skill guidance.

### Task 2.1: Update Repository Entry Docs

- **Location**: `README.md`
- **Description**: Document the post-refoundation baseline, active plan location, archive location, and validation model.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - `README.md` no longer references the completed roadmap file.
  - Active and archived planning docs are distinguishable.
  - Compile evidence from Phase 8 remains visible.
- **Validation**:
  ```powershell
  rg "docs/plans|archive|phase-08-build|0 errors" README.md
  ```

### Task 2.2: Keep Architecture Docs Strategy-Facing

- **Location**: `docs/architecture/execution-foundation.md`
- **Description**: Ensure architecture docs remain about execution boundaries and do not duplicate full agent workflow rules.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Execution source-of-truth rules remain clear.
  - Future strategy integration boundary remains clear.
  - Skill-stack instructions stay in `AGENTS.md` and README, not architecture internals.
- **Validation**:
  ```powershell
  rg "source of truth|strategy candidate|execution planner|Codex|skill" docs/architecture/execution-foundation.md
  ```

### Task 2.3: Validate Product Docs Are Not Contributor Docs

- **Location**: `docs/addons/`, `docs/product_copy/`
- **Description**: Confirm product-facing docs do not instruct Codex agents or mention internal skill workflow.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Product docs remain user/product focused.
  - No completed-roadmap references remain.
  - No skill-stack rules leak into product copy.
- **Validation**:
  ```powershell
  rg "Codex|skill|planner|agent" docs/addons docs/product_copy
  ```

## Sprint 3: Static Audit And Archive Boundary

**Goal**: Confirm active docs, archived plans, and ignored artifacts have clean boundaries.
**Commit**: `docs: verify plan archive boundaries`
**Demo/Validation**:
- Only the new skill-stack plan remains active under `docs/plans/`.
- Refoundation Phase 0-8 plans are archived.
- The completed roadmap file is absent.

### Task 3.1: Verify Active Plan Set

- **Location**: `docs/plans/`
- **Description**: Confirm active plans are limited to current intended work and historical plans live under `docs/plans/archive/`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `docs/plans/codex-agent-skill-stack-alignment-plan.md` remains active.
  - Phase 0-8 plans live under `docs/plans/archive/refoundation-baseline-2026-07-03/`.
  - No root-level `phase-*.md` plans remain active.
- **Validation**:
  ```powershell
  Get-ChildItem docs\plans -File
  Get-ChildItem docs\plans\archive\refoundation-baseline-2026-07-03 -Filter "phase-*.md"
  ```

### Task 3.2: Final Static Documentation Sweep

- **Location**: active docs
- **Description**: Search for stale roadmap references, custom test guidance, and removed feature claims in active docs.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Active docs have no completed-roadmap references.
  - Active docs still reject custom tests/harnesses/CI.
  - Removed feature claims remain absent.
- **Validation**:
  ```powershell
  rg "run_mql5_tests|TEST_PASS|TEST_FAIL|Candle Structure|Support Resistance|Grid Strategy|GRID_" AGENTS.md README.md docs/architecture docs/addons docs/product_copy
  git diff --check
  git status --short
  ```

### Task 3.3: Commit Archive And Documentation Changes

- **Location**: repository docs
- **Description**: Commit the new active plan, archived Phase 0-8 plans, completed roadmap removal, and active doc adjustments.
- **Dependencies**: Tasks 3.1-3.2.
- **Acceptance Criteria**:
  - Commit is docs-only.
  - Working tree is clean after commit.
  - No MT5 compile is run for this docs-only change.
- **Validation**:
  ```powershell
  git status --short
  git log --oneline -3
  ```

## Testing Strategy

- Use static documentation checks only.
- Use `git diff --check` before commit.
- Do not run MetaEditor compile unless a later execution changes `.mq5` or `.mqh` files.

## Potential Risks And Gotchas

- `docs/plans/archive/*` is ignored by `.gitignore`; the refoundation archive exception must remain in place or moved files will not be tracked.
- Product docs should not become contributor docs. Keep skill guidance in `AGENTS.md` and README.
- Removing the completed roadmap file requires updating every active reference to it first.
- Archived plans can still mention old features, tests, or roadmap phases because they are historical.

## Rollback Plan

- Restore the completed roadmap file from the previous commit if an external process still requires it.
- Move archived Phase 0-8 plans back to `docs/plans/` if the team decides to keep phase plans active.
- Revert this docs commit if skill-stack alignment should be handled in a different repository-wide standard.
