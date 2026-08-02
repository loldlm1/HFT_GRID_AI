# Plan: Pivot HFT Retry Threshold Continuity And Audit Hardening

**Generated**: 2026-08-02
**Status**: Implementation in progress; Sprints 1-2 complete
**Estimated Complexity**: Critical / trading-sensitive
**Execution override**: User authorized contiguous execution of Sprints 1-3
with one validated commit per Sprint and one final MetaEditor compile.

## Overview

Audit the latest focused `query_debug.txt` run, correct the lifecycle defect
that makes `Pivot_HFT_Start_Real_Retry` look like a maximum retry count, and
make retry state unambiguous in both the chart and the audit stream.

The source-selection helper is already correct: initial entry is broker retry
`0`, retries below the configured positive threshold are virtual, and the
configured retry plus every later retry are broker executions. The observed
failure is lifecycle-based: an eligible non-positive close can rearm only while
the micro candle containing its fill is still current. This time boundary ends
many chains before they reach the configured first real retry.

The implementation will align a closed position's pending retry lifetime with
the existing pending-campaign lifetime. A chain may cross micro candles while
the session/resources and original macro pivot set remain valid. It ends only
through a documented terminal condition, not merely because M3 advanced.

## Audit Baseline And Findings

Evidence source (read-only, not copied into the repository):

`C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\query_debug.txt`

- One complete run: `1,790` rows, `479,531` bytes, from 2024-01-05 through
  2024-01-31, with `start_real_retry=2`, US30, micro M3 and pivot H1.
- Fill/finalization reconciliation is exact: `36` broker fills plus `9` virtual
  fills equal `45` `POSITION_FINALIZED` rows. No orphan broker/virtual lifecycle
  or unresolved fill appears.
- Results are `28` losses, `16` profits and `1` flat. Of `29` eligible
  non-positive closes, `12` rearmed and `17` emitted `REARM_EXPIRED`.
- The `17` time-expired chains are `12` initial broker entries, `4` virtual
  retry-1 positions and `1` broker retry-2 position. This affects about `58.6%`
  of eligible non-positive closes.
- Routing itself is correct: all `9` retry-1 fills are virtual, all broker retry
  fills are retry `2`, and no virtual retry is sent to the broker.
- Three retry-2 broker campaigns were armed. Two filled; one was silently
  replaced by a newer R2 campaign while still tracking. Replacement is allowed
  by the one-latest-level policy, but the terminal retry-chain decision is not
  explicit in the event payload or visual state.
- Campaign tracking already survives micro-bar transitions through
  `CAMPAIGN_CARRIED_FORWARD`. Only the post-close rearm precursor is limited to
  the fill bar, creating an inconsistent lifetime contract.
- Entry reconciliation is also exact: `50` `ENTRY_TRIGGERED` rows equal `45`
  fills plus `5` safe `ENTRY_RISK_DISTANCE_BLOCKED` attempts, each paired with
  `ENTRY_RETRYABLE`.
- All `36` broker sends succeeded with `sent=1`, retcode `10009` and error `0`.
  There are no virtual aborts, unresolved fills, result-model fallbacks or
  post-fill distance failures in this run.
- The audit schema contains duplicate keys: all `12` `POSITION_REARMED` rows
  contain two `execution_source` keys with different meanings, and all `9`
  `VIRTUAL_FILL_REGISTERED` rows contain two `spread_pts` keys.
- `RUN_START visual=0` reports tester runtime visual mode while `CONFIG visual=1`
  reports the visualization input. Both values are valid, but the shared key is
  ambiguous.
- Observed entry slippage, close slippage and per-lot costs are all zero in this
  tester run. The virtual model correctly inherits those observed values and
  uses real Bid/Ask spread, but the logs do not clearly distinguish an observed
  zero from a missing or fallback model.

## Scope

- **In scope**:
  - Archive the completed prior plan during Sprint 1 and link it to this plan.
  - Clear stale hook continuity state before Sprint 1 execution and initialize
    fresh state for this plan.
  - Remove the fill-micro-candle boundary as a retry-chain terminator.
  - Continue eligible retries across micro candles while session/resources and
    the original pivot set remain valid.
  - Distinguish transient retry deferral from terminal invalidation.
  - Preserve deterministic virtual/broker threshold routing for `0`, `1`, and
    every `N >= 2`.
  - Preserve the one pending campaign / one managed position execution slot.
  - Make level replacement of a retry campaign explicit and auditable.
  - Normalize audit keys, add lifecycle/model provenance, and improve visual
    retry state.
  - Update operator documentation and the manual Strategy Tester matrix.
