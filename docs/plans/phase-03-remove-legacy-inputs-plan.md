# Plan: Phase 3 Remove Legacy Feature Inputs

**Generated**: 2026-07-02  
**Estimated Complexity**: High  
**Roadmap Phase**: Phase 3  
**Primary Output**: Legacy feature input groups and dependent code paths removed from the EA  
**Validation Policy**: One MT5 compile gate at phase end, portable/headless first and normal MetaEditor fallback only if needed

## Overview

Phase 3 removes the legacy feature input surface and the code paths that exist only to support those inputs. This is the first implementation phase after the documentation and test-infrastructure cleanup, so it must be careful about include order, license add-on mapping, logging, frontend references, and production compile health.

This phase removes the five legacy input groups and three individual strategy-context inputs named in `ROADMAP.md`. It must not rename the whole grid domain; Phase 4 owns the broader domain rename away from `GRID_`. It also must not redesign risk/range semantics; Phase 5 owns that.

## Prerequisites

- Phase 0, Phase 1, and Phase 2 are complete and committed.
- Working tree is clean before execution.
- `tests/` and `scripts/run_mql5_tests.sh` are absent.
- MT5 root exists at `C:\Program Files\MetaTrader 5-1`.
- Phase 3 runs no custom tests.
- MT5 compile is run only once after all code and docs edits are complete.

## Inputs And Feature Groups To Remove

Remove these input groups from `services/trading_management/ea_inputs.mqh`:

- `Candle Structure Filter`
- `Support Resistance Retest Chain`
- `Structure Trailing Addon`
- `Structure Compound Context`
- `Grid Strategy Settings`

Remove these individual inputs from `Strategy Context`:

- `Structure_Fibonacci_Levels`
- `Structure_Trigger_Entry`
- `Structure_Touch_Policy`

## Files Expected To Change

- `services/trading_management/ea_inputs.mqh`
- `services/trading_management.mqh`
- `services/trading_management/addon_runtime_policy.mqh`
- `services/trading_management/indicator_definitions_loader.mqh`
- `services/trading_management/strategy_structure_context.mqh`
- `services/trading_signals.mqh`
- `services/trading_signals/market_signal_filters.mqh`
- `services/trading_signals/market_signal_detection.mqh`
- `services/trading_signals/grid_order_controller.mqh`
- `services/trading_signals/grid_order_helpers.mqh`
- `services/trading_signals/grid_order_logging.mqh`
- `services/trading_signals/grid_planner.mqh`
- `services/frontend/grid_visualization.mqh`
- `README.md`
- `AGENTS.md`
- `ROADMAP.md`
- `docs/addons/base.md`
- `docs/architecture/execution-foundation.md`
- `docs/plans/phase-03-remove-legacy-inputs-plan.md`

## Files Expected To Be Deleted If They Become Orphaned

- `services/trading_management/candle_structure_filter_context.mqh`
- `services/trading_management/trailing_structure_context.mqh`
- `services/trading_signals/structure_support_resistance_filter.mqh`
- `services/trading_signals/structure_compound_modes.mqh`
- `services/trading_signals/structure_trailing_manager.mqh`

Delete these only after their references are removed from aggregators and production code. Do not leave unused compatibility shims.

## Files To Review Before Deleting

- `services/trading_management/structure_fibonacci_levels.mqh`
- `services/indicators/fibonacci_calculator.mqh`
- `services/indicators/stochastic_market_indicator.mqh`

Stoch Structure remains the structural context source. Fibonacci internals used by Stoch Structure may stay only if they are structural-calculation internals, not user-configurable entry-policy features. Remove public input loading and feature-specific entry-policy behavior in this phase.

## Non-Goals

- Do not rename the complete grid domain; Phase 4 owns that.
- Do not remove every internal Fibonacci calculation if it is still required by Stoch Structure.
- Do not redesign risk/range foundation; Phase 5 owns that.
- Do not implement broker-aware local execution; Phase 6 owns that.
- Do not add tests, harnesses, CI, or compile-helper scripts.
- Do not edit `docs/plans/archive/` unless the user explicitly requests archive cleanup.

