# Plan: Pandora XBoost V5 Hybrid Adaptive Scoring

**Generated**: 2026-06-29
**Estimated Complexity**: High / Trading-Sensitive
**Status**: Active

## Overview

Build a Pandora XBoost V5 scoring layer that restores a better balance between
adaptability and robustness after the V4 sample-window rollout became too
restrictive in deep inference testing.

The current evidence shows the clean `US30_Dukas_Clean_v2` run is mostly valid
at the broker-trade level, but V4 produced only 23 real trades across the deep
run, with most candidates blocked by `ROBUST_SCORE`. V5 should keep the
Bayesian/robust philosophy, but make recent market regime evidence primary
again and use long-history/sample-window evidence as shrinkage and safety
guards rather than as dominant vetoes.

The feature has two related parts:

- optional `session_mask.csv` gating for clean-data Strategy Tester audits;
- V5 hybrid adaptive scoring that blends calendar recent windows, sample
  windows, Bayesian shrinkage, and soft robustness penalties.

This plan does not optimize thresholds against one backtest. It defines
structural scoring rules intended to reduce overfit risk while allowing the
model to adapt when recent evidence improves.

## Goals

- Keep XBoost inference adaptive from a cold start.
- Avoid mixing V4 and V5 broker-selection behavior in the same CSV namespace.
- Reduce extreme under-trading caused by overly punitive all-history robust
  scoring.
- Preserve robust protection against fragile, outlier-dependent, stale, or
  broker-degraded nodes.
- Make clean-session data audits deterministic without slowing normal MT5
  tests or live broker usage.
- Keep new inputs minimal and explicit.

## Non-Goals

- No SQLite or external database.
- No MQL5 CI/test harness.
- No Strategy Tester automation matrix.
- No preset-specific threshold tuning for US30 or Dukascopy.
- No changes to Pandora breakout, trailing, BE, local branch lifecycle, or
  broker order mechanics beyond XBoost admission and audit gating.

## Proposed V5 Scoring Shape

```text
v5_score =
  adaptive_recent_score
  + bayesian_shrinkage_support
  + trailing_payoff_credit
  - soft_fragility_penalty
  - soft_forward_penalty
  - soft_broker_degradation
  - depth_penalty
```

Decision principles:

- Recent calendar windows (`w60_days`, `w120_days`) become the primary regime
  evidence when they have enough node samples.
- Last-N sample windows (`s60`, `s120`) remain valuable, but act as support,
  fallback, and audit evidence rather than the only recent source of truth.
- All-history Bayesian posterior remains a stabilizer, not the dominant score.
- Fragility, poor median, outlier dependency, and broker degradation should
  penalize first; hard block only when multiple independent signals confirm the
  node is weak.
- Negative recent evidence may still block, but only when the evidence is both
  sufficiently sampled and consistently weak across the relevant sources.

## V5 Data Compatibility

- Bump XBoost scoring namespace to V5 so V4/V5 broker decisions are not mixed.
- Keep CSV column formats compatible unless a sprint explicitly adds optional
  trailing audit columns.
- Existing V4 files remain readable for historical audit but should not be used
  as V5 inference state.
- V5 strategy keys should continue to include strategy id, symbol, timeframe,
  entry/trailing modes, points mode, box window, and max depth.

## Session Mask Contract

The optional session mask is for clean-data tester runs, not a dependency for
normal broker/live operation.

Recommended behavior:

- Disabled by default unless a mask path is configured.
- Load once during XBoost startup from Common Files or a user-specified relative
  file path.
- Store compact date/status rows in memory and use binary search by `yyyymmdd`.
- No file I/O on per-tick hot paths.
- If mask is disabled, XBoost behavior is unchanged.
- If mask is enabled and a date is missing, fail closed for XBoost sample/trade
  recording and log the missing date.
- If `train_allowed=false`, skip XBoost sample/stat recording for that date.
- If `trade_allowed=false`, block XBoost broker selection for that date.
- `warmup_blocked` should allow chart/tick progression but should not train.