- **Out of scope**:
  - Adding a maximum retry count, cooldown, retry queue, or concurrent campaign.
  - Adding another strategy input or changing the default threshold.
  - Changing pivot admission, Bollinger geometry, retracement math, lot size,
    local SL/BE/trailing/TP behavior, or broker distance formulas.
  - Inventing random slippage, synthetic commission, or a non-broker-derived
    virtual result.
  - Adding MQL5 harness tests, CI modules, headless Strategy Tester matrices,
    dependencies, migrations, or include-pipeline changes.
  - Running the user's final visual Strategy Tester QA.
- **Fixed decisions**:
  - `Pivot_HFT_Start_Real_Retry=0`: initial broker entry only; no retry.
  - `Pivot_HFT_Start_Real_Retry=1`: retry `1` and every later retry use broker.
  - `Pivot_HFT_Start_Real_Retry=N >= 2`: retries `1..N-1` are virtual; retry `N`
    and every later retry use broker. The value is a start threshold, never a
    maximum.
  - Initial entry remains broker retry `0`.
  - An eligible non-positive locally requested close keeps the admitted
    sequence and may rearm across micro bars.
  - Session/resource shutdown, pivot-set/price change, retry input `0`, external
    or protection close, and documented latest-level replacement are terminal
    chain outcomes.
  - Spread, broker status, daily budget, protection gate, indicator readiness,
    another blocking lifecycle, or a temporarily occupied campaign slot may
    defer rearm; they must not silently convert the threshold into a maximum.
  - The current latest-level replacement policy and single execution slot stay
    intact. A replacement terminates the superseded chain explicitly rather
    than creating a second pending campaign.
  - Virtual execution continues to use fresh executable Bid/Ask, broker tick
    normalization, `OrderCalcProfit`, and signed observed source slippage/cost.
    Zero observed values remain zero and are labeled as observed, not guessed.
  - Compile MetaEditor only once, after all three Sprints. Earlier Sprint gates
    use focused static/diff validation.
- **Assumptions**:
  - The audited January run is the user's latest focused QA evidence.
  - The account remains hedging and the runtime license magic contract is
    unchanged.
  - Manual QA will use `Every tick based on real ticks` after implementation.

## Named Resources

- **Project instructions**:
  - `AGENTS.md`
  - `docs/planner-execution-discipline.md`
  - `C:\Users\loldlm\.codex\skills\planner\references\execution-state.md`
  - `C:\Users\loldlm\.codex\skills\mql5-production-engineering\SKILL.md`
- **Prior plan and hook state**:
  - `docs/plans/pivot-hft-entry-safety-retry-visibility-plan.md`
  - `docs/plans/archive/pivot-hft-entry-safety-retry-visibility-plan.md`
  - `.codex-hook-state/active-plan-state.json`
  - `.codex-hook-state/compact-plan-state-*.json`
- **Implementation files**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_indicators.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
  - `services/trading_signals/pivot_hft_diagnostics.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
  - `README.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - this plan
- **Validation resources**:
  - `C:\Program Files\MetaTrader 5-1\MetaEditor64.exe`
  - `C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5`
  - temporary `C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log`
  - focused Strategy Tester output in the terminal common `query_debug.txt`
- **External documentation**:
  - None required. The change is an internal lifecycle contract and does not
    depend on version-sensitive external API behavior.
- **Operational resources**:
  - Git history and one Sprint-specific commit per Sprint.
  - User-run visual Strategy Tester QA after the final compile.

## Prerequisites

- Confirm `rtk git status --short` is clean and the latest completed commits are
  `9a9a0ff`, `332ce19`, and `fc62b98` before editing.
- Verify the prior plan is complete through Sprint 5 and the stale hook state
  reports Sprint 5 validation passed and committed.
- Before Sprint 1 product edits, read planner `references/execution-state.md`,
  remove only the verified disposable files under this repository's
  `.codex-hook-state`, and initialize fresh redacted active-plan state pointing
  to this plan. Hook files must remain untracked and contain no private log data.