## Sprint 1: Remove Public Input Surface

**Goal**: Remove the legacy input groups and the three individual strategy-context inputs from the MT5 input surface.  
**Commit**: `refactor: remove legacy strategy inputs`  
**Demo/Validation**:

- Removed input declarations are gone from `services/trading_management/ea_inputs.mqh`.
- Preserved input groups still exist.
- Do not compile yet.

### Task 1.1: Remove Feature Groups From `ea_inputs.mqh`

- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Delete the five removed input groups and all inputs contained in them.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `Candle Structure Filter` group is absent.
  - `Support Resistance Retest Chain` group is absent.
  - `Structure Trailing Addon` group is absent.
  - `Structure Compound Context` group is absent.
  - `Grid Strategy Settings` group is absent.
- **Validation**:
  - `rg "Candle_Strategy|Support_Resistance_Retest_Chain|Trailing_Structure|Base_Structure_Compound|Base_Fresh_Structure|Grid_Exponential|Grid_Level" services/trading_management/ea_inputs.mqh` returns no results.

### Task 1.2: Remove Three Strategy-Context Inputs

- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Delete `Structure_Fibonacci_Levels`, `Structure_Trigger_Entry`, and `Structure_Touch_Policy`.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Strategy context keeps `Strategy_Timeframe`, `Stoch_Structure_Period_Type`, `Strategy_Direction_Mode`, and `Signal_Concurrency_Mode`.
  - Removed input names are absent from `ea_inputs.mqh`.
- **Validation**:
  - `rg "Structure_Fibonacci_Levels|Structure_Trigger_Entry|Structure_Touch_Policy" services/trading_management/ea_inputs.mqh` returns no results.

### Task 1.3: Introduce Internal Defaults Only Where Required

- **Location**: nearest owning modules that still need stable values
- **Description**: Replace removed input reads with internal constants only where needed to keep current code compiling until later roadmap phases.
- **Dependencies**: Tasks 1.1-1.2
- **Acceptance Criteria**:
  - Defaults are not `input` declarations.
  - Defaults are not documented as user-configurable compatibility shims.
  - Defaults are scoped to the module that owns the remaining lifecycle behavior.
- **Validation**:
  - Search confirms removed names are not used in production after Sprint 2.

## Sprint 2: Remove Dependent Feature Code Paths

**Goal**: Remove production code that only exists for the deleted input groups and entry-policy inputs.  
**Commit**: `refactor: remove legacy feature code paths`  
**Demo/Validation**:

- Aggregators no longer include orphaned feature modules.
- Production code no longer references removed input identifiers.
- No custom tests are run.
- Do not compile yet.

### Task 2.1: Remove Orphaned Management Includes

- **Location**: `services/trading_management.mqh`
- **Description**: Remove includes for management modules that only support removed feature groups.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - `candle_structure_filter_context.mqh` include is removed.
  - `trailing_structure_context.mqh` include is removed if no preserved code needs it.
  - `structure_fibonacci_levels.mqh` include is removed only if no preserved Stoch/internal range code needs it.
- **Validation**:
  - `rg "candle_structure_filter_context|trailing_structure_context" services/trading_management.mqh` returns no results.

### Task 2.2: Remove Orphaned Signal Includes

- **Location**: `services/trading_signals.mqh`
- **Description**: Remove signal modules that only implement deleted feature groups.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - `structure_compound_modes.mqh` include is removed.
  - `structure_support_resistance_filter.mqh` include is removed.
  - `structure_trailing_manager.mqh` include is removed.
  - Remaining include order stays sequential and acyclic.
- **Validation**:
  - `rg "structure_compound_modes|structure_support_resistance_filter|structure_trailing_manager" services/trading_signals.mqh` returns no results.