## Execution Policy

- Execute sprints in order.
- Complete validation before moving to the next sprint.
- Create one commit per completed sprint.
- Because this affects broker admission decisions, prefer one sprint per batch
  unless the user explicitly asks for a contiguous batch.
- Compile only at the final implementation sprint unless a compile-specific
  issue appears earlier.
- Do not add MQL5 CI/test harnesses.

## Sprint 1: V5 Contract And Namespace

**Goal**: Define the V5 scoring boundary, namespace, and compatibility rules
without changing broker behavior yet.
**Commit**: `docs: define Pandora XBoost V5 hybrid scoring contract`
**Demo/Validation**:
- Static review of the plan and XBoost key/version locations.
- Confirm V4 files remain untouched and V5 will use a separate namespace.

### Task 1.1: Document V5 Runtime Contract

- **Location**: `docs/plans/pandora-xboost-v5-hybrid-adaptive-scoring-plan.md`
- **Description**: Keep this plan as the active source of truth for V5 behavior.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Plan states V5 goals, non-goals, scoring shape, and session mask behavior.
  - Plan explicitly avoids preset-specific overfit tuning.
- **Validation**:
  - Read-through against recent deep-run findings.

### Task 1.2: Identify Versioned Key Touchpoints

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/pandora_xboost_storage.mqh`
- **Description**: Locate schema/version constants and file/key builders that
  need V5 separation.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Implementation notes identify every place that emits `v4`/schema version.
  - No storage migration is required for V4 files.
- **Validation**:
  - Static grep for `PANDORA_XBOOST_SCHEMA_VERSION`, `v4`, file-name builders,
    and strategy-key builders.

### Sprint 1 Execution Notes

- Version namespace is controlled by
  `services/trading_signals/pandora_xboost_state.mqh`:
  - `PANDORA_XBOOST_SCHEMA_VERSION`;
  - `PandoraXBoostBuildStrategyKey()`;
  - `PandoraXBoostBuildNodeKey()`;
  - `PandoraXBoostBuildSampleId()`;
  - `PandoraXBoostBuildBrokerTradeId()`;
  - summary/panel labels that currently display `v4`.
- File namespace is controlled by
  `services/trading_signals/pandora_xboost_storage.mqh`:
  - `PandoraXBoostFilePrefix()`;
  - `PandoraXBoostStatsFilename()`;
  - `PandoraXBoostSamplesFilename()`;
  - `PandoraXBoostBrokerTradesFilename()`;
  - `PandoraXBoostRunSummaryFilename()`;
  - `PandoraXBoostNodeSummaryFilename()`.
- V5 must change the schema/version namespace before any inference run so V4
  and V5 samples, stats, broker trades, run summaries, and node summaries do not
  calibrate each other.

## Sprint 2: Optional Session Mask Gate

**Goal**: Add a lightweight clean-session gate that can be enabled for custom
dataset Strategy Tester runs without affecting normal broker/live operation.
**Commit**: `feat: add optional XBoost session mask gate`
**Demo/Validation**:
- With mask disabled, behavior is unchanged.
- With mask enabled, excluded/warmup dates are logged and skipped correctly.

### Task 2.1: Add Minimal Mask Inputs

- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Add the smallest practical input surface for mask use.
  Recommended shape:
  - `Pandora_XBoost_Session_Mask_File = ""`
  - empty means disabled.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - No new required input for normal users.
  - Existing presets remain valid.
  - The input can point to a Common Files CSV path.
- **Validation**:
  - Static check that default empty value produces disabled mode.

### Task 2.2: Implement Mask Loader

- **Location**: `services/trading_signals/pandora_xboost_storage.mqh` or a
  nearby XBoost-owned helper section.
- **Description**: Load `session_mask.csv` once during XBoost startup into a
  compact date-indexed structure.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Parses `date,status,train_allowed,trade_allowed` columns.
  - Converts dates to integer `yyyymmdd`.
  - Sorts rows once for binary search.
  - Logs row count and file path.
  - Missing/invalid file disables only when input is empty; if input is set and
    load fails, XBoost mask mode fails closed with clear logs.
- **Validation**:
  - Static review for no per-tick file reads.
  - Query debug labels such as `PANDORA_XBOOST_MASK_LOAD`.

### Task 2.3: Gate Training And Broker Selection

- **Location**:
  - `services/trading_signals/pandora_xboost_storage.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Apply mask decisions at XBoost sample recording and broker
  candidate selection boundaries.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - `train_allowed=false` skips sample/stat writes for the root date.
  - `trade_allowed=false` blocks broker selection with reason `SESSION_MASK`.
  - Missing date while enabled blocks both training and broker selection.
  - Local Pandora progression can still run visually for audit.