- Retain the audited `query_debug.txt` as read-only baseline evidence. Rotate it
  only immediately before the new focused manual tester run.
- Execute exactly one critical/trading-sensitive Sprint per batch.

## Sprint 1: Persist Valid Retry Chains Across Micro Bars

**Goal**: Make an eligible retry chain survive M3 transitions while preserving
all real terminal invalidations and the single execution slot.

**Dependencies**: clean baseline, verified old hook state, current threshold
routing helper, current pending-campaign cancellation contract.

**Tracked scope**:
`docs/plans/pivot-hft-entry-safety-retry-visibility-plan.md`,
`docs/plans/archive/pivot-hft-entry-safety-retry-visibility-plan.md`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_indicators.mqh`,
`services/trading_signals/pivot_hft_levels.mqh`

**Commit**: `Sprint 1: persist valid Pivot HFT retry chains`

**Demo/Validation**:

- Statically trace a retry-2 broker loss that closes in a later M3 candle and
  verify it becomes pending retry `3` broker instead of `REARM_EXPIRED`.
- Statically trace session close and macro pivot rollover and verify both
  terminally complete the pending chain without opening a new position.
- Run `rtk git diff --check` and inspect only the Sprint 1 diff.

**Rollback point**: commit immediately preceding Sprint 1. Reverting the single
Sprint 1 commit restores the fill-bar retry boundary and the prior active plan
location.

### Task 1.1: Archive The Completed Prior Plan

- **Location**:
  - `docs/plans/pivot-hft-entry-safety-retry-visibility-plan.md`
  - `docs/plans/archive/pivot-hft-entry-safety-retry-visibility-plan.md`
- **Description**:
  - Mark the prior plan `Completed and archived` with its final Sprint 5 commit,
    compile result, manual-QA handoff, and a link to this successor audit plan.
  - Move it into `docs/plans/archive/` without altering its historical execution
    records.
  - Include the tracked move in the one Sprint 1 commit. Hook cleanup remains a
    disposable runtime action and must not be committed.
- **Dependencies**: verified clean worktree and commit `9a9a0ff`.
- **Acceptance criteria**:
  - Only this plan remains active in `docs/plans/`.
  - The archived plan clearly records completion and succession.
- **Validation**:
  - `rtk git status --short`
  - `rtk grep "Completed and archived|pivot-hft-retry-threshold-log-audit-plan" docs/plans/archive/pivot-hft-entry-safety-retry-visibility-plan.md`
- **Rollback**: restore the file to `docs/plans/` and its pre-Sprint status by
  reverting Sprint 1.

### Task 1.2: Replace Time Expiry With Explicit Retry-Chain State

- **Location**:
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Remove `current_micro_bar != entry_micro_bar_time` as a terminal condition in
    `PivotHftTryRearmClosedPosition`.
  - Store the minimum authoritative retry decision state needed to distinguish
    pending, transiently deferred, rearmed, disabled and terminally invalidated
    outcomes, including next public retry number/source and a bounded reason.
  - Keep sequence id, original pivot identity, retry ordinal, source identity,
    risk geometry and observed execution model intact across bars.
  - Centralize the next retry number/source calculation so frontend, logs and
    business logic cannot disagree.
  - Do not add arrays, history scans, indicator creation, random values or chart
    calls to the per-tick lifecycle path.
- **Dependencies**: `PivotHftExecutionSourceForRetry`, existing position state,
  existing pivot-price validation and single-slot helpers.
- **Acceptance criteria**:
  - A locally requested net `<= 0` close with threshold `> 0` remains eligible
    after one or more M3 transitions.
  - Threshold `0` still completes the level with no retry.
  - Profit, external/protection close and invalid source state never rearm.
  - Exactly one pending chain or active campaign/position owns the slot.
- **Validation**:
  - Static traces for threshold `0`, `1`, `2`, and `3` through retries `0..4`.
  - Static trace of broker -> virtual -> broker -> broker after losses spanning
    different micro candles.
  - `rtk grep "REARM_EXPIRED|entry_micro_bar_time|reattempt_pending|PivotHftExecutionSourceForRetry" services/trading_signals/pivot_hft_position_lifecycle.mqh services/trading_signals/pivot_hft_state.mqh`
- **Rollback**: restore the original same-fill-bar gate and remove the new retry
  decision fields/helper.

### Task 1.3: Apply The Same Terminal Lifetime As Pending Campaigns

- **Location**:
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_indicators.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
- **Description**:
  - Add one lifecycle-owned invalidation path for pending closed-position retries.
  - Invoke it on session/resource shutdown and macro pivot-set rollover, matching
    existing campaign cancellation behavior.
  - Keep pivot price/snapshot validation before every eventual rearm.
  - Treat temporary risk, daily, market, indicator, slot and managed-position
    blocks as deferred state transitions rather than completion. Avoid repeated
    per-tick logs for an unchanged reason.
  - Ensure deinit/cleanup cannot leave a closed pending retry state authoritative
    after resources are released.
- **Dependencies**: existing `PivotHftCancelPendingCampaign`, session resource
  owner, pivot refresh owner and protection/market guard APIs.
- **Acceptance criteria**:
  - No retry crosses a session/resource shutdown or macro pivot rollover.
  - Temporary blocking cannot lose the retry number or change virtual/broker
    source.
  - State compaction occurs only after a terminal decision or successful rearm.
- **Validation**:
  - Static call-order review from `OnTick` through signal resources, detection,
    execution and `PivotHftProcessAllPositions`.
  - Verify no session/pivot cancellation path sends, closes or mutates broker
    positions beyond the existing lifecycle contract.
- **Rollback**: remove pending-retry invalidation hooks and restore the previous
  lifecycle-only completion behavior.

### Sprint 1 Gate

- [x] All Sprint 1 tasks complete.
- [x] Cross-bar loss traces preserve next retry number/source.
- [x] Session and pivot rollover traces terminate the chain explicitly.
- [x] Threshold `0/1/2/3` traces remain deterministic and off-by-one free.
- [x] Single campaign/position slot and symbol/magic guards remain intact.
- [x] `rtk git diff --check` passes and the Sprint-only diff is reviewed.
- [x] Exactly one Sprint 1 commit is created with the proposed message.
- [x] The rollback point is recorded before Sprint 2 starts.

**Execution record**:

- Removed the fill-micro-bar equality gate; a pending retry now uses the current
  bar only to seed the next campaign.
- Added authoritative next retry ordinal/number/source and explicit
  pending/deferred/rearmed/disabled/invalidated state.
- Session resource shutdown and macro pivot rollover terminally invalidate
  pending retries; temporary guards retain the same retry decision.
- Static threshold traces pass for `0`, `1`, `2`, and `3`; no MetaEditor compile
  was run by design.
- Archived the prior completed plan and cleared/reinitialized disposable hook
  continuity state.
- Rollback point: `9a9a0ff`.

## Sprint 2: Make Retry Ownership And Audit Events Unambiguous

**Goal**: Give every retry chain one parseable transition history, including
replacement, deferral, invalidation and virtual model provenance.

**Dependencies**: Sprint 1 gate and commit.

**Tracked scope**:
`HFT_Grid_AI.mq5`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_detection.mqh`,
`services/trading_signals/pivot_hft_diagnostics.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`