### Task 2.3: Simplify Strategy Structure Context

- **Location**: `services/trading_management/strategy_structure_context.mqh`
- **Description**: Remove support/retest-chain, compound, touch-policy, and fresh-structure-time context fields and helpers that only exist for deleted inputs.
- **Dependencies**: Tasks 2.1-2.2
- **Acceptance Criteria**:
  - No `Support_Resistance_Retest_Chain_*` references remain.
  - No `Base_Structure_Compound_Filter` or `Base_Fresh_Structure_Time` references remain.
  - No `Structure_Touch_Policy` references remain.
  - Base/trend/macro/session structure context still compiles for preserved Stoch Structure usage.
- **Validation**:
  - Targeted `rg` over `services/trading_management/strategy_structure_context.mqh`.

### Task 2.4: Remove Candle, Support/Resistance, Compound, And Trailing Filters

- **Location**: `services/trading_signals/market_signal_filters.mqh`, related orphaned modules
- **Description**: Delete filter evaluation code for removed feature groups from signal gating.
- **Dependencies**: Tasks 2.1-2.3
- **Acceptance Criteria**:
  - No candle-structure filter evaluation remains.
  - No support/resistance retest-chain filter evaluation remains.
  - No structure compound filter evaluation remains.
  - No structure trailing manager calls remain in lifecycle.
  - Remaining preserved filters still fail closed where appropriate for license/session/protection/market status.
- **Validation**:
  - `rg "CandleStructure|SupportResistanceRetest|StructureCompound|TrailingStructure" services/trading_signals services/trading_management` returns no production references except historical comments scheduled for removal in same sprint.

### Task 2.5: Remove Entry-Policy Input Usage

