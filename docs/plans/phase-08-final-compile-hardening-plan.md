# Plan: Phase 8 Final Compile Hardening And Cleanup

**Generated**: 2026-07-03
**Estimated Complexity**: Medium
**Roadmap Phase**: Phase 8
**Primary Output**: Refounded EA baseline with stale artifacts/docs cleaned, active docs aligned, production source swept for removed feature drift, and one final MT5 compile gate
**Validation Policy**: Static validation per sprint; one MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback only if needed
**Status**: Completed

## Completion Evidence

- **Completed**: 2026-07-03.
- **Sprint commits**:
  - Sprint 1: `82128b9 chore: clean generated artifact policy`
  - Sprint 2: `b0bce91 docs: align active docs with refounded baseline`
  - Sprint 3: `f668a29 chore: harden refounded source baseline`
  - Sprint 4: `chore: finalize refounded ea baseline`
- **Static validation**: final sweeps confirmed the include pipeline, ignored generated artifacts, no active removed-feature references in production source, no tracked generated/local config artifacts, and no whitespace errors.
- **Compile evidence**: portable/headless MetaEditor compile wrote `logs/compile/phase-08-build.log` with `result 0 errors, 0 warnings, 271 ms elapsed, cpu='X64 Regular'`. The MetaEditor process returned exit code `1`, so the explicit log result is the pass/fail source of truth for this phase.
- **Fallback compile**: not run because portable/headless compile produced valid evidence.
- **Custom tests/CI**: not run and not added.

## Overview

Phase 8 closes the refoundation by making the repository clean, coherent, and ready for future strategy-specific plans.

This phase is intentionally conservative. It should remove stale artifacts and documentation drift, confirm removed feature names are absent from active production surfaces, and run one final MetaEditor compile. It must not introduce strategy behavior, custom MQL5 tests, test harnesses, or CI.

Each sprint must complete validation and commit before the next sprint starts. The MT5 compile gate runs once at the end of Sprint 4 only.

## Current Baseline

- Phase 0 through Phase 7 are complete and committed.
- `HFT_Grid_AI.mq5` compiled after Phase 7 with `0 errors, 0 warnings`.
- `.gitignore` ignores generated `.ex5`, `.log`, `logs/*`, and local editor/runtime artifacts.
- Existing untracked or ignored runtime artifacts may exist locally, including root/indicator `.ex5` files and logs.
- Some tracked docs intentionally preserve historical planning context under `docs/plans/archive/`.
- Active docs still need a final pass for Phase 8 completion notes, product-copy accuracy, and removed feature wording.

## Prerequisites

- Working tree is clean before execution.
- Phase 7 completion evidence is present in `ROADMAP.md` and `docs/plans/phase-07-real-tick-performance-plan.md`.
- No custom MQL5 tests, harnesses, scripts, or CI are added or run.
- Compile is run once after all Phase 8 code/docs cleanup is complete.
- Historical planning artifacts can keep legacy vocabulary when clearly historical.
- Trading safety controls remain unchanged unless a compile or consistency issue requires a narrow fix.

## Files Expected To Change

- `ROADMAP.md`
- `README.md`
- `AGENTS.md` only if final instructions need tightening
- `docs/architecture/execution-foundation.md`
- `docs/plans/phase-08-final-compile-hardening-plan.md`
- `docs/addons/*.md`
- `docs/product_copy/**/*.md`
- `.gitignore` only if artifact policy needs a narrow correction
- Production `.mq5`/`.mqh` files only if final sweeps find stale references, unreachable removed feature code, or compile hardening issues

## Files Expected To Be Deleted

Deletion is conditional and must follow the Sprint 1 inventory.

Expected candidates:

- Stale generated logs or compile artifacts that are tracked accidentally.
- Obsolete root-level generated files if tracked and not part of source baseline.
- Machine-local config files if they are confirmed non-portable and not intentionally tracked.
- Active docs that describe removed features as current behavior and cannot be corrected cleanly.

Do not delete:

- Source `.mq5` or `.mqh` files needed by the EA or included indicators.
- Historical plans under `docs/plans/archive/` solely because they contain legacy vocabulary.
- Shared license service contract docs solely because they mention migration history.
- Local ignored generated files unless the sprint explicitly chooses to clean ignored local artifacts.

