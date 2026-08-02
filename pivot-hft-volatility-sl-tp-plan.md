# Plan: Pivot HFT Volatility-Normalized Local Exits

**Generated**: 2026-08-01
**Revised**: 2026-08-01 after execution authorization
**Status**: Completed
**Completed**: 2026-08-01
**Complexity**: Critical / trading-sensitive
**Execution**: Sprints 1-6 in order, exactly one validated commit per Sprint

## Overview

Pivot HFT currently anchors `Pivot_HFT_Local_SL_Points` and
`Pivot_HFT_TP_Step_Points` to the actual broker fill. The step is a local
break-even/trailing interval, not a fixed take-profit. Entries already use one
cached native Bollinger handle (`21`, deviation `2.0`, `PRICE_CLOSE`) and read
the previous closed micro bar (`shift=1`).

The implementation will reuse that existing cached upper/lower snapshot to add
optional volatility-normalized exit geometry without another indicator handle:

```text
band_width_points = (upper_band - lower_band) / SYMBOL_POINT
initial_sl_points = band_width_points * bands_width_percent / 100
step_points       = initial_sl_points * tp_step_sl_ratio
fixed_tp_points   = initial_sl_points * fixed_tp_sl_ratio
```

With the fixed deviation `2.0`, the full band width is approximately `4 sigma`;
therefore `25%` of full width is approximately `1 sigma`. This is a volatility
scale, not a normal-distribution probability claim.

## User Execution Overrides

- Keep new inputs minimal, efficient, and non-redundant for Strategy Tester
  parameter stepping.
- Do not add test harnesses, CI modules, parser scripts, synthetic fixtures, or
  automated Strategy Tester jobs.
- Do not run manual or automated Strategy Tester QA during implementation; the
  user will perform that after handoff.
- Do not compile the full EA during Sprints 1-5.
- Sprint 6 is the only full MetaEditor compile gate and must fix all compile
  errors/warnings found before completion.
- Execute all six Sprints now, in order, with one commit per completed Sprint.

## Fixed Decisions

- Reuse `g_pivot_hft_bands_upper`, `g_pivot_hft_bands_lower`, and
  `g_pivot_hft_bands_bar`; add no ATR or second Bollinger handle.
- Use the latest cached closed-bar bands immediately before order send. Freeze
  that geometry for the ticket and anchor exact prices to the verified fill.
- Keep server-side SL/TP at zero; protection remains local.
- Preserve existing point inputs and their defaults for `.set` compatibility.
- Add only one new enum:
  - `Pivot_HFT_Local_SL_Mode`: fixed points or full-band-width percentage.
- Add only three new numeric inputs:
  - `Pivot_HFT_Local_SL_Bands_Width_Percent`, used only in band mode.
  - `Pivot_HFT_TP_Step_SL_Ratio`: `0` keeps existing point step; `> 0` derives
    the trailing step from immutable initial SL.
  - `Pivot_HFT_Fixed_TP_SL_Ratio`: `0` disables fixed TP; `> 0` enables an
    immutable initial-SL multiple.
- Do not add separate step-mode or fixed-TP-mode enums; their zero-disabled
  ratios provide simpler Strategy Tester runs.
- Default behavior remains points SL, points trailing step, fixed TP disabled.
- Fixed TP trigger priority is evaluated before advancing the trailing step on
  the same favorable tick. Protection/market-status forced closes remain prior
  and authoritative.
- Lot size remains fixed. Volatility-normalized exit geometry does not imply
  constant monetary risk.
- Correct the existing `OnTester()` arithmetic so `STAT_PROFIT`, which is net
  profit, is divided by initial deposit rather than having the deposit
  subtracted again.

## Scope

- **In scope**:
  - Minimal inputs and enum.
  - Immutable risk geometry resolved before order send.
  - Volatility SL, initial-SL-ratio step, optional fixed-R local TP.
  - Ticket state, close classification, diagnostics, panel/visualization, and
    user documentation.
  - Existing `OnTester()` arithmetic correction.
  - Final full compile and compile-defect fixes in Sprint 6 only.