- **Location**: `services/trading_signals/market_signal_detection.mqh`, `services/trading_signals/grid_order_helpers.mqh`, `services/trading_signals/grid_order_logging.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Remove logic and logs driven by `Structure_Fibonacci_Levels`, `Structure_Trigger_Entry`, and `Structure_Touch_Policy`.
- **Dependencies**: Task 2.4
- **Acceptance Criteria**:
  - Removed input names have no production references.
  - Entry detection uses a stable internal foundation behavior until Phase 5/6 redesigns strategy/range execution.
  - Logging no longer emits removed input config values.
  - Frontend no longer depends on removed entry-policy inputs.
- **Validation**:
  - `rg "Structure_Fibonacci_Levels|Structure_Trigger_Entry|Structure_Touch_Policy" services HFT_Grid_AI.mq5` returns no results.

### Task 2.6: Replace Removed Grid Strategy Settings With Internal Fixed Behavior

- **Location**: `services/trading_signals/grid_order_controller.mqh`, `services/trading_signals/grid_order_helpers.mqh`, `services/trading_signals/grid_planner.mqh`, `services/frontend/grid_visualization.mqh`
- **Description**: Remove public input reads for `Grid_Exponential_Multiplier`, `Grid_Level_Position_Start`, and `Grid_Level_Stop_Limit`; use scoped internal constants only as a temporary foundation bridge until Phase 4/5.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Removed input identifiers have no production references.
  - Internal constants are not `input` declarations and are not exposed as user settings.
  - Behavior remains deterministic enough to compile until later phases.
- **Validation**:
  - `rg "Grid_Exponential_Multiplier|Grid_Level_Position_Start|Grid_Level_Stop_Limit" services HFT_Grid_AI.mq5` returns no production references.

## Sprint 3: Clean License Mapping, Docs, And Orphans

**Goal**: Remove entitlement requests and active docs references for deleted feature inputs.  
**Commit**: `refactor: remove legacy addon input mapping`  
**Demo/Validation**:

- License policy no longer requests add-ons for removed features.
- Orphaned modules are deleted.
- Active docs describe Phase 3 completion.
- Do not compile yet.

### Task 3.1: Simplify Add-On Runtime Policy

- **Location**: `services/trading_management/addon_runtime_policy.mqh`
- **Description**: Remove add-on request logic for candle structure, support/resistance retest chain, structure trailing, grid strategy config, and structure compound families.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - `CollectRequestedAddonsForCurrentInputs` only maps preserved inputs, currently session filter modes.
  - No references to removed input identifiers remain.
  - Shared license catalog files are not edited unless compile requires unused symbol cleanup.
- **Validation**:
  - `rg "ADDON_KEY_CANDLE|ADDON_KEY_SUPPORT|ADDON_KEY_STRUCTURE_TRAILING|ADDON_KEY_GRID|ADDON_KEY_COMPOUND|Candle_Strategy|Support_Resistance|Trailing_Structure|Base_Structure_Compound|Grid_Level|Grid_Exponential" services/trading_management/addon_runtime_policy.mqh` returns no removed-feature mapping.

### Task 3.2: Delete Orphaned Feature Modules

- **Location**: orphaned `.mqh` files listed above
- **Description**: Delete modules that only support removed feature groups after all references are removed.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - Deleted modules are not included anywhere.
  - No orphaned feature files remain if they have no preserved owner.
- **Validation**:
  - `rg "candle_structure_filter_context|trailing_structure_context|structure_support_resistance_filter|structure_compound_modes|structure_trailing_manager" services HFT_Grid_AI.mq5` returns no results.

### Task 3.3: Update Active Docs

- **Location**: `README.md`, `AGENTS.md`, `ROADMAP.md`, `docs/addons/base.md`, `docs/architecture/execution-foundation.md`
- **Description**: Replace "will remove" language with completed-state Phase 3 notes where appropriate.
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**:
  - Active docs do not describe removed inputs as current MT5 settings.
  - Roadmap references this plan and marks Phase 3 active/completed during execution.
  - Historical mentions in roadmap/plans remain allowed only as deletion context.
- **Validation**:
  - `rg "Candle Structure Filter|Support Resistance Retest Chain|Structure Trailing Addon|Structure Compound Context|Grid Strategy Settings|Structure_Fibonacci_Levels|Structure_Trigger_Entry|Structure_Touch_Policy" README.md AGENTS.md docs/addons docs/architecture` returns only explicit removal/completion context.

### Task 3.4: Validate No Production References Remain

- **Location**: production source tree
- **Description**: Run a final production grep for removed identifiers before compile.
- **Dependencies**: Tasks 3.1-3.3
- **Acceptance Criteria**:
  - Removed input identifiers have no production references.
  - Removed feature group helper names have no production references.
- **Validation**:
  - Use the full targeted `rg` command from the Phase 3 validation strategy.

## Sprint 4: Final Compile Gate

**Goal**: Validate production compile after removing input declarations and dependent code.  
**Commit**: `docs: complete phase 3 input removal` only if final notes are recorded after compile.  
**Demo/Validation**:

- One MT5 compile gate is run after all edits.
- Portable/headless compile is attempted first.
- Normal MetaEditor fallback is used only if needed.
- Compile log is reviewed for warnings/errors.

### Task 4.1: Run Portable/Headless Compile

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Compile the EA once after all Phase 3 edits.
- **Dependencies**: Sprints 1-3
- **Acceptance Criteria**:
  - Compile log reports `0 errors, 0 warnings`.
  - No custom tests are run.
  - If process ExitCode conflicts with compile log, record both and use the log result as the compile truth.
- **Validation**:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$logDir = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile"
$log = Join-Path $logDir "phase-03-build.log"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$args = @('/portable', '/s', "/compile:`"$entrypoint`"", "/log:`"$log`"")
$process = Start-Process -FilePath $metaeditor -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
```

### Task 4.2: Run Normal MetaEditor Fallback If Needed

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Use only if portable/headless compile does not produce a valid compile log or reports errors.
- **Dependencies**: Task 4.1 failure
- **Acceptance Criteria**:
  - Fallback reason is documented.
  - Fallback log is reviewed for warnings/errors.
  - Known non-portable AppData include-profile failures are documented as environment issues if they recur.
- **Validation**:

```powershell
$fallbackLog = Join-Path $logDir "phase-03-build-fallback.log"
$args = @('/s', "/compile:`"$entrypoint`"", "/log:`"$fallbackLog`"")
$process = Start-Process -FilePath $metaeditor -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
```

### Task 4.3: Record Compile Result

- **Location**: `ROADMAP.md`, `docs/plans/phase-03-remove-legacy-inputs-plan.md`
- **Description**: Record compile command, log path, exit code, and result line.
- **Dependencies**: Task 4.1 or Task 4.2
- **Acceptance Criteria**:
  - Phase 3 status is documented.
  - Compile result is documented.
  - Working tree is clean after final commit.
- **Validation**:
  - `git status --short`

## Phase 3 Acceptance Criteria

- Removed input groups are absent from `services/trading_management/ea_inputs.mqh`.
- `Structure_Fibonacci_Levels`, `Structure_Trigger_Entry`, and `Structure_Touch_Policy` are absent from production source.
- Removed feature input identifiers have no production references.
- License add-on policy no longer requests add-ons for removed feature inputs.
- Orphaned feature modules are deleted or explicitly retained only for preserved Stoch/internal calculations.
- Active docs reflect completed input removal.
- `HFT_Grid_AI.mq5` compiles with `0 errors, 0 warnings`.

## Validation Strategy

Use targeted validation during sprints:

```powershell
rg "Candle_Strategy|Support_Resistance_Retest_Chain|Trailing_Structure|Base_Structure_Compound|Base_Fresh_Structure|Grid_Exponential_Multiplier|Grid_Level_Position_Start|Grid_Level_Stop_Limit|Structure_Fibonacci_Levels|Structure_Trigger_Entry|Structure_Touch_Policy" services HFT_Grid_AI.mq5
rg "candle_structure_filter_context|trailing_structure_context|structure_support_resistance_filter|structure_compound_modes|structure_trailing_manager" services HFT_Grid_AI.mq5
rg "ADDON_KEY_CANDLE|ADDON_KEY_SUPPORT|ADDON_KEY_STRUCTURE_TRAILING|ADDON_KEY_GRID|ADDON_KEY_COMPOUND" services/trading_management/addon_runtime_policy.mqh
git diff --check
git status --short
```

Run the MT5 compile gate once after all code and docs edits are complete.

## Historical Docs Policy

Roadmap and phase plans may mention removed inputs as deletion history. `docs/plans/archive/` remains historical and is not part of Phase 3 cleanup unless the user explicitly requests archive purging.

## Potential Risks And Gotchas

- Removing input declarations first will create compile errors until dependent code is cleaned. That is expected inside the phase; compile only at the end.
- Grid strategy settings are public inputs being removed now, but broader grid-domain rename is Phase 4. Use scoped internal bridge constants only where needed and do not expose them as inputs.
- Stoch Structure may still depend on internal Fibonacci calculations. Do not delete internal Fibonacci utilities blindly if they are still required by Stoch Structure hydration.
- Add-on catalog constants may be shared infrastructure. Remove this EA's requests first; avoid editing shared catalog unless compile or ownership requires it.
- Frontend visual code may reference removed settings for display offsets. Remove public input reads there, but defer full frontend/domain rename to Phase 4.
- If compile fails, fix source references to removed inputs; do not restore deleted inputs as shims.

## Rollback Plan

- If Phase 3 becomes too large, stop after the current committed sprint and split remaining work into a revised plan.
- To revert the phase, revert Phase 3 commits in reverse order.
- If internal Stoch Structure utilities are accidentally deleted, restore only the required utility file and remove the public input dependency instead.
- If compile cannot pass without a product decision, document the blocker and do not create compatibility inputs.