## Non-Goals

- Do not design or implement final production strategy rules.
- Do not add custom MQL5 tests, harnesses, scripts, or CI.
- Do not run compile after each sprint.
- Do not remove broker/risk/session/license/magic-number safeguards.
- Do not mass-rename historical planning artifacts.
- Do not delete MT5 platform binaries or files outside the EA repo.
- Do not optimize hot paths beyond narrow cleanup required by final hardening.
- Do not preserve removed feature compatibility through shims or aliases.

## Target Final Baseline Contract

- Active repository docs describe the refounded foundation accurately.
- Removed strategy feature groups and removed public inputs are absent from production surfaces.
- Legacy vocabulary remains only in historical, migration, or explicitly archived context.
- Generated artifacts are either ignored, deleted from tracking, or documented as intentionally retained.
- Include order still follows the functional aggregator pipeline.
- Compile logs for the final phase report `0 errors, 0 warnings`.
- Future strategy work can start from this baseline without first cleaning refoundation residue.

## Sprint 1: Artifact And Repository Hygiene Inventory

**Goal**: Identify generated artifacts, tracked local files, stale logs, and cleanup candidates without deleting source files prematurely.
**Commit**: `chore: clean generated artifact policy`
**Demo/Validation**:
- Artifact inventory is reviewed and only safe cleanup is applied.
- No source files or MT5 platform files are removed accidentally.
- `git diff --check`

### Task 1.1: Inventory Tracked And Ignored Artifacts

- **Location**: repository root, `.gitignore`, `logs/`, `config/`, `indicators/`
- **Description**: Build a concise inventory of tracked artifacts and ignored local runtime files relevant to Phase 8 cleanup.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Tracked `.ex5`, `.log`, `logs/*`, `config/*`, and root artifact files are identified.
  - Ignored local artifacts are identified separately from tracked files.
  - No deletion happens before classification.
- **Validation**:
  ```powershell
  git ls-files | rg "(\.ex5$|\.log$|^logs/|^config/|^\.plan\.md$)"
  rg --files -g "*.ex5" -g "*.log" -g "*.tmp" -g "*.bak" -g "*.old"
  git status --ignored --short
  ```

### Task 1.2: Decide Cleanup Policy Per Artifact Class

- **Location**: `.gitignore`, `ROADMAP.md`, `docs/plans/phase-08-final-compile-hardening-plan.md`
- **Description**: Decide whether each artifact class should be deleted, left ignored locally, kept tracked, or documented as intentionally retained.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Runtime logs remain ignored.
  - Compile logs are not tracked unless intentionally used as phase evidence.
  - Machine-local config files are either justified or scheduled for removal.
  - Indicator/source requirements are not broken.
- **Validation**:
  ```powershell
  git check-ignore -v logs/compile/phase-08-build.log
  git ls-files config logs indicators | Sort-Object
  ```

### Task 1.3: Remove Only Confirmed Obsolete Tracked Artifacts

- **Location**: files identified by Tasks 1.1-1.2
- **Description**: Delete tracked generated artifacts only after they are confirmed obsolete. Leave ignored local runtime files alone unless they interfere with final validation.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - No required source or doc file is removed.
  - Deleted files are limited to confirmed obsolete generated/local artifacts.
  - `.gitignore` still protects future generated files.
- **Validation**:
  ```powershell
  git status --short
  git diff --name-status
  git diff --check
  ```

### Task 1.4: Commit Artifact Cleanup

- **Location**: repository root
- **Description**: Commit Sprint 1 if cleanup or policy docs changed.
- **Dependencies**: Tasks 1.1-1.3.
- **Acceptance Criteria**:
  - Commit exists only if there are tracked changes.
  - Commit message matches the sprint commit.
  - Working tree is clean before Sprint 2.
- **Validation**:
  ```powershell
  git status --short
  git log --oneline -3
  ```

## Sprint 2: Active Documentation Alignment

**Goal**: Make active docs match the refounded codebase and keep historical legacy references scoped.
**Commit**: `docs: align active docs with refounded baseline`
**Demo/Validation**:
- Active docs no longer describe removed features as available.
- Historical docs are clearly historical or archived.
- `git diff --check`