**Commit**: `Sprint 2: make Pivot HFT retry transitions auditable`

**Demo/Validation**:

- Trace one complete chain by `run + sequence + execution_id`: initial broker
  loss, virtual retry loss, real retry loss, cross-bar real retry rearm.
- Verify every event payload has unique keys and explicit current/next sources.
- Run `rtk git diff --check` and the read-only duplicate-key parser against a
  focused log when runtime evidence becomes available.

**Rollback point**: Sprint 1 commit. Revert only Sprint 2 to restore the old
event schema and replacement logs while retaining cross-bar retry continuity.

### Task 2.1: Make Latest-Level Replacement A Terminal Retry Decision

- **Location**:
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Preserve the existing same-origin-bar latest-level replacement rule and one
    campaign slot.
  - Before overwriting a retry campaign, capture its sequence, level, public
    retry number, ordinal, source and source identity and mark the chain terminal
    with reason `latest_level_replaced` (or one equivalent canonical token).
  - Ensure replacement cannot leave a pending closed position, stale visual, or
    retry chain that later reappears.
  - Keep initial-campaign replacement behavior unchanged apart from richer audit
    identity.
- **Dependencies**: Sprint 1 retry decision state and existing
  `PivotHftReplaceCampaignIfLatestLevelChanged` ordering.