- **Out of scope**:
  - ATR/Keltner/new volatility indicators.
  - Risk-based lot sizing or account-risk inputs.
  - Server SL/TP.
  - Entry, pivot, retracement, session, daily limit, protection, licensing,
    margin, spread, symbol/magic, or single-flight changes.
  - Harness tests, CI, automated QA, Strategy Tester execution, result analysis,
    parameter optimization, or changing defaults based on research.

## Named Files

- `pivot-hft-volatility-sl-tp-plan.md`
- `microservices/core/enums.mqh`
- `services/trading_management/ea_inputs.mqh`
- `services/trading_signals.mqh`
- `services/trading_signals/pivot_hft_risk_geometry.mqh` (new)
- `services/trading_signals/pivot_hft_state.mqh`
- `services/trading_signals/pivot_hft_execution.mqh`
- `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- `services/frontend/pivot_hft_panel.mqh`
- `services/frontend/pivot_hft_visualization.mqh`
- `HFT_Grid_AI.mq5`
- `README.md`
- `docs/guides/pivot-hft-strategy-inputs.md`

## Validation Policy

Sprints 1-5 use static validation only:

- `rtk git status --short`
- focused `rtk grep` checks for names/references/contracts
- `rtk git diff --check`
- focused diff review for include order, struct initialization, hot-path cost,
  symbol/magic scope, server SL/TP zeroes, and cleanup ownership

Sprint 6 alone runs the full compile command:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

Read the current `BUILD.log`, fix all errors/warnings, recompile until clean, and
remove `BUILD.log`. No Strategy Tester run is part of this execution.

## Sprint 1: Minimal Input And Enum Contract

**Goal**: Introduce the smallest backward-compatible public input surface.

**Dependencies**: None.

**Files**: `pivot-hft-volatility-sl-tp-plan.md`,
`microservices/core/enums.mqh`, `services/trading_management/ea_inputs.mqh`

**Commit**: `Sprint 1: define minimal pivot hft exit inputs`

### Tasks

1. Add `PivotHftLocalSlModes` with stable values for points and full-band-width
   percentage.
2. Add `Pivot_HFT_Local_SL_Mode` defaulting to points.
3. Keep `Pivot_HFT_Local_SL_Points` and `Pivot_HFT_TP_Step_Points` unchanged.
4. Add `Pivot_HFT_Local_SL_Bands_Width_Percent = 25.0`.
5. Add `Pivot_HFT_TP_Step_SL_Ratio = 0.0`; zero selects legacy point step.
6. Add `Pivot_HFT_Fixed_TP_SL_Ratio = 0.0`; zero disables fixed TP.
7. Keep input ordering clear so only relevant numeric fields need optimizer
   stepping for a selected mode.

### Acceptance Criteria

- Existing input names/defaults remain compatible.
- Only one new enum and three new numeric inputs exist.
- No trading logic changes in this Sprint.
- No compile or Strategy Tester run occurs.

### Validation

- Inspect enum numeric stability and the input diff.
- Confirm no product file outside the listed scope changed.
- Run `rtk git diff --check`.

### Rollback

- Revert the one Sprint 1 commit.

### Sprint 1 Gate

- [x] Tasks and static validation complete.
- [x] Diff is limited to plan/input/enum contracts.
- [x] Exactly one Sprint 1 commit created and rollback hash recorded.

## Sprint 2: Immutable Cached-Band Risk Geometry

**Goal**: Resolve one validated, immutable geometry snapshot before order send.

**Dependencies**: Sprint 1 commit and gate.

**Files**: `services/trading_signals/pivot_hft_risk_geometry.mqh`,
`services/trading_signals.mqh`, `services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`, `HFT_Grid_AI.mq5`

**Commit**: `Sprint 2: resolve pivot hft cached-band risk geometry`

### Tasks

1. Add an explicit `PivotHftRiskGeometry` struct with deterministic constructor
   fields for band source, upper/lower, width points, initial SL points, step
   points, fixed TP points, and validity.
2. Add pure input validation:
   - points SL requires positive `Pivot_HFT_Local_SL_Points`;
   - band mode requires positive band-width percentage;
   - step ratio and fixed TP ratio cannot be negative;
   - if step ratio is zero, legacy step points must be positive.
3. Add pure geometry resolution using only the existing cached closed bands and
   existing point/tick helpers. No handle creation or `CopyBuffer` call.
4. Insert the new strategy include after Pivot HFT indicators and before
   detection/execution consumers without sibling re-includes or cycles.
5. Call input validation from `OnInit` and fail with
   `INIT_PARAMETERS_INCORRECT` before signal resources activate.
6. Resolve geometry after existing entry guards but before `Buy`/`Sell`; invalid
   runtime geometry blocks order send with an actionable audit reason.
7. Pass the local geometry value into verified fill registration and copy its
   immutable values into `PivotHftPositionState`.

### Acceptance Criteria

- Default geometry resolves to existing point SL and point step.
- Band width uses `upper - lower` from the cached `shift=1` snapshot.
- A carried campaign uses the latest cached closed band at order-send time.
- No unresolved geometry is intentionally sent to the broker.
- Server SL/TP arguments remain zero.
- No compile or Strategy Tester run occurs.

### Validation

- Trace inputs -> cached bands -> resolver -> entry preflight -> registration.
- Search for exactly one `iBands` creation path and unchanged `CopyBuffer`
  scheduling.
- Review symbol/magic/fill verification and `rtk git diff --check`.

### Rollback

- Revert the one Sprint 2 commit to the Sprint 1 hash.

### Sprint 2 Gate

- [x] Tasks and static validation complete.
- [x] Include layering, immutable state, and pre-send failure path reviewed.
- [x] Exactly one Sprint 2 commit created and rollback hash recorded.

## Sprint 3: Volatility SL And Initial-Risk Trailing Step

**Goal**: Apply stored geometry to the actual fill and preserve monotonic local
SL/BE/trailing behavior.

**Dependencies**: Sprint 2 commit and gate.

**Files**: `services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`

**Commit**: `Sprint 3: apply pivot hft volatility sl and risk step`

### Tasks

1. Add immutable per-ticket initial SL and resolved step fields plus exact local
   SL price initialization from the verified fill.
2. Preserve legacy points mode by resolving the same distance and normalized
   stop price as the current implementation.
3. Use stored resolved step points in `PivotHftUpdateTrailingStop`; never reread
   bands or recompute from the moving stop.
4. Keep first completed step at break-even and later stops monotonic.
5. Retain a recovery initialization path that uses stored geometry only.
6. Extend bounded initialization/trailing diagnostics with resolved geometry;
   add no per-tick logging or unbounded work.

### Acceptance Criteria

- Open-ticket geometry cannot change after later band refreshes.
- Ratio zero preserves `Pivot_HFT_TP_Step_Points` behavior.
- Positive ratio uses immutable initial SL distance.
- Local stops never move backward.
- No compile or Strategy Tester run occurs.

### Validation

- Inspect BUY/SELL formulas, point/tick normalization, first-step BE math, and
  later-step direction comparisons.
- Confirm lifecycle uses ticket state rather than active global bands/inputs.
- Run focused searches and `rtk git diff --check`.

### Rollback

- Revert the one Sprint 3 commit to the Sprint 2 hash.

### Sprint 3 Gate

- [x] Tasks and static validation complete.
- [x] Legacy path and monotonic trailing reviewed for BUY/SELL.
- [x] Exactly one Sprint 3 commit created and rollback hash recorded.

## Sprint 4: Optional Fixed-R Local TP

**Goal**: Add a zero-disabled fixed TP based on immutable initial SL.

**Dependencies**: Sprint 3 commit and gate.

**Files**: `microservices/core/enums.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`

**Commit**: `Sprint 4: add pivot hft fixed risk target`

### Tasks

1. Append `PIVOT_HFT_CLOSE_TRIGGER_FIXED_TP` without changing existing close
   trigger numeric values.
2. Initialize `local_tp_price` from actual fill and stored fixed TP distance only
   when `Pivot_HFT_Fixed_TP_SL_Ratio > 0`.
3. Add direction-aware target crossing using the existing local close quote.
4. Evaluate fixed TP before advancing trailing on the same favorable tick; when
   disabled, preserve the current trailing/SL path.
5. Reuse existing ticket-scoped `PositionClose`, retcode handling, close retry,
   finalization, daily outcome, and rearm rules.
6. Record an explicit TP trigger/target without relabeling profitable BE or
   trailing closes.

### Acceptance Criteria

- Ratio zero has no target and no changed close behavior.
- BUY target is above fill; SELL target is below fill.
- Fixed TP does not bypass symbol/magic, protection, market-status, or close
  permission controls.
- Net result remains the profit/loss/flat source of truth.
- No compile or Strategy Tester run occurs.

### Validation

- Trace fixed TP disabled/enabled branches and close-failure restoration.
- Review trigger priority, BUY/SELL comparisons, rearm semantics, and
  `rtk git diff --check`.

### Rollback

- Revert the one Sprint 4 commit to the Sprint 3 hash.

### Sprint 4 Gate

- [x] Tasks and static validation complete.
- [x] Local close ownership and existing safety scopes reviewed.
- [x] Exactly one Sprint 4 commit created and rollback hash recorded.

## Sprint 5: Diagnostics, Frontend, Tester Criterion, And Documentation

**Goal**: Make the new geometry auditable and document the manual QA contract.

**Dependencies**: Sprint 4 commit and gate.

**Files**: `HFT_Grid_AI.mq5`, `services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`, `README.md`,
`docs/guides/pivot-hft-strategy-inputs.md`

**Commit**: `Sprint 5: expose and document pivot hft exit geometry`

### Tasks

1. Extend `CONFIG`, fill/risk, trailing, local-close, and finalization audit
   fields with SL mode, band width, initial SL, resolved step, TP ratio/target,
   and explicit trigger.
2. Show compact initial risk/current stop/step/optional target values in the
   panel without mutating trading state.
3. Draw deterministic `POSITION_<ticket>_TP` only when enabled, using existing
   dynamic object tracking and cleanup.
4. Correct `OnTester()` normalized growth to
   `STAT_PROFIT / STAT_INITIAL_DEPOSIT`; retain the remaining current score
   components and forced-stop behavior.
5. Update README and the Spanish strategy-input guide with exact input names,
   zero-disabled semantics, formulas, fixed-lot caveat, local-protection caveat,
   and a manual Strategy Tester checklist for the user.
6. Do not add scripts, test modules, CI, tester automation, or result artifacts.

### Acceptance Criteria

- Frontend is read-only and non-visual tester behavior remains guarded by
  existing checks.
- TP object participates in existing cleanup and causes no object churn when
  disabled.
- Documentation matches code names/defaults exactly and makes no profitability
  claim.
- No compile or Strategy Tester run occurs.

### Validation

- Review frontend ownership, deterministic names, cleanup, and documentation.
- Hand-check `OnTester()` arithmetic against official `STAT_PROFIT` semantics.
- Run focused searches and `rtk git diff --check`.

### Rollback

- Revert the one Sprint 5 commit to the Sprint 4 hash.

### Sprint 5 Gate

- [x] Tasks and static validation complete.
- [x] Frontend, diagnostics, docs, and tester arithmetic reviewed.
- [x] Exactly one Sprint 5 commit created and rollback hash recorded.

## Sprint 6: Final Full-EA Compile And Defect Repair

**Goal**: Compile the complete EA once integration is finished, repair every
compile defect, and leave a clean handoff for user-run Strategy Tester QA.

**Dependencies**: Sprint 5 commit and gate.

**Files**: Any implementation file requiring a compile fix,
`pivot-hft-volatility-sl-tp-plan.md`; transient `BUILD.log` must not remain.

**Commit**: `Sprint 6: validate final pivot hft build`

### Tasks

1. Run the exact MetaEditor command from the Validation Policy.
2. Read the newly generated `BUILD.log` and capture the exact first useful error
   or warning lines if defects exist.
3. Fix only defects caused by or exposed through this plan; preserve behavior
   and avoid unrelated refactors.
4. Recompile until the current log reports zero errors and zero warnings.
5. Remove `BUILD.log` after confirming the result.
6. Perform final static review of inputs -> indicators -> geometry -> execution
   -> lifecycle -> protection -> frontend, plus symbol/magic and local-resource
   cleanup contracts.
7. Update this plan's execution record with Sprint commit hashes, final compile
   result, and the explicit note that Strategy Tester QA was not run by Codex.

### Acceptance Criteria

- Full EA compiles with zero errors and zero warnings.
- `BUILD.log` is removed after validation.
- No harness/CI/test module or automated/manual Strategy Tester run was added or
  executed.
- Worktree contains no unexpected generated artifacts.
- User receives exact changed files, six commit hashes, compile result, and
  remaining manual QA risks.

### Validation

- MetaEditor full compile and current-log inspection.
- `rtk git status --short`, `rtk git diff --check`, and final commit/diff review.

### Rollback

- Revert the one Sprint 6 commit, then revert prior Sprint commits in reverse
  order as needed. Do not detach/revert while a locally protected live/demo
  position depends on the EA.

### Sprint 6 Gate

- [x] Full compile passes with zero errors/warnings.
- [x] `BUILD.log` removed and worktree reviewed.
- [x] Plan execution record updated.
- [x] Exactly one Sprint 6 commit created and rollback hash recorded.
- [x] Active plan state marked complete.

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| Wider band SL increases money risk with fixed lots | Keep default points mode and document fixed-lot caveat |
| Forming-band path dependence | Use cached closed `shift=1` snapshot only |
| Carried campaign uses stale arm volatility | Resolve latest cached geometry immediately before order send |
| Invalid band geometry leaves unsafe entry | Validate and block before `Buy`/`Sell` |
| Step changes after entry | Store immutable resolved step per ticket |
| TP and BE cross together | TP has explicit same-tick priority |
| Local close delay/slippage | Reuse existing close retry and actual net finalization |
| Input optimization redundancy | One enum; zero-disabled step/TP ratios |
| Hot-path overhead | No new handle/history scan/per-tick logging; bounded state math only |
| Compile defects accumulate through Sprints 1-5 | Sprint 6 is reserved for complete compile/fix loop per user instruction |
| Runtime behavior remains unverified | User performs manual real-tick Strategy Tester QA after handoff |

## Execution Record

| Sprint | Status | Commit | Validation |
| --- | --- | --- | --- |
| 1 | Complete | `0984e73` | Static input/enum compatibility review |
| 2 | Complete | `42c503c` | Static include, cached-band, pre-send and immutable-state review |
| 3 | Complete | `55b71f5` | Static BUY/SELL SL, BE and monotonic trailing review |
| 4 | Complete | `1227b48` | Static fixed-TP priority, ticket close and retry review |
| 5 | Complete | `fd6d4f2` | Static diagnostics, frontend, docs and `OnTester()` review |
| 6 | Complete | This Sprint 6 commit | MetaEditor: `0 errors, 0 warnings` |

### Completion Notes

- The exact compile command was attempted first. MetaEditor selected its roaming
  data directory and could not find the portable install's standard
  `Include\Trade\Trade.mqh`.
- The same compile and log paths were then run with MetaEditor's `/portable`
  data-root mode. The current build completed with `0 errors, 0 warnings` in
  `8627 ms`; no EA compile repair was required.
- `BUILD.log` was removed after inspection. No harness, CI module, parser,
  fixture, automated tester job, or result artifact was added.
- Codex did not run Strategy Tester QA. The checklist below remains the user's
  manual real-tick validation handoff.

## Final Manual QA Handoff

Codex will not run Strategy Tester QA in this execution. The user should test at
minimum:

1. Legacy points SL/points step/fixed TP off.
2. Band SL at representative full-width percentages.
3. Step ratio zero versus positive initial-SL ratios.
4. Fixed TP zero versus positive ratios for BUY and SELL.
5. Carried campaign filling after later micro bars and using the latest closed
   band snapshot.
6. SL, BE, multi-step trailing, TP priority, close delay/rejection, rearm, and
   protection/external closes.
7. Panel/objects in visual mode and absence/cleanup in non-visual/deinit paths.
8. Broker-specific spread, commission, slippage, session, and fixed-lot drawdown
   behavior using `Every tick based on real ticks`.
