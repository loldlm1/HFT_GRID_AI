# Plan: Phase 2 Remove Test Infrastructure

**Generated**: 2026-07-02  
**Estimated Complexity**: Medium  
**Roadmap Phase**: Phase 2  
**Primary Output**: Legacy custom MQL5 test infrastructure removed; project validates by MT5 compile only  
**Validation Policy**: One MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback
**Status**: Completed

## Overview

Phase 2 removes the legacy custom MQL5 test system. This phase deletes the `tests/` tree, removes `scripts/run_mql5_tests.sh`, updates active docs that still describe test removal as future work, and closes with one MetaEditor compile of `HFT_Grid_AI.mq5`.

This phase must not create replacement tests, CI, harnesses, or validation scripts. The goal is to make MT5 compile the only formal validation path for implementation phases.

## Prerequisites

- Phase 0 and Phase 1 are complete and committed.
- Working tree is clean before execution.
- MT5 root exists at `C:\Program Files\MetaTrader 5-1`.
- `MetaEditor64.exe` exists at `C:\Program Files\MetaTrader 5-1\MetaEditor64.exe`.
- `HFT_Grid_AI.mq5` exists at `C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5`.
- MT5 compile is run only once after all Phase 2 edits are complete.

## Files Expected To Be Deleted

- `tests/`
- `scripts/run_mql5_tests.sh`

This includes generated test `.ex5` files, test wrapper `.mq5` files, `tests/hft_grid_ai_tests_harness.mq5`, `tests/harness/framework.mqh`, and all `tests/harness/cases/*_test_case.mqh` files.

## Files Expected To Change

- `README.md`
- `AGENTS.md`
- `ROADMAP.md`
- `docs/architecture/execution-foundation.md`
- `docs/plans/phase-02-remove-tests-plan.md`

Potentially changed if stale active references remain:

- `docs/addons/README.md`
- `docs/addons/base.md`

## Files Intentionally Not Changed

- `.mq5` and `.mqh` production files.
- `docs/plans/archive/` unless the user explicitly decides historical archived plans should be removed.
- Shared license-service docs under `services/shared/` unless they contain active EA validation instructions.

## Non-Goals

- Do not add a new compile helper script.
- Do not add new tests.
- Do not add CI.
- Do not run the old test runner.
- Do not remove legacy strategy inputs; Phase 3 owns that.
- Do not rename grid-domain code; Phase 4 owns that.
- Do not alter trading behavior.

## Sprint 1: Delete Legacy Test Tree

**Goal**: Remove all custom MQL5 test files and generated test artifacts.  
**Commit**: `chore: remove legacy mql5 tests`  
**Demo/Validation**:

- `tests/` no longer exists.
- No `*_test.mq5` files remain.
- No `tests/harness` files remain.
- Do not compile yet.

### Task 1.1: Delete `tests/`

- **Location**: `tests/`
- **Description**: Delete the complete legacy test tree.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `tests/` is absent from the working tree.
  - No test `.mq5`, `.mqh`, or generated `.ex5` files remain under `tests/`.
  - No production files are modified.
- **Validation**:
  - `Test-Path .\tests` returns `False`.
  - `rg --files -g "*_test.mq5"` returns no results outside historical docs.

### Task 1.2: Confirm Production Includes Do Not Depend On Tests

- **Location**: production `.mq5` and `.mqh` files
- **Description**: Search production files for test harness includes or test-only helpers.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - No production include points to `tests/`.
  - No production code references `hft_grid_ai_tests_harness`.
- **Validation**:
  - `rg "tests/|tests\\|hft_grid_ai_tests_harness|TEST_PASS|TEST_FAIL" -g "*.mq5" -g "*.mqh"`
  - Results must be absent after `tests/` is deleted.

## Sprint 2: Remove Legacy Test Runner

**Goal**: Remove the shell runner that only supported the deleted custom test system.  
**Commit**: `chore: remove legacy mql5 test runner`  
**Demo/Validation**:

- `scripts/run_mql5_tests.sh` no longer exists.
- No active docs instruct use of the old runner.
- Do not compile yet.