- **Acceptance criteria**:
  - The January R1 retry-2 -> R2 replacement has one explicit terminal event.
  - No queue or concurrent campaign is introduced.
  - A carried-forward campaign outside its replacement window remains latched to
    its level as before.
- **Validation**:
  - Static initial-campaign and retry-campaign replacement traces in both
    directions.
  - Verify the replacement event names both previous and next sequences/levels
    and the previous retry source.
- **Rollback**: restore direct campaign overwrite and remove replacement-specific
  retry finalization while keeping Sprint 1 continuity.

### Task 2.2: Normalize The Audit Schema And Retry Transitions

- **Location**:
  - `services/trading_signals/pivot_hft_diagnostics.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**:
  - Add an audit schema version to `RUN_START`.
  - Rename runtime/input visual fields to distinct keys such as
    `tester_visual_mode` and `visualization_input`.
  - Replace duplicate `POSITION_REARMED.execution_source` fields with explicit
    `source_execution_source` and `next_execution_source`.
  - Emit `spread_pts` only once in `VIRTUAL_FILL_REGISTERED`, keeping risk and
    execution snapshots parseable without duplicate keys.
  - Add transition-only events/fields for retry pending, deferred, rearmed,
    disabled and terminal invalidation. Include sequence, current and next retry,
    source identity, reason and relevant bar/pivot identity.
  - Retire time-only `REARM_EXPIRED` from the normal lifecycle. If retained for
    compatibility, it must not be emitted merely because the micro bar changed.
  - Keep logs bounded: emit on state/reason transition, never every tick.
- **Dependencies**: Sprint 1 state contract and existing audit prefix.
- **Acceptance criteria**:
  - Every payload key is unique within its row.
  - Every eligible non-positive finalization has exactly one subsequent rearm or
    terminal-decision event.
  - Current source and next source cannot be confused by a parser.
  - Audit changes contain no account, license, credential or private payload.
- **Validation**:
  - `rtk grep "execution_source=.*execution_source|spread_pts=.*spread_pts|visual=" HFT_Grid_AI.mq5 services/trading_signals`
  - Review all lifecycle event builders for unique keys and stable reason tokens.
  - On the later tester log, parse each row by `|` and fail if any key before `=`
    repeats in the same row.
- **Rollback**: restore prior event field names and remove the new transition
  events without reverting Sprint 1 business behavior.

### Task 2.3: Expose Virtual Execution Model Provenance

- **Location**:
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Preserve current deterministic pricing and result formulas.
  - Record that virtual entry slippage, close slippage and per-lot costs came from
    the preceding source execution, including its execution id and whether each
    observed value is valid zero or an unavailable/fallback value.
  - Fail closed or use the existing explicit fallback path when a required model
    component is non-finite; do not invent a random or arbitrary nonzero value.
  - Keep real broker history scoped by position id, symbol and runtime magic.
- **Dependencies**: existing signed slippage helpers, `OrderCalcProfit`, history
  net aggregation and source identity chain.
- **Acceptance criteria**:
  - A zero-slippage/cost tester run is labeled as observed zero.
  - A virtual chain can be traced to the real execution that calibrated it.
  - No virtual execution touches broker send/close/history or daily counters.
- **Validation**:
  - Static BUY/SELL entry and close formula review.
  - Static trace for threshold `3`, where retry 2 inherits the same calibrated
    model through retry 1 without losing the original provenance.
- **Rollback**: remove provenance fields while retaining existing deterministic
  model values and Sprint 1 continuity.

### Sprint 2 Gate

- [x] All Sprint 2 tasks complete.
- [x] Initial and retry campaign replacements have explicit terminal ownership.
- [x] Audit payload review finds no duplicate keys.
- [x] Retry decision events reconcile one-to-one with eligible finalizations.
- [x] Virtual model provenance is deterministic and broker-scoped.
- [x] No per-tick log flood, history scan or frontend authority is introduced.
- [x] `rtk git diff --check` passes and the Sprint-only diff is reviewed.
- [x] Exactly one Sprint 2 commit is created with the proposed message.
- [x] The rollback point is recorded before Sprint 3 starts.

**Execution record**:

- Latest-level replacement now records the previous and replacement campaign
  identities, retry/source ownership and terminal reason
  `latest_level_replaced`; the previous campaign is retained briefly as a
  terminal visualization snapshot without re-entering execution.
- Added schema version `2`, distinct tester/input visualization keys and bounded
  `REARM_PENDING`, `REARM_DEFERRED`, `POSITION_REARMED`, `RETRY_DISABLED` and
  `REARM_INVALIDATED` transitions.
- Removed duplicate audit keys from `POSITION_REARMED`,
  `VIRTUAL_FILL_REGISTERED` and the latent post-fill `local_sl` composition.
- Virtual model values now retain both the immediate retry predecessor and the
  original broker calibration execution, with `OBSERVED_ZERO`, observed-value,
  fallback and unavailable provenance per component.
- Static composed-event parsing reports zero duplicate keys; threshold traces
  remain deterministic for `0`, `1`, `2` and `3`. No MetaEditor compile was run
  by design.
- Rollback point: `381087f`.

## Sprint 3: Expose Retry Continuity And Complete Final Validation

**Goal**: Make the start-threshold semantics and current retry-chain state
obvious on chart, document the corrected contract, and pass the single final
MetaEditor compile.

**Dependencies**: Sprint 2 gate and commit.

**Tracked scope**:
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`,
`README.md`,
`docs/guides/pivot-hft-strategy-inputs.md`,
this plan