### Task 2.1: Classify Active Versus Historical Docs

- **Location**: `README.md`, `AGENTS.md`, `ROADMAP.md`, `docs/architecture/`, `docs/addons/`, `docs/product_copy/`, `docs/plans/archive/`
- **Description**: Classify which docs are active contributor/product docs and which docs are historical planning artifacts.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Active docs are listed and reviewed.
  - Historical docs are not edited solely to remove old vocabulary.
  - Product-copy docs are treated as active only if the repository still publishes them.
- **Validation**:
  ```powershell
  rg --files docs README.md AGENTS.md ROADMAP.md
  rg "archive|legacy|removed|deprecated" -n docs README.md AGENTS.md ROADMAP.md
  ```

### Task 2.2: Remove Stale Active Feature Claims

- **Location**: active docs from Task 2.1
- **Description**: Update or delete active statements that still describe removed feature groups, removed inputs, old tests, or retired strategy add-ons as current behavior.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Removed features are not advertised as active.
  - Validation policy says compile-only, no custom tests or CI.
  - Lot/range/execution wording matches Phase 4 through Phase 7.
- **Validation**:
  ```powershell
  rg "Candle Structure|Support Resistance|Retest|Trailing Addon|Compound|Grid Strategy|GRID_|run_mql5_tests|TEST_PASS|TEST_FAIL|harness" -n README.md AGENTS.md ROADMAP.md docs
  ```

### Task 2.3: Add Final Baseline Notes

- **Location**: `README.md`, `docs/architecture/execution-foundation.md`, `ROADMAP.md`
- **Description**: Add concise final baseline notes for future strategy integration without turning docs into implementation details.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Future strategy work has clear starting boundaries.
  - Local simulation versus broker truth remains explicit.
  - Performance boundaries from Phase 7 are documented as implemented.
- **Validation**:
  ```powershell
  rg "future strateg|broker-aware|source of truth|performance|compile" -n README.md docs/architecture/execution-foundation.md ROADMAP.md
  ```

### Task 2.4: Commit Documentation Alignment

- **Location**: active docs
- **Description**: Commit Sprint 2 documentation changes.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance Criteria**:
  - Documentation diff is scoped to active docs or intentional archive status notes.
  - Working tree is clean before Sprint 3.
- **Validation**:
  ```powershell
  git diff --check
  git status --short
  ```

## Sprint 3: Production Source And Removed-Feature Sweep

**Goal**: Confirm production source has no removed feature compatibility residue and no compile-hardening issues before the final compile.
**Commit**: `chore: harden refounded source baseline`
**Demo/Validation**:
- Removed feature references are absent from active production surfaces unless intentionally foundation-owned.
- Include pipeline and safety gates remain intact.
- `git diff --check`

### Task 3.1: Sweep Input Surface And Enums

- **Location**: `services/trading_management/ea_inputs.mqh`, `services/core/enums.mqh`, `services/trading_management/addon_runtime_policy.mqh`
- **Description**: Confirm removed public inputs, removed strategy feature groups, and retired enum prefixes are absent from active input and license policy surfaces.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Removed feature group labels do not appear in active input groups.
  - No active `GRID_` lot enum values remain.
  - License/add-on policy does not request removed strategy add-ons.
- **Validation**:
  ```powershell
  rg "input |enum |GROUP_|GRID_|Candle Structure|Support Resistance|Retest|Trailing|Compound|Addon" -n services/trading_management services/core
  ```

### Task 3.2: Sweep Production Source For Legacy Compatibility Paths

- **Location**: `services/`, `HFT_Grid_AI.mq5`, `indicators/`
- **Description**: Search production source for removed feature compatibility shims, aliases, dead includes, old strategy comments, or stale helper names.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Legacy terms in production source are either removed or documented as still foundation-owned.
  - No deleted feature input names remain reachable.
  - No include drift or circular include workaround is introduced.
- **Validation**:
  ```powershell
  rg "#include|input |enum |struct |class |OrderSend|Position|CopyBuffer|iCustom|IndicatorRelease|TesterStop" -n HFT_Grid_AI.mq5 services indicators
  rg "deprecated|legacy|GRID_|Candle Structure|Support Resistance|Retest|Compound|Trailing Addon" -n HFT_Grid_AI.mq5 services indicators
  ```