- **Validation**:
  - Static trace from `PandoraXBoostRecordClosedSignal()` and
    `PandoraXBoostFindReadyCandidateForSignal()`.

### Sprint 2 Execution Notes

- `Pandora_XBoost_Session_Mask_File = ""` disables the mask and preserves
  current behavior.
- When configured, the mask is loaded once during `PandoraXBoostLoad()` from
  Common Files using `FILE_COMMON`; there is no per-tick file I/O.
- Mask rows are stored in memory as sorted `yyyymmdd` keys and resolved with
  binary search.
- `train_allowed=false` skips XBoost sample/stat recording with
  `PANDORA_XBOOST_SAMPLE_SKIP`.
- `trade_allowed=false` blocks XBoost broker selection with
  `PANDORA_XBOOST_BROKER_SKIP reason=SESSION_MASK`.
- If the mask input is configured but the file is missing, unreadable, invalid,
  or missing a date, XBoost mask checks fail closed.

## Sprint 3: V5 Audit Fields And Shadow Metrics

**Goal**: Add V5 candidate fields and logs that show the hybrid score inputs
before changing admission behavior.
**Commit**: `feat: add XBoost V5 hybrid score audit metrics`
**Demo/Validation**:
- `PANDORA_XBOOST_DRYRUN` shows V5 audit fields.
- Broker behavior remains V4-compatible until Sprint 4.

### Task 3.1: Add Candidate Metrics

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Extend `PandoraXBoostCandidate` with V5 audit fields:
  - `adaptive_recent_r`
  - `calendar_recent_r`
  - `sample_recent_r`
  - `hybrid_shrinkage_r`
  - `soft_fragility_r`
  - `soft_broker_r`
  - `v5_score_r`
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Constructors/copy constructors initialize/copy new fields.
  - No aggregate initialization issues.
- **Validation**:
  - Static constructor/copy review.

### Task 3.2: Compute Shadow Hybrid Score

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Compute V5 score in parallel using current candidate data,
  but do not yet use it for `READY`.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Calendar windows are primary when sufficiently sampled.
  - Sample windows are fallback/support when calendar windows are sparse.
  - All-history posterior contributes as shrinkage support.
  - Soft penalties are capped.
- **Validation**:
  - Static review of formula and guard conditions.

### Task 3.3: Log V5 Shadow Metrics

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Extend top-candidate logs with compact V5 fields.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Logs remain one-line and parseable.
  - Existing fields `w120_days`, `w60_days`, `s120`, `s60`, and `age` remain.
- **Validation**:
  - Review `PANDORA_XBOOST_DRYRUN` formatting.

## Sprint 4: Hybrid Adaptive Admission

**Goal**: Make V5 hybrid score the admission score while keeping minimum-sample
and edge safeguards.
**Commit**: `feat: use hybrid adaptive score for XBoost V5 admission`
**Demo/Validation**:
- Candidate `READY` decisions come from V5 score.
- V5 should produce more realistic opportunity frequency without daily forced
  trades.