**Commit**: `Sprint 3: expose and validate retry-chain continuity`

**Demo/Validation**:

- Panel and chart text distinguish active broker, active virtual, close wait,
  retry pending/deferred, retry tracking, and terminal invalidation without
  relying on color.
- Documentation states `N` and later are real, never the ambiguous phrase
  `N+` when it could mean `N+1`.
- Compile the portable EA once, require zero errors and zero warnings, inspect
  and remove `BUILD.log`, then review the full three-Sprint diff.

**Rollback point**: Sprint 2 commit. Revert Sprint 3 to remove frontend/docs
changes while retaining corrected business behavior and audit events.

### Task 3.1: Render Pending, Deferred And Invalidated Retry State

- **Location**:
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
- **Description**:
  - Show the policy as `initial broker`, `virtual before RETRY N`, `broker from
    RETRY N`, and `no max while chain valid` (or equally explicit compact text).
  - Include the next public retry number and next source for a closed pending or
    deferred chain, plus a short canonical reason when blocked.
  - Reuse authoritative signal/lifecycle state. Frontend must remain read-only.
  - Briefly render terminal invalidation/replacement with words, not color alone,
    then clean objects through the existing visualization owner.
  - Preserve bounded panel rows and deterministic object names.
- **Dependencies**: Sprint 1 retry decision state and Sprint 2 reason/source
  tokens.
- **Acceptance criteria**:
  - A retry that crosses M3 remains visibly present instead of disappearing.
  - Start `2` visibly progresses `RETRY 1 VIRTUAL` -> `RETRY 2 BROKER` ->
    `RETRY 3 BROKER` after successive non-positive outcomes.
  - Replacement and session/pivot invalidation are visually distinct from a
    profit or retry-disabled completion.
- **Validation**:
  - Static rendering traces for idle, pending, deferred, virtual active, broker
    active, close wait and terminal states.
  - Verify textual state remains understandable with colors ignored.
- **Rollback**: restore the previous campaign/position-only rendering.

### Task 3.2: Correct Strategy And Audit Documentation