### Task 3.3: Confirm Safety Gates And Source Of Truth Boundaries

- **Location**: `services/trading_signals/`, `services/trading_management/`, `services/shared/license_guard_v1/`
- **Description**: Verify license, spread, broker constraints, margin, session, protection, magic-number scoping, local simulation, and broker reconciliation remain present after cleanup.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - No safety gate is weakened to simplify cleanup.
  - Broker position facts remain source of truth after real execution.
  - Local simulated decisions still apply broker conditions first.
- **Validation**:
  ```powershell
  rg "License|Max_Spread|BrokerExecution|margin|SessionTime|ProtectionRisk|g_magic_number|Reconcile|PositionSelectByTicket|MarketStatus" -n HFT_Grid_AI.mq5 services
  ```

### Task 3.4: Apply Narrow Compile-Hardening Fixes If Needed

- **Location**: files identified by Tasks 3.1-3.3
- **Description**: Make only the smallest source changes needed to remove stale references or obvious compile-hardening risks before the final compile.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - Changes are narrow and directly tied to sweep findings.
  - No strategy behavior is added.
  - No custom tests or harnesses are introduced.
- **Validation**:
  ```powershell
  git diff --check
  git status --short
  ```

### Task 3.5: Commit Source Hardening

- **Location**: production source
- **Description**: Commit Sprint 3 only if source changes were required.
- **Dependencies**: Task 3.4.
- **Acceptance Criteria**:
  - Commit exists only if production source changed.
  - Working tree is clean before Sprint 4.
- **Validation**:
  ```powershell
  git status --short
  git log --oneline -4
  ```

## Sprint 4: Final Compile Gate And Roadmap Closure

**Goal**: Run the single final compile, record Phase 8 evidence, and mark the refoundation baseline complete.
**Commit**: `chore: finalize refounded ea baseline`
**Demo/Validation**:
- MetaEditor compile reports `0 errors, 0 warnings`.
- Phase 8 status and final baseline evidence are documented.
- `git status --short` is clean after final commit.

### Task 4.1: Final Static Sweep Before Compile

- **Location**: active repository
- **Description**: Run final static checks for removed feature residue, custom test residue, include order, artifact policy, and whitespace.
- **Dependencies**: Sprints 1-3.
- **Acceptance Criteria**:
  - Removed active feature claims are absent.
  - Custom test/harness references remain absent from production validation flow.
  - Include pipeline still follows AGENTS.
  - No whitespace errors.
- **Validation**:
  ```powershell
  rg "run_mql5_tests|TEST_PASS|TEST_FAIL|harness|CI|GitHub Actions" -n README.md AGENTS.md ROADMAP.md docs HFT_Grid_AI.mq5 services
  rg "Candle Structure|Support Resistance|Retest|Grid Strategy|GRID_|Compound" -n HFT_Grid_AI.mq5 services README.md AGENTS.md ROADMAP.md docs
  rg "#include" -n HFT_Grid_AI.mq5 services/*.mqh
  git diff --check
  git status --short
  ```

### Task 4.2: Run Portable/Headless Compile Once

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile the EA once after all Phase 8 cleanup is complete.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Compile reports `0 errors, 0 warnings`.
  - Compile evidence is written to `logs/compile/phase-08-build.log` or, if MetaEditor redirects logging, the alternate evidence path is documented.
  - No custom tests or harnesses are run.
- **Validation**:
  ```powershell
  $mt5Root = "C:\Program Files\MetaTrader 5-1"
  $metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
  $entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
  $logDir = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile"
  $log = Join-Path $logDir "phase-08-build.log"
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  if(Test-Path $log) { Remove-Item -LiteralPath $log -Force }
  $argString = "/portable /s /compile:`"$entrypoint`" /log:`"$log`""
  $proc = Start-Process -FilePath $metaeditor -ArgumentList $argString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.3: Fallback Compile Only If Needed

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run normal MetaEditor compile only if portable compile fails or does not produce usable evidence.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Fallback reason is documented.
  - Fallback result is parsed for warnings/errors.