### Task 2.1: Delete `scripts/run_mql5_tests.sh`

- **Location**: `scripts/run_mql5_tests.sh`
- **Description**: Delete the old test runner instead of repurposing it into a compile helper.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - File is absent from the working tree.
  - `scripts/` may remain if future scripts exist, but no old runner remains.
- **Validation**:
  - `Test-Path .\scripts\run_mql5_tests.sh` returns `False`.

### Task 2.2: Confirm No Active Runner References

- **Location**: active docs
- **Description**: Search active docs for old runner instructions.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - `README.md`, `AGENTS.md`, and active docs do not instruct users to run `run_mql5_tests.sh`.
  - Remaining mentions in roadmap/phase plans are deletion-history context only.
- **Validation**:
  - `rg "run_mql5_tests|matrix-smoke|TEST_PASS|TEST_FAIL" README.md AGENTS.md ROADMAP.md docs/addons docs/architecture docs/plans/phase-*.md`

## Sprint 3: Update Active Docs For Completed Test Removal

**Goal**: Replace "scheduled for removal" language with completed-state compile-only guidance.  
**Commit**: `docs: mark legacy tests removed`  
**Demo/Validation**:

- Active docs describe compile-only validation as the current model.
- Active docs do not list `tests/` or the old runner as live repository layout.
- Do not compile yet.

### Task 3.1: Update README Repository Layout

- **Location**: `README.md`
- **Description**: Remove `tests/` and `scripts/run_mql5_tests.sh` from live layout and state that legacy test infrastructure was removed in Phase 2.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - README does not list `tests/` as a current active directory.
  - README does not list `scripts/run_mql5_tests.sh` as a current active file.
  - README validation model remains compile-only.
- **Validation**:
  - `rg "tests/|run_mql5_tests|TEST_PASS|TEST_FAIL|matrix-smoke" README.md` returns no active-use instructions.

### Task 3.2: Update AGENTS Validation Policy

- **Location**: `AGENTS.md`
- **Description**: Replace "Phase 2 owns deletion" with current-state guidance that custom tests/harnesses are absent.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - AGENTS says no custom MQL5 tests or runner are part of the repo.
  - AGENTS keeps compile-once-per-implementation-phase guidance.
- **Validation**:
  - `rg "Phase 2 owns|run_mql5_tests|TEST_PASS|TEST_FAIL|matrix-smoke" AGENTS.md` returns no stale active guidance.

### Task 3.3: Update Roadmap Progress

- **Location**: `ROADMAP.md`
- **Description**: Mark Phase 2 as active/completed by the end of execution and link this plan.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - Progress section mentions Phase 2 plan.
  - Phase 2 status is updated during execution.
  - Roadmap still states compile once at phase end.
- **Validation**:
  - Manual review.

### Task 3.4: Update Architecture Boundary Notes

- **Location**: `docs/architecture/execution-foundation.md`
- **Description**: Replace "Phase 2 removes..." future wording with completed-state wording after deletion is done.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - Architecture doc no longer implies legacy tests are still present after Phase 2 is complete.
  - The doc still states compile-only validation direction.
- **Validation**:
  - Manual review.

## Sprint 4: Final Compile Gate

**Goal**: Validate that deleting tests and the old runner did not affect EA compile.  
**Commit**: `docs: complete phase 2 test removal` only if final docs need commit after compile notes are recorded.  
**Demo/Validation**:

- One MT5 compile gate is run after all Phase 2 edits.
- Portable/headless compile is attempted first.
- Normal MetaEditor compile fallback is used only if portable/headless is blocked.
- Compile log is reviewed for warnings/errors.

### Task 4.1: Run Portable/Headless Compile

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile the EA once after all deletions and docs updates.
- **Dependencies**: Sprints 1-3
- **Acceptance Criteria**:
  - Compile command exits successfully or fallback reason is documented.
  - Compile log has no warnings or errors.
  - No custom tests are run.
- **Validation**:
  - Preferred command:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$logDir = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile"
$log = Join-Path $logDir "phase-02-build.log"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