- **Location**:
  - `README.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - this plan
- **Description**:
  - Replace the same-fill-candle retry boundary with the session/pivot-scoped
    chain lifetime and list terminal versus transient outcomes.
  - Document exact `0`, `1`, and `N >= 2` semantics using `retry N and later`.
  - Document latest-level replacement as a terminal chain decision under the
    one-campaign rule.
  - Document the versioned, unique-key event schema, visual-mode field names and
    model provenance.
  - Update the manual QA matrix for cross-bar retry-2 and retry-3 broker cases,
    BUY/SELL, session close, pivot rollover, replacement and guard deferral.
- **Dependencies**: final Sprint 1/2 event names and frontend labels.
- **Acceptance criteria**:
  - No documentation calls the threshold a maximum or implies retry `N+1` is
    the first real retry.
  - The guide and code use the same terminal reason tokens and source labels.
- **Validation**:
  - `rtk grep "fill micro candle|REARM_EXPIRED|N\+|Start_Real_Retry|retry N" README.md docs/guides/pivot-hft-strategy-inputs.md`
  - Proofread English/Spanish semantics against threshold traces `0/1/2/3`.
- **Rollback**: restore prior docs while retaining code, then reapply corrected
  docs before any release.

### Task 3.3: Run The Single Final Compile And Handoff QA

- **Location**:
  - `HFT_Grid_AI.mq5` include graph and all Sprint-touched files
  - temporary `BUILD.log`
- **Description**:
  - Run the one portable MetaEditor compile after all code/docs edits.
  - Read the fresh log, require zero errors and warnings, then remove it.
  - Review the final diff for include changes, symbol/magic scope, broker guards,
    virtual broker-call isolation, per-tick cost, duplicate audit keys, secrets
    and unrelated changes.
  - Do not add or run an MQL5 harness, CI module or headless tester matrix.
  - Hand the documented real-tick visual matrix to the user for manual QA.
- **Dependencies**: all Sprint 3 tasks complete.
- **Acceptance criteria**:
  - Portable compile exits with zero errors and zero warnings.
  - `BUILD.log` is inspected and removed.
  - Worktree contains only intended Sprint 3 changes before commit.
- **Validation**:
  - `& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"`
  - Inspect `BUILD.log` for the final result, remove it, then run
    `rtk git status --short`, `rtk git diff --check`, and `rtk git diff`.
- **Rollback**: revert Sprint 3. If Sprint 1/2 must also be rolled back, revert
  in reverse Sprint order and recompile once after restoration.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] Frontend exposes cross-bar retry state and source without ambiguity.
- [ ] README and Spanish guide match exact `0/1/N` semantics.
- [ ] One final MetaEditor compile passes with zero errors/warnings.
- [ ] `BUILD.log` is inspected and removed.
- [ ] Final diff has no unrelated changes, secrets or private log content.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] The manual Strategy Tester matrix is handed to the user.

## Testing Strategy

- **Pure/static**:
  - Trace retry numbers `0..4` for thresholds `0`, `1`, `2`, and `3`.
  - Trace non-positive close before and after an M3 boundary.
  - Trace session close, pivot rollover, latest-level replacement, protection,
    daily limit, market status, indicator readiness and occupied-slot behavior.
  - Verify unique audit keys and one terminal/rearm decision per eligible close.
- **Integration**:
  - Correlate `run + sequence + execution_id + source_id` through campaign arm,
    entry intent, fill, local close, finalization and next retry decision.
  - Require fills to equal finalizations for broker plus virtual sources.
  - Require broker sends to equal broker fills and no broker send for virtual
    entries.
- **Manual end-to-end Strategy Tester (user-run)**:
  - Use `Every tick based on real ticks`, US30, M3 micro, H1 pivots and a focused
    date range that produces repeated losses.
  - Threshold `0`: initial broker fill; non-positive close emits disabled and no
    retry.
  - Threshold `1`: retry `1+` remains broker across multiple M3 bars.
  - Threshold `2`: retry 1 virtual, retry 2 broker, retry 3 broker after a
    retry-2 loss that closes in a later M3 candle.
  - Threshold `3`: retries 1-2 virtual, retry 3 and later broker.
  - Repeat representative BUY and SELL SL, BE, trailing, TP and entry-safety
    outcomes.
  - End a session with a pending retry and require one terminal session reason,
    no overnight rearm and no stale panel state.
  - Trigger a macro pivot rollover and require one pivot invalidation.
  - Trigger same-origin-bar latest-level replacement and require explicit old/new
    chain identity with no orphan retry.
  - Exercise spread/distance, daily, protection and market guards and distinguish
    deferred from terminal outcomes.
  - Confirm no event row contains duplicate keys and no eligible close lacks a
    retry decision.
- **Trading/security**:
  - Preserve `_Symbol` and runtime `g_magic_number` scope for all positions,
    deals, history, daily results and forced closes.
  - Preserve margin, spread, stop/freeze, session, drawdown, daily-budget,
    market-status and license guards.
  - Keep virtual paths isolated from broker send/close/history and daily counts.
- **Performance/reliability**:
  - Emit retry wait logs only when state/reason changes.
  - Add no per-tick history scan, unbounded resize, repeated indicator creation,
    chart churn or noisy `Print`.