### Task 4.1: Replace Hard Historical Dominance

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Use `v5_score_r` as the candidate score for V5 mode and keep
  all-history robust components as bounded penalties/support.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Minimum samples by depth still apply.
  - Minimum score remains positive.
  - Fragility no longer hard-blocks by itself when recent evidence is strong.
  - Candidate reason distinguishes `V5_SCORE`, `V5_RECENT`, and
    `V5_FRAGILITY` where useful.
- **Validation**:
  - Static trace through `PandoraXBoostBuildCandidate()`.

### Task 4.2: Add Two-Source Recent Weakness Block

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Replace single-source recent vetoes with a stricter but more
  balanced block: recent weakness blocks only when enough sampled evidence from
  calendar/sample sources agrees that the node is weak.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - A single weak source penalizes.
  - Two sufficiently sampled weak sources can block.
  - Sparse recent evidence does not falsely block.
- **Validation**:
  - Static review against gap-heavy datasets.

### Task 4.3: Preserve Edge Ranking

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Keep alternative-side edge ranking, but compute edge from the
  V5 score instead of the old robust score.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - `READY` still requires positive edge over the alternative when the
    alternative has enough evidence.
  - The TOP 3 panel remains ordered by status and score.
- **Validation**:
  - Static trace through `PandoraXBoostApplyCandidateEdge()` and top sorting.

## Sprint 5: Broker Degradation Rebalance

**Goal**: Keep broker-real feedback valuable without allowing a small number of
broker trades to shut down adaptation too early.
**Commit**: `feat: soften XBoost broker degradation for V5`
**Demo/Validation**:
- Broker feedback penalizes only after enough broker evidence exists.
- Sustained broker weakness can still block.

### Task 5.1: Separate Broker Penalty From Broker Block

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Make broker degradation a soft penalty until stronger sample
  thresholds are met.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Node/family/recent broker averages are logged separately.
  - Low broker sample counts do not hard-block.
  - Sustained negative broker evidence can still block with reason
    `BROKER_DEGRADATION`.
- **Validation**:
  - Static review of `PandoraXBoostApplyBrokerCalibration()`.

### Task 5.2: Keep Broker Ledger Separate By V5 Namespace

- **Location**: `services/trading_signals/pandora_xboost_storage.mqh`
- **Description**: Ensure V5 broker trades do not calibrate V4 and V4 broker
  trades do not calibrate V5.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Strategy key/version separation is explicit.
  - Existing V4 CSV files are not read as V5 broker state.
- **Validation**:
  - Static grep for broker trade strategy matching.

## Sprint 6: Audit Output And Operator Visibility

**Goal**: Make the V5 decision path easy to audit after one long Strategy Tester
run.
**Commit**: `feat: expose XBoost V5 audit reasons`
**Demo/Validation**:
- Query debug and panel show why candidates are READY/BLOCK/WAIT.

### Task 6.1: Update Query Debug Reasons

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add compact V5 reason labels and keep old labels readable.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Reasons distinguish insufficient samples, recent weakness, score weakness,
    stale sample, session mask, and broker degradation.
  - Logs remain parseable by simple CSV/text scripts.
- **Validation**:
  - Static review of top candidate logging.

### Task 6.2: Update Panel Candidate Rows

- **Location**: `services/frontend/pandora_box_panel.mqh`
- **Description**: Keep panel compact while showing V5 score/reason for the top
  candidates.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Existing panel line count remains bounded.
  - No chart objects or UI state affect trading decisions.
- **Validation**:
  - Static review of frontend-only changes.

### Task 6.3: Update Guides

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
- **Description**: Document V5 scoring, session mask behavior, and audit
  expectations.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Guides explain that V5 is adaptive and not a fixed A/B backtest.
  - Guides state that mask mode is optional and mainly for clean dataset tests.
- **Validation**:
  - Read-through for consistency with inputs and logs.

## Sprint 7: Final Compile And Manual Test Handoff