### Task 4.2: Run Normal MetaEditor Fallback If Needed

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Use only if portable/headless compile cannot run because of environment/profile constraints.
- **Dependencies**: Task 4.1 failure caused by environment/profile constraints
- **Acceptance Criteria**:
  - Fallback reason is recorded.
  - Fallback compile log has no warnings or errors.
- **Validation**:

```powershell
& $metaeditor /s /compile:$entrypoint /log:$log
```

### Task 4.3: Record Compile Result

- **Location**: `ROADMAP.md` or this phase plan
- **Description**: Record compile command used, log path, and pass/fail result.
- **Dependencies**: Task 4.1 or Task 4.2
- **Acceptance Criteria**:
  - Compile result is documented.
  - Any fallback use is documented.
  - Working tree is clean after final commit.
- **Validation**:
  - `git status --short`

## Phase 2 Acceptance Criteria

- `tests/` is absent.
- `scripts/run_mql5_tests.sh` is absent.
- No `*_test.mq5` files remain.
- No production `.mq5` or `.mqh` files reference test harnesses.
- Active docs no longer instruct users to run custom tests or the old runner.
- `README.md` and `AGENTS.md` describe compile-only validation as the current model.
- `ROADMAP.md` references Phase 2 progress and this plan.
- One MT5 compile gate is run at phase end.
- Compile log has no warnings or errors.

## Validation Strategy

Use targeted validation during sprints:

```powershell
Test-Path .\tests
Test-Path .\scripts\run_mql5_tests.sh
rg --files -g "*_test.mq5"
rg "tests/|tests\\|hft_grid_ai_tests_harness|TEST_PASS|TEST_FAIL" -g "*.mq5" -g "*.mqh"
rg "run_mql5_tests|matrix-smoke|TEST_PASS|TEST_FAIL" README.md AGENTS.md ROADMAP.md docs/addons docs/architecture docs/plans/phase-*.md
git diff --check
```

Run the MT5 compile gate once after all sprints are complete.

## Historical Docs Policy

`docs/plans/archive/` contains historical planning material that may mention the deleted test harness. Phase 2 does not delete archive history by default. If the project requires zero repository-wide references to old tests, create a separate docs-archive cleanup decision before deleting archived planning records.

## Phase 2 Completion Notes

Completed in Sprint batch.

Deleted:

- `tests/`
- `scripts/run_mql5_tests.sh`

Updated active docs:

- `README.md`
- `AGENTS.md`
- `ROADMAP.md`
- `docs/addons/README.md`
- `docs/architecture/execution-foundation.md`

Compile gate:

- Portable/headless command was executed first with `MetaEditor64.exe /portable /s /compile`.
- Portable process returned ExitCode `1`, but the compile log produced by MetaEditor reports `result 0 errors, 0 warnings`.
- Portable log path: `logs/compile/phase-02-build.log`.
- Normal fallback was attempted because of the non-zero portable process exit code.
- Fallback process returned ExitCode `0`, but fallback log reports missing standard include files under the non-portable AppData profile, starting with `Trade/Trade.mqh` not found. This is an environment/profile issue, not a Phase 2 source-code change.
- Fallback log path: `logs/compile/phase-02-build-fallback.log`.

Phase 2 compile status:

- PASS by portable compile log: `0 errors, 0 warnings`.
- No custom tests were run.

## Potential Risks And Gotchas

- Deleting generated test `.ex5` files is expected; they are part of the legacy test tree.
- The old runner may be referenced by archived plans. Do not treat archived references as active instructions unless the user decides to purge archives.
- Some future phase plans may mention tests as deletion history. That is acceptable if not active guidance.
- Compile logs may be generated under `logs/compile/`; keep or ignore them according to existing gitignore behavior.
- If compile fails after deleting tests, investigate production include leakage first; do not restore the custom test harness unless the user changes the roadmap.

## Rollback Plan

- If production compile fails because production code depended on tests, fix the production dependency instead of restoring the test harness.
- If test deletion is rejected, restore `tests/` and `scripts/run_mql5_tests.sh` from the previous commit.
- If docs need adjustment, revise active docs only; do not resurrect old runner instructions.