- **Accessibility/visual**:
  - State words carry meaning without color; labels remain bounded on desktop
    tester charts.
- **Operational**:
  - No migration or dependency step.
  - Compile once at the end; user performs runtime QA afterward.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Removing fill-bar expiry creates stale overnight retries | Old levels could reopen in a later session | Explicit session/resource and pivot-rollover terminal invalidation | No pending chain after session exit or pivot refresh |
| Temporary guard is treated as terminal | Threshold still appears to cap retries | Separate deferred and invalidated states | Deferred chain keeps same next retry/source |
| Temporary guard never clears | Closed state occupies the execution slot | Bounded reason state plus terminal session/pivot cleanup | Panel/log show reason; cleanup occurs at terminal boundary |
| Retry replacement leaves an orphan | Old chain can reappear or double execute | Finalize old retry before latest-level overwrite | One replacement terminal event and one active campaign |
| Threshold off-by-one changes | Real money starts too early or too late | Keep current helper and trace `0/1/2/3` | At `2`, only retry 1 is virtual |
| Cross-bar state loses source/model identity | Virtual result or audit becomes invalid | Preserve sequence, source id and observed model snapshot | End-to-end id chain remains complete |
| Duplicate log keys break analytics | Parsers silently overwrite evidence | Unique schema keys plus duplicate-key QA | Zero duplicate keys in focused log |
| Added deferral logging floods hot path | Tester/live overhead and large logs | Log only state/reason transitions | Event count remains bounded by lifecycle changes |
| Visual state influences execution | Trading behavior regression | Frontend reads authoritative state only | No frontend symbol referenced by trading modules |
| Zero tester costs look like missing modeling | Operator assumes simulation ignored costs | Add observed/fallback provenance without invented values | Log labels observed zero with source id |
| Archive/hook cleanup removes wrong state | Continuity loss or user data deletion | Verify exact repository-local disposable paths first | Only old-plan hook files removed; Git files preserved |

## Rollback Plan

- **Sprint 1**: revert its single commit to restore the prior plan location and
  same-fill-bar retry boundary. Remove newly initialized disposable hook state
  only after verifying it points to this plan.
- **Sprint 2**: revert its single commit to restore the prior audit/replacement
  schema while retaining Sprint 1 continuity.
- **Sprint 3**: revert its single commit to restore prior frontend/docs while
  retaining Sprint 1/2 business and audit behavior.
- Revert in reverse Sprint order for a full rollback. Run the portable compile
  once after the desired rollback point, inspect zero errors/warnings, and
  remove `BUILD.log`.
- No data, migration, dependency, server configuration or license rollback is
  required.

## Execution Order

1. Read planner `references/execution-state.md`, verify and clear only stale
   repository-local hook state, then initialize fresh state for this plan.
2. Execute exactly Sprint 1, run its static gate, create exactly one Sprint 1
   commit and record the rollback point.
3. Stop the batch. This is a critical trading-sensitive plan and only one Sprint
   may run per batch.
4. On later authorization, execute Sprint 2 only after verifying Sprint 1 state,
   validation and commit; create exactly one Sprint 2 commit.
5. On later authorization, execute Sprint 3, run the only MetaEditor compile,
   remove `BUILD.log`, create exactly one Sprint 3 commit and record completion.
6. Hand the manual real-tick Strategy Tester QA matrix to the user. Do not claim
   runtime behavior passed until the user supplies that evidence.

## Completion Checklist

- [ ] Prior plan is marked completed, linked and archived.
- [ ] Old hook state is safely cleared and fresh state tracks this plan.
- [ ] Eligible retry chains survive micro-bar transitions.
- [ ] Session/resource shutdown and pivot rollover terminate stale chains.
- [ ] `Pivot_HFT_Start_Real_Retry` controls source only and never acts as max.
- [ ] Latest-level retry replacement is explicit and leaves no orphan.
- [ ] Audit rows use unique keys and explicit current/next sources.
- [ ] Virtual model zero/fallback provenance is unambiguous.
- [ ] Visual state exposes pending, deferred, real/virtual and terminal outcomes.
- [ ] Every Sprint passes its gate and has exactly one Sprint-specific commit.
- [ ] Final compile has zero errors/warnings and `BUILD.log` is removed.
- [ ] Manual Strategy Tester QA remains explicitly assigned to the user.