**Goal**: Validate the implementation with MetaEditor compile and produce a
clear manual Strategy Tester checklist.
**Commit**: `chore: validate XBoost V5 hybrid scoring`
**Demo/Validation**:
- MetaEditor compile passes with no errors or warnings.
- Handoff includes one short-run and one long-run audit checklist.

### Task 7.1: Compile Gate

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run the project MetaEditor compile command.
- **Dependencies**: Sprints 1-6.
- **Acceptance Criteria**:
  - Compile completes with zero errors.
  - Warnings are reviewed and treated as failures unless already known and
    unrelated.
  - `BUILD.log` is removed after inspection.
- **Validation**:
  - Run:
    ```powershell
    & "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
    ```

### Task 7.2: Short Smoke Test Checklist

- **Location**: `docs/guides/pandora-box-strategy-inputs.md`
- **Description**: Add a manual Strategy Tester checklist for a short masked
  run around known excluded/warmup dates.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - Excluded dates create no XBoost samples.
  - Warmup dates create no XBoost samples when mask is enabled.
  - Broker trades occur only when `trade_allowed=true`.
  - Spread remains normalized in broker diagnostics.
- **Validation**:
  - User-run Strategy Tester audit with `Enable_File_Logs=true`.

### Task 7.3: Long Deep-Run Checklist

- **Location**: `docs/guides/pandora-box-strategy-inputs.md`
- **Description**: Add the deep-run acceptance checklist for the full clean
  dataset.
- **Dependencies**: Task 7.2.
- **Acceptance Criteria**:
  - Confirm V5 starts from `stats=0 samples=0 broker=0`.
  - Confirm broker trades are all trainable/tradable.
  - Confirm `READY` frequency is higher than V4's extreme under-trading while
    still sparse enough to avoid forced daily trading.
  - Compare yearly broker trades, total R, median R, and reason distribution.
- **Validation**:
  - Manual audit of `samples.csv`, `broker_trades.csv`, `run_summary.csv`, and
    `query_debug.txt`.

## Testing Strategy

- Static validation per sprint.
- Final MetaEditor compile only at the final sprint unless an earlier sprint
  introduces syntax uncertainty.
- Manual short Strategy Tester smoke test with `Enable_File_Logs=true`.
- Manual deep inference run only after V5 and mask gate are compiled.
- Audit scripts should compare:
  - sample dates vs `session_mask.csv`;
  - broker entry/close dates vs `session_mask.csv`;
  - `READY/BLOCK/WAIT` reason distribution;
  - `w60/w120` vs `s60/s120` score behavior;
  - broker trades by year and node path;
  - realized R vs V5 score.

## Success Criteria

- Mask-enabled clean dataset tests produce no samples on `train_allowed=false`
  dates.
- Broker trades occur only on `trade_allowed=true` dates when mask is enabled.
- V5 does not repeat V4's extreme under-trading profile unless market evidence
  genuinely provides no candidates.
- V5 does not force trades when recent evidence is weak.
- Recent positive evidence can overcome old weak history when the node is not
  structurally fragile.
- Broker degradation protects the model without shutting down adaptation from a
  small early sample.

## Potential Risks And Gotchas

- **Too many trades after relaxing score**: mitigate with positive score,
  minimum edge, and two-source weakness checks.
- **Hidden overfit from threshold changes**: keep constants generic and do not
  tune to one US30 result curve.
- **Mask file overhead**: load once at startup; never read the file per tick.
- **Missing mask date**: fail closed only when mask mode is explicitly enabled.
- **V4/V5 data contamination**: separate namespace before running any V5
  inference.
- **Broker feedback double counting**: keep broker calibration separate from
  local samples and log both.
- **Panel/log bloat**: keep V5 audit fields compact and bounded.

## Rollback Plan

- Disable mask mode by clearing `Pandora_XBoost_Session_Mask_File`.
- Revert to archived V4 plan/commits if V5 compile or audit behavior is worse.
- Because V5 uses a separate namespace, V4 CSV files remain intact.
- If V5 produces too many trades, restore stricter V5 internal constants before
  running another long test.