- **Validation**:
  ```powershell
  $fallbackLog = Join-Path $logDir "phase-08-build-fallback.log"
  $fallbackArgString = "/s /compile:`"$entrypoint`" /log:`"$fallbackLog`""
  $fallbackProc = Start-Process -FilePath $metaeditor -ArgumentList $fallbackArgString -Wait -PassThru -WindowStyle Hidden
  ```

### Task 4.4: Record Final Baseline Evidence

- **Location**: `ROADMAP.md`, `README.md`, `docs/architecture/execution-foundation.md`, `docs/plans/phase-08-final-compile-hardening-plan.md`
- **Description**: Record Phase 8 status, compile command, evidence path, process exit code, result line, and final baseline notes.
- **Dependencies**: Task 4.2 or 4.3.
- **Acceptance Criteria**:
  - Phase 8 is marked completed.
  - Roadmap completion definition is satisfied or updated with explicit residual risks.
  - Future strategy integration notes point to the final baseline.
  - Working tree is clean after final commit.
- **Validation**:
  ```powershell
  rg "Phase 8|final baseline|0 errors|0 warnings|phase-08-build" -n ROADMAP.md README.md docs
  git status --short
  ```

## Phase 8 Acceptance Criteria

- `HFT_Grid_AI.mq5` compiles with `0 errors, 0 warnings`.
- Active docs match the refounded codebase.
- No custom MQL5 tests, harnesses, or CI expectations remain active.
- Removed feature groups and removed public inputs are absent from production surfaces.
- Legacy vocabulary is confined to historical, migration, or archived context.
- Generated artifacts are cleaned, ignored, or intentionally documented.
- Safety controls are still present and not weakened.
- Roadmap is updated with Phase 8 completion notes or final baseline status.
- Working tree is clean after the final commit.

## Validation Strategy

Use static validation per sprint:

```powershell
git status --short
git ls-files | rg "(\.ex5$|\.log$|^logs/|^config/|^\.plan\.md$)"
rg "run_mql5_tests|TEST_PASS|TEST_FAIL|harness" -n README.md AGENTS.md ROADMAP.md docs HFT_Grid_AI.mq5 services
rg "Candle Structure|Support Resistance|Retest|Grid Strategy|GRID_|Compound" -n HFT_Grid_AI.mq5 services README.md AGENTS.md ROADMAP.md docs
rg "License|Max_Spread|BrokerExecution|margin|SessionTime|ProtectionRisk|g_magic_number|Reconcile|MarketStatus" -n HFT_Grid_AI.mq5 services
git diff --check
```

Run the MT5 compile gate once after all Phase 8 cleanup is complete. Do not run custom MQL5 tests.

## Potential Risks And Gotchas

- Some generated `.ex5` files may be ignored local artifacts required only for this workstation's current MT5 runtime. Do not delete local ignored files unless they are confirmed safe to regenerate or irrelevant.
- Tracked `config/*.ini` files may be historical or machine-local. Remove them only after confirming they are not required for portable compile behavior.
- Historical plans and shared license migration docs can legitimately mention legacy terms. Do not churn them unless they are presented as active guidance.
- Product-copy docs may be active externally even if not used by the EA. Update or archive them intentionally instead of silently deleting them.
- MetaEditor can return process exit code `1` even when the compile log reports `0 errors, 0 warnings`; record both and treat the explicit log result as the compile source of truth.
- Final cleanup can accidentally weaken license, spread, margin, session, or broker reconciliation guards if broad refactors are attempted. Keep source changes narrow.
- Removing ignored logs locally is not a meaningful repo cleanup unless they interfere with validation; prefer tracked-state cleanup.

## Rollback Plan

- Revert sprint commits in reverse order.
- If artifact cleanup removes a needed file, restore it from git history or regenerate it with MT5 compile where appropriate.
- If docs cleanup removes needed product context, revert Sprint 2 and reapply a narrower active/historical classification.
- If source hardening causes compile failure, revert Sprint 3 and reapply only the minimal compile fix.
- If final compile fails, do not mark Phase 8 complete; inspect the log, fix the smallest source issue, and rerun the single phase-end compile gate.
