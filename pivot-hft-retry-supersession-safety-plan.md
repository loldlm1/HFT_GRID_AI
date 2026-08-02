# Plan: Pivot HFT Retry Supersession And Broker Safety

**Generated**: 2026-08-02
**Status**: Sprint 1 complete; Sprint 2 pending
**Estimated Complexity**: Critical / trading-sensitive

## Overview

Harden Pivot HFT around three related contracts: exact retry identity, safe
broker-position ownership, and deterministic supersession by a deeper pivot
level.

The current virtual/broker routing helper already implements the intended
positive threshold: the initial entry is broker retry `0`, retries below a
positive `Pivot_HFT_Start_Real_Retry` value are virtual, and that retry plus
later retries are broker-real. The apparent off-by-one behavior comes primarily
from broker comments ending in `attempt_count + 1`, while the audit correctly
reports the zero-based market `retry_number`. For example, the audited
`phft_..._R2_3` position is attempt `3`, logical retry `2`, and broker-real at a
start threshold of `2`.

The behavior-changing strategy work will retain the deepest independently
admitted same-side pivot while the single execution slot is occupied. If the
owning position later closes through an eligible non-positive local outcome,
the deeper pivot will suppress the old same-level retry and become a new
initial broker campaign. It will not inherit the old level's retry ordinal or
virtual model and will not replay a stale historical entry price.

The safety work precedes the strategy change. A confirmed broker fill must
never remain unmanaged if normal local registration fails, and a restart or
recompile must either restore an exact durable lifecycle checkpoint or
quarantine and force-close the scoped broker position. `OnTester()` scoring
will remain unchanged; campaign-level audit evidence will be added before any
future scoring redesign is considered.

## Audit Baseline And Findings

Read-only evidence source, not to be copied into the repository:

`/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/query_debug.txt`

- The current file contains one `3,862`-row run from 2024-01-05 through
  2024-02-23 for US30, M3 micro bars, H1 pivots and
  `start_real_retry=2`.
- Reconciliation is exact in that run: `90` broker order sends produced `90`
  broker fills, `34` virtual fills plus `90` broker fills produced `124`
  position finalizations, and no `FILL_UNRESOLVED` event was observed.
- The first day demonstrates correct routing: initial broker entry, virtual
  retry `1`, then broker retry `2`. Broker comments use attempts (`..._1`,
  `..._2`, `..._3`), which makes the third attempt look like retry `3` even
  though the authoritative audit identifies it as retry `2`.
- Prior event reconstruction identified five deeper same-side pivot
  opportunities while another Pivot HFT lifecycle occupied the slot. Four
  were discarded and one was promoted only because same-bar timing happened
  to expose it after the slot became available.
- `OnDeinit()` clears `g_pivot_hft_positions`; `OnInit()` does not rebuild
  local SL, TP, trailing, campaign or retry ownership for an already-open
  symbol-and-magic broker position. Admission is blocked by the broker position,
  but its normal local lifecycle is no longer authoritative after restart.
- After a verified broker fill, failure of `PivotHftRegisterFilledPosition()`
  emits `FILL_UNRESOLVED` and resets the campaign without closing or managing
  the successfully opened broker position.
- `OnTester()` currently scores non-negative growth multiplied by non-negative
  Sharpe and `log(1 + trades)`. This formula is not the source of the retry
  routing or overlap defects and will remain unchanged in this plan.

## Scope

- **In scope**:
  - Force-close and reconcile a confirmed broker fill when normal local
    lifecycle registration cannot complete.
  - Consume daily-start accounting exactly once after a verified real fill,
    even when normal registration later fails.
  - Persist the minimum authoritative broker lifecycle state needed to survive
    EA restart, recompile or chart reload.
  - Restore a matching scoped broker position from a validated checkpoint, or
    enter a no-new-entry quarantine and close it when exact restoration is not
    possible.
  - Make broker comments expose logical retry number separately from execution
    attempt, while keeping audit fields authoritative.
  - Preserve exact `Pivot_HFT_Start_Real_Retry` semantics for `0`, `1` and
    every `N >= 2`.
  - Observe and retain one deepest, same-side, independently admitted pivot
    candidate while the execution slot is occupied.
  - Suppress an eligible same-level retry when a valid deeper candidate exists,
    then promote that candidate as a new initial broker campaign.
  - Persist a latched deeper candidate together with an active recovered broker
    lifecycle so a recompile does not silently change the statistical choice.
  - Add bounded campaign/recovery audit metrics, chart visibility, an offline
    audit checker and operator documentation.
  - Perform focused static validation after Sprints 1-4, then run the sole
    MetaEditor compile plus focused real-tick Strategy Tester and demo-chart
    validation in Sprint 5 before live use.
- **Out of scope**:
  - Any Fibonacci calculation, Fibonacci input, Fibonacci-derived price, or
    change to classic pivot formulas. The earlier Fibonacci wording is context
    only: retries are conceptually deeper price levels.
  - Changes to Bollinger admission, configured retracement distance, lot size,
    margin formulas, local SL/BE/trailing/TP geometry, server-side SL/TP, or
    daily-result backend contracts.
  - A retry maximum, cooldown, FIFO queue, multiple pending campaigns or
    concurrent managed positions.
  - Replaying missed ticks or creating a retroactive fill at the price where a
    deeper candidate originally appeared.
  - Recovering arbitrary manual trades, another EA's positions, legacy
    lane-magic positions, or positions outside the exact symbol and runtime
    magic scope.
  - Changing the `OnTester()` score formula or optimization objective.
  - Adding network services, dependencies, migrations, secrets or license
    contract changes.
- **Fixed decisions**:
  - The initial pivot entry is always broker-real and has logical
    `retry_number=0`.
  - `Pivot_HFT_Start_Real_Retry=0` disables same-level reentries completely.
    An independently admitted deeper pivot may still become a new initial
    broker campaign because it is a different pivot level, not a retry.
  - `Pivot_HFT_Start_Real_Retry=1` routes retry `1` and every later retry to the
    broker.
  - `Pivot_HFT_Start_Real_Retry=N >= 2` routes retries `1..N-1` virtually and
    retry `N` plus every later retry to the broker.
  - A deeper candidate must pass the same normal new-campaign admission rules
    except for the deliberately occupied execution-slot predicate. It must be
    same-side and strictly deeper than the lifecycle it may supersede.
  - Only the deepest valid candidate is retained. A strictly deeper candidate
    may replace an earlier latch; equal, shallower and opposite-side candidates
    do not.
  - The latch survives micro-bar transitions after admission and is
    grandfathered even when its admission candle later burns the level.
  - Promotion occurs only after an eligible locally requested close with net
    result `<= 0`. A positive, external/protection, session-terminal or
    pivot-invalidating outcome discards the latch.
  - Promotion creates a new sequence at the deeper level with
    `retry_ordinal=1`, `retry_number=0`, `attempt_count=0` and execution source
    `BROKER`. Supersession provenance is separate from retry provenance.
  - Promotion seeds a fresh directional extreme at promotion time and then
    follows the normal retracement and execution guards. It never executes at
    a stale historical candidate quote.
  - A confirmed broker fill consumes the applicable daily-start budget even if
    registration or checkpointing later fails.
  - Recovery is exact or fail-closed. Current bands, current price or a broker
    comment alone must not be used to guess a lost local stop or trailing state.
  - Broker comments are bounded operator hints. Symbol, runtime magic, ticket,
    position identifier, deal history and the validated checkpoint remain the
    machine authority.
  - `OnTester()` and its optimization score formula remain unchanged;
    campaign metrics are audit-only.

## Named Resources

- **Project instructions**:
  - `AGENTS.md`
  - `docs/planner-execution-discipline.md`
  - `/home/loldlm/.codex/skills/planner/references/execution-state.md`
  - `/home/loldlm/.codex/skills/mql5-production-engineering/SKILL.md`
- **Current strategy and historical decisions**:
  - `README.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - `docs/plans/archive/pivot-hft-entry-safety-retry-visibility-plan.md`
  - `docs/plans/archive/pivot-hft-retry-threshold-log-audit-plan.md`
  - `docs/plans/archive/pivot-hft-retracement-campaign-continuity-plan.md`
- **Implementation files**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals.mqh`
  - `microservices/core/enums.mqh`
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/market_status_controller.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
  - `services/trading_signals/pivot_hft_indicators.mqh`
  - `services/trading_signals/pivot_hft_risk_geometry.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_diagnostics.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
  - new `services/trading_signals/pivot_hft_recovery.mqh`
  - new `scripts/audit_pivot_hft_retry.py`
  - this plan
- **Validation resources**:
  - `C:\Program Files\MetaTrader 5-1\MetaEditor64.exe`
  - `C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5`
  - temporary `C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log`
  - terminal-common `query_debug.txt`, rotated before each focused run
  - a demo hedging account for restart/recompile and forced-close checks
- **Official MQL5 documentation**:
  - Position iteration and selection:
    <https://www.mql5.com/en/docs/trading/positiongetticket> and
    <https://www.mql5.com/en/docs/trading/positionselectbyticket>
  - Position and deal properties:
    <https://www.mql5.com/en/docs/constants/tradingconstants/positionproperties>
    and
    <https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties>
  - Position-scoped history:
    <https://www.mql5.com/en/docs/trading/historyselectbyposition>
  - `CTrade::PositionClose` and result retcode verification:
    <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclose>
    and
    <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctraderesultretcode>
  - MQL5 file sandbox, open and flush behavior:
    <https://www.mql5.com/en/docs/files/fileopen> and
    <https://www.mql5.com/en/docs/files/fileflush>
- **Operational resources**:
  - Terminal-local recovery checkpoint files under the MQL5 file sandbox,
    scoped by an opaque account/server fingerprint, symbol and runtime magic.
  - Git history with exactly one commit and one recorded rollback point per
    Sprint.
  - No database, backend, deployment or secret-management change.

## Prerequisites

- Planning discovery observed a clean worktree at commit `52e9446`; re-check
  `rtk git status` and `rtk git log -5 --oneline` immediately before execution.
- Read planner `references/execution-state.md` and initialize a small, redacted,
  untracked active-plan state before Sprint 1. Never place tickets, account
  identifiers, source dumps or audit rows in hook state.
- Execute Sprints 1-5 as one explicitly authorized contiguous batch, in order.
  Each Sprint must pass its non-compile gate and create exactly one
  Sprint-specific commit before another Sprint begins.
- Preserve the external audit file as baseline evidence. Rotate it only before
  a new focused tester or demo run and never commit it or copy private rows into
  tests.
- Confirm the portable MT5 install is flat for this EA before any rollback that
  changes recovery/checkpoint code. Never downgrade lifecycle code while a
  scoped broker position remains open.
- Run runtime trading checks first in Strategy Tester or a demo hedging account.
  No live rollout is authorized by this planning artifact.
- Use this exact compile gate once, during Sprint 5 after all code and
  documentation work is complete:

  ```powershell
  & "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
  ```

  Read the newly generated `BUILD.log`, require `0 errors, 0 warnings`, and
  remove the file before recording validation. Never reuse a stale build log.
- Before enabling new broker entries, the implementation must prove the
  terminal-local recovery store can write, flush, close and read back a scoped
  checkpoint. If the store is unavailable while flat, initialization fails
  closed. If an existing scoped position is open, the EA must remain in
  safety-only quarantine so it can close/reconcile rather than removing itself.

## Authorized Execution Overrides

The user explicitly authorized these execution-policy overrides on 2026-08-02:

- Execute Sprints 1 through 5 as one contiguous batch while preserving strict
  Sprint order and every Sprint completion gate.
- Create exactly one validated commit per Sprint before starting the next.
- Do not add MQL5 harness tests or CI modules. Use focused static review,
  existing runtime facilities, the dependency-free audit checker and manual
  Strategy Tester/demo evidence instead.
- Do not run MetaEditor after Sprints 1-4. Run one final compilation in Sprint
  5 and require zero errors and zero warnings.
- Consolidate fault-injection, restart/recompile, visual and broker-runtime
  checks for Sprints 1-4 into Sprint 5 because those checks require the compiled
  final EA. Earlier Sprint gates use reproducible static traces and diff review.

These overrides supersede the default one-Sprint critical-plan batch limit and
the original per-Sprint compile wording. They do not waive symbol/magic scope,
flat-state rollback, runtime safety, diff review or commit gates.

## Sprint 1: Fail-Close Confirmed But Unregistered Broker Fills

**Goal**: Guarantee that every confirmed Pivot HFT broker fill either enters a
normal managed lifecycle or an emergency close-and-reconciliation lifecycle.

**Dependencies**: clean baseline, existing symbol/magic fill lookup, existing
protection force-close loop and existing position-history finalization helpers.

**Tracked scope**:
`microservices/core/enums.mqh`,
`services/trading_signals/market_signal_state.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/market_status_controller.mqh`,
`services/trading_signals/protection_risk_filter.mqh`

**Commit**: `Sprint 1: fail close unresolved Pivot HFT fills`

**Demo/Validation**:

- Trace a successful `Buy`/`Sell` with a valid fill retcode and prove daily
  start accounting occurs exactly once before normal registration can fail.
- Statically trace the registration-failure branch through exact-ticket close,
  quarantine, no-retry and history reconciliation. Run the temporary
  uncommitted tester/demo fault build in Sprint 5 against the compiled final EA.
- Run focused static lifecycle traces and `rtk git diff --check`. Compilation is
  intentionally deferred to the sole Sprint 5 gate.

**Rollback point**: commit immediately preceding Sprint 1. Reverting the single
Sprint 1 commit restores the former unresolved-fill behavior; therefore rollback
is permitted only while the scoped symbol/magic is flat.

### Task 1.1: Separate Verified Fill Accounting From Normal Registration

- **Location**:
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/market_signal_state.mqh`
- **Description**:
  - Treat a filled trade retcode, non-zero deal, positive price and positive
    volume as the broker-fill boundary.
  - Register the daily broker signal start once at that boundary rather than
    only after normal local state registration.
  - Add an explicit idempotency flag or scoped helper so retries of emergency
    reconciliation cannot double-consume the daily budget.
  - Keep virtual entries excluded from daily-start and broker-history counts.
- **Dependencies**: existing `PivotHftTradeRetcodeFilled()` and
  `RegisterPivotHftDailySignalStart()` contracts.
- **Acceptance criteria**:
  - Every verified broker fill consumes one applicable daily start.
  - A rejected or unfilled send consumes none.
  - A virtual fill consumes none.
- **Validation**:
  - Static trace for broker success, broker rejection, virtual fill and
    registration failure.
  - Audit assertions in Sprint 5 must later prove broker-fill count equals
    broker daily-start events when the configured mode counts starts.
- **Rollback**: restore the prior post-registration accounting call only as part
  of a full Sprint 1 rollback while flat.

### Task 1.2: Create An Emergency Lifecycle For Registration Failure

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Add a terminal close trigger/reason for confirmed-fill registration failure.
  - Resolve the exact position ticket and identifier from the confirmed deal,
    symbol and runtime magic; never close by symbol alone.
  - If full risk/lifecycle registration fails, append the minimum emergency
    broker state needed to own and finalize the exact ticket without pretending
    that missing geometry is valid.
  - Mark it close-wait, exclude it from retry eligibility, and send a close
    through the existing broker permission and retcode checks.
  - If even emergency state creation fails, keep a bounded quarantine marker,
    request the existing scoped protection force-close path, and block all new
    campaign admission until no matching broker position remains.
- **Dependencies**: Task 1.1 and current ticket/history helpers.
- **Acceptance criteria**:
  - `FILL_UNRESOLVED` can no longer reset the campaign and leave an unmanaged
    live position.
  - Only the exact `_Symbol + g_magic_number + ticket/identifier` exposure is
    closed.
  - The failure path cannot rearm or promote another campaign.
  - Close boolean and `ResultRetcode()` are both checked and audited.
- **Validation**:
  - Temporary uncommitted fault injection after a real tester/demo fill.
  - Require one registration-failure event, one emergency close decision and
    either a confirmed close/finalization or a still-active quarantine with a
    bounded retry reason.
  - Verify another symbol or magic is untouched.
- **Rollback**: revert the close-trigger and emergency-state changes together;
  never leave a partially defined enum/state contract.

### Task 1.3: Make Emergency Close Retries Bounded And Observable

- **Location**:
  - `services/trading_signals/market_status_controller.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Reuse the existing pending force-close generation and broker-action guards
    for retryable close failures.
  - Emit state-transition events such as registration failed, emergency close
    sent, emergency close failed and exposure reconciled; do not print on every
    tick.
  - Clear quarantine only after position enumeration confirms the exact scoped
    exposure is flat and any available history outcome is reconciled.
- **Dependencies**: Task 1.2.
- **Acceptance criteria**:
  - Close-only, disabled-market and transient broker failures do not permit a
    new entry while exposure remains.
  - Repeated failure logs are time/state bounded.
  - A later successful close clears the error and quarantine deterministically.
- **Validation**:
  - Static trace through broker actions allowed, temporarily unavailable and
    permanently rejected states.
  - Verify protection filtering remains symbol-and-magic scoped.
- **Rollback**: revert only with no pending emergency close and no open scoped
  position.

### Sprint 1 Gate

- [x] All Sprint 1 tasks are complete.
- [x] The registration-failure path has a reproducible static trace; compiled
      fault-injection evidence remains explicitly deferred to Sprint 5.
- [x] Focused static lifecycle traces pass; final compilation remains deferred
      to Sprint 5 by explicit user instruction.
- [x] The diff contains no unrelated changes or unbounded logging.
- [x] Exactly one Sprint 1 commit is created with the proposed message.
- [x] The rollback point and flat-position requirement are recorded.
- [x] Sprint 2 has not started before this gate completes.

**Sprint 1 execution record**:

- Rollback point: `52e9446`; revert only while the exact symbol-and-magic scope
  is flat and no emergency close is pending.
- Static validation: broker rejection precedes the sole fill-accounting call;
  fill accounting precedes normal registration; quarantine activation precedes
  campaign reset; virtual fills never call daily-start accounting.
- Safety validation: direct close verifies symbol, runtime magic and position
  identifier; protection fallback honors an optional exact ticket/identifier;
  emergency finalization cannot rearm; quarantine blocks admission until
  broker exposure and available history reconcile.
- Reliability validation: direct and protection close attempts are bounded to
  one per second, repeated failure output is bounded to 30 seconds, braces and
  call signatures are balanced, and `git diff --check` passes.
- Deferred by explicit instruction: MetaEditor compilation and temporary
  registration-failure fault injection run once against the final Sprint 5 EA.

## Sprint 2: Persist And Recover Exact Broker Lifecycle Ownership

**Goal**: Restore an open scoped broker position with its exact local risk and
lifecycle state after restart, or keep the EA in safety-only quarantine and
force-close when exact restoration is impossible.

**Dependencies**: completed Sprint 1 emergency lifecycle and clean one-position
ownership contract.

**Tracked scope**:
`HFT_Grid_AI.mq5`, `services/trading_signals.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_risk_geometry.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
new `services/trading_signals/pivot_hft_recovery.mqh`,
`services/trading_signals/pivot_hft_diagnostics.mqh`,
`services/frontend/pivot_hft_panel.mqh`

**Commit**: `Sprint 2: recover Pivot HFT broker lifecycle state`

**Demo/Validation**:

- On a demo hedging chart, capture an active managed broker position after its
  local stop has initialized or advanced, then recompile/reload the EA and
  require one recovered state with the same ticket, identifier, geometry,
  local stop, target and trailing step.
- Repeat with a missing/corrupt checkpoint and require safety-only quarantine
  plus an exact scoped force-close, never guessed geometry.
- Run focused checkpoint/recovery static validation and `rtk git diff --check`.
  Compilation is intentionally deferred to the sole Sprint 5 gate.

**Rollback point**: the Sprint 1 commit. Before reverting Sprint 2, close all
scoped positions, verify flat state, then remove only validated checkpoint slots
for the exact account fingerprint, symbol and magic.

### Task 2.1: Add A Versioned Two-Slot Lifecycle Checkpoint

- **Location**:
  - new `services/trading_signals/pivot_hft_recovery.mqh`
  - `services/trading_signals.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_risk_geometry.mqh`
- **Description**:
  - Add a dedicated recovery module at a non-circular include point after state
    and pure risk helpers, before execution/lifecycle consumers.
  - Use terminal-local MQL5 file storage, not the shared audit log, so tester
    agents and separate terminal installations do not share lifecycle state.
  - Scope filenames with an opaque fingerprint of account/server plus
    symbol and runtime magic; do not expose account identifiers in Journal or
    audit messages.
  - Rotate between checkpoint slots A/B. Each record carries schema version,
    monotonically increasing generation, full required fields and checksum.
    Write, flush, close and read-validate the inactive slot before considering
    the generation durable. On recovery, choose the highest valid matching
    generation; no manifest or destructive overwrite is required.
  - Persist ticket and position identifier as exact strings, not lossy doubles.
  - Persist the immutable entry/risk snapshot and mutable local lifecycle:
    direction, level, pivot identity, campaign/retry identity, entry deal/time,
    price/volume, local SL/TP, trailing step, close state, safety snapshot,
    force-close generation and daily-accounting flags.
- **Dependencies**: Sprint 1 state contract and official MQL5 file sandbox
  behavior.
- **Acceptance criteria**:
  - A torn or corrupt latest slot leaves the previous valid generation usable.
  - A checkpoint from another account fingerprint, symbol, magic, ticket or
    position identifier is rejected.
  - No checkpoint write occurs on every ordinary tick; writes occur only after
    fill/recovery and material lifecycle transitions such as SL advancement or
    close-state change.
  - Checkpoint data contains no license token, credentials or private audit
    rows.
- **Validation**:
  - Round-trip each field with maximum observed ticket/identifier formatting.
  - Corrupt one slot and verify the other is selected.
  - Change magic/symbol fingerprint in a disposable test copy and verify the
    checkpoint is ignored.
- **Rollback**: remove the new include/module and checkpoint callers together,
  after positions are flat and scoped files are safely identified.

### Task 2.2: Checkpoint Every Material Broker Lifecycle Transition

- **Location**:
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**:
  - Write the first durable checkpoint immediately after normal broker state
    registration and before the campaign is considered safely complete.
  - Update the checkpoint after local SL/TP initialization, each monotonic
    trailing advance, close-trigger capture, close-send state and final history
    reconciliation.
  - Flush current state in `OnDeinit()` before clearing memory. Do not delete a
    checkpoint merely because the EA is unloading while its position remains.
  - Delete both slots only after the scoped broker position is flat and final
    history/daily outcome reconciliation has completed.
  - If a required checkpoint write/read-back fails while a broker position is
    open, enter Sprint 1 emergency quarantine and close; do not continue with
    non-durable local risk.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - A confirmed broker position is never intentionally managed without a
    validated durable checkpoint.
  - Recompile/deinit preserves the last monotonic local stop rather than
    resetting it to the initial stop.
  - File failure is fail-closed and cannot permit a new campaign.
- **Validation**:
  - Compare the last pre-deinit checkpoint generation with the first recovered
    generation and runtime state.
  - Make the state directory temporarily unwritable in a disposable tester
    environment and verify flat initialization fails closed, while an existing
    position enters quarantine instead of removing the EA.
- **Rollback**: revert only while flat; retain audit evidence outside git.

### Task 2.3: Reconcile Startup Before Enabling Signals

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/pivot_hft_recovery.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
- **Description**:
  - After successful license verification and runtime magic resolution, enumerate
    all open positions for the exact symbol and magic before enabling new signal
    resources.
  - Zero matching positions plus stale checkpoint: reconcile closed history if
    needed, then remove the stale slots.
  - One matching position plus one valid checkpoint: verify ticket, identifier,
    type, entry facts and volume, restore one authoritative position state and
    resume local lifecycle management.
  - One matching position with missing, corrupt or mismatched checkpoint: create
    an emergency close state, set recovery quarantine and force-close without
    synthesizing risk from current bands or comments.
  - Multiple matching positions: treat the one-position invariant as violated,
    quarantine and close all exact symbol-and-magic positions through the
    existing protection path; do not choose one arbitrarily.
  - Make the panel show `RECOVERED`, `RECOVERY QUARANTINE` or
    `RECOVERY CLOSE WAIT` from authoritative signal state.
- **Dependencies**: Tasks 2.1-2.2.
- **Acceptance criteria**:
  - New campaign admission cannot occur before startup reconciliation finishes.
  - An exactly restored position is represented once, not duplicated.
  - Unknown or conflicting broker exposure is closed, not adopted with guessed
    state.
  - Frontend remains read-only.
- **Validation**:
  - Demo cases: valid recovery, stale checkpoint/flat, corrupt checkpoint/open,
    and deliberately duplicated scoped positions.
  - Verify unrelated magic and symbol positions remain untouched in every case.
- **Rollback**: flatten all scoped positions and remove only the exact recovery
  files before reverting Sprint 2.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks are complete.
- [ ] Static startup traces preserve exact lifecycle state for a valid record
      and choose quarantine/scoped force-close for missing or corrupt state.
- [ ] Compiled restart/corruption demo evidence remains explicitly deferred to
      Sprint 5.
- [ ] Focused checkpoint/recovery static validation passes; final compilation
      remains deferred to Sprint 5 by explicit user instruction.
- [ ] Checkpoint writes are transition-bounded and privacy-reviewed.
- [ ] Exactly one Sprint 2 commit is created with the proposed message.
- [ ] The rollback point and checkpoint cleanup procedure are recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Make Retry Threshold And Broker Identity Unambiguous

**Goal**: Preserve the already-correct routing policy while ensuring broker
comments, panel state and audit fields cannot confuse attempts with retries.

**Dependencies**: completed safety and recovery foundation; no change to
`OnTester()` scoring.

**Tracked scope**:
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_diagnostics.mqh`,
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`

**Commit**: `Sprint 3: clarify Pivot HFT retry identity`

**Demo/Validation**:

- Trace thresholds `0`, `1`, `2` and `3` across retry numbers `0..4` and prove
  the source matrix is exact.
- Confirm broker comments show logical retry `0`, `1`, `2`, etc., while audit
  retains an independent execution-attempt field.
- Run retry-policy/comment diff and static checks. Compilation is intentionally
  deferred to the sole Sprint 5 gate.

**Rollback point**: the Sprint 2 commit. Sprint 3 can be reverted while flat or
with a recovered position because recovery does not use the new comment as its
sole authority; retain backward-compatible display handling.

### Task 3.1: Centralize The Retry Policy Contract

- **Location**:
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Keep one canonical conversion from internal ordinal to market retry number
    and one canonical execution-source decision.
  - Make same-level reentry eligibility explicit and separate from source
    routing so threshold `0` cannot accidentally be interpreted as broker retry
    `0+`.
  - Preserve initial broker retry `0`; for positive thresholds use an inclusive
    broker boundary.
  - Ensure every rearm, panel and audit caller uses the same resolved decision.
- **Dependencies**: current `PivotHftMarketRetryNumber()` and
  `PivotHftExecutionSourceForRetry()` behavior.
- **Acceptance criteria**:
  - Threshold `0`: initial broker only; no same-level campaign rearm.
  - Threshold `1`: retries `1+` broker.
  - Threshold `2`: retry `1` virtual; retries `2+` broker.
  - Threshold `3`: retries `1-2` virtual; retries `3+` broker.
- **Validation**:
  - A small deterministic table in code review or the Sprint 5 audit checker;
    no broker call should contain independent threshold arithmetic.
  - `rtk grep "Start_Real_Retry|ExecutionSourceForRetry|MarketRetryNumber"` and
    inspect every trading call site.
- **Rollback**: restore the previous helpers and callers together; do not leave
  duplicated threshold logic.

### Task 3.2: Version The Bounded Broker Comment Around Logical Retry

- **Location**:
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_recovery.mqh`
- **Description**:
  - Replace the attempt-only suffix with a compact versioned format that names
    direction, pivot level and logical retry, including `R0` for an initial
    pivot entry. Keep it within the broker-supported bounded comment length.
  - Retain `attempt_count` in audit fields and virtual execution ids, where it
    is clearly labeled as an attempt.
  - Treat broker truncation/modification as expected. Recovery may use a valid
    comment as corroborating evidence but must require its checkpoint and
    broker/deal identity checks.
  - Continue recognizing the old comment form only as a legacy hint; never
    infer exact lost lifecycle state from it.
- **Dependencies**: Task 3.1 and Sprint 2 recovery authority.
- **Acceptance criteria**:
  - An initial R3 position is visibly retry `0`, not apparent retry `1`.
  - The third R2 attempt at logical retry `2` is visibly retry `2`, not retry
    `3`.
  - Broker comment and audit retry number agree whenever the broker preserves
    the comment.
- **Validation**:
  - Generate comments for long epoch values, R1/R2/R3 and retry values with at
    least two digits; assert bounded length and unambiguous tokens.
  - Compare comment retry against `ORDER_SEND_RESULT.retry_number` in a focused
    log.
- **Rollback**: restore the old builder while retaining recovery's refusal to
  trust comments alone.

### Task 3.3: Align Panel And Audit Terminology

- **Location**:
  - `services/trading_signals/pivot_hft_diagnostics.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
- **Description**:
  - Use `INITIAL`, `RETRY N`, `BROKER` and `VIRTUAL` consistently.
  - Show attempt only when diagnostically useful and label it explicitly.
  - Add a clear threshold `0` panel phrase: same-level retries disabled; deeper
    independently admitted pivots remain eligible as new initial campaigns.
  - Keep state meaning available in text, not color alone.
- **Dependencies**: Tasks 3.1-3.2.
- **Acceptance criteria**:
  - Chart, audit and broker history no longer present contradictory retry
    numbering.
  - Frontend code does not influence campaign or lifecycle state.
- **Validation**:
  - Visual tester inspection for threshold `0`, `2` and `3`.
  - Static include-direction review confirms trading modules do not reference
    frontend state.
- **Rollback**: revert display/audit wording independently only if it remains
  compatible with the active comment and policy schema.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks are complete.
- [ ] Threshold `0/1/2/3` matrix is exact.
- [ ] Broker comments and audit retry numbers agree.
- [ ] `OnTester()` score logic is unchanged.
- [ ] Retry-policy/comment static validation passes; final compilation remains
      deferred to Sprint 5 by explicit user instruction.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] The rollback point is recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Supersede Same-Level Retries With Deeper Pivot Campaigns

**Goal**: Preserve the deepest valid same-side pivot admission while occupied
and promote it instead of opening a statistically stale retry at the shallower
level.

**Dependencies**: exact recovery/checkpoint ownership and unambiguous retry
identity from Sprints 1-3.

**Tracked scope**:
`HFT_Grid_AI.mq5`, `microservices/core/enums.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_levels.mqh`,
`services/trading_signals/pivot_hft_detection.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_recovery.mqh`,
`services/trading_signals/pivot_hft_indicators.mqh`,
`services/trading_signals/pivot_hft_diagnostics.mqh`,
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`

**Commit**: `Sprint 4: supersede retries with deeper pivot campaigns`

**Demo/Validation**:

- Reproduce a same-side R2 lifecycle while R3 independently qualifies. Require
  the R3 candidate to remain latched across M3 transitions, the eligible R2
  retry to be suppressed after a non-positive local close, and R3 to promote as
  a new broker initial campaign.
- Repeat symmetrically for S2/S3 and test candidate replacement R1 -> R2 -> R3.
- Inspect the complete Sprint diff and focused traces for one-slot and guard
  preservation. Compilation is intentionally deferred to Sprint 5.

**Rollback point**: the Sprint 3 commit. Revert Sprint 4 only while flat and
after clearing any persisted supersession candidate through the versioned
recovery cleanup path.

### Task 4.1: Add One Authoritative Supersession Candidate

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
- **Description**:
  - Add a small explicit state struct for one candidate: validity, direction,
    level, level price, pivot-set identity, admission bar/time, owning
    execution/campaign identity and terminal reason.
  - Add explicit same-side depth comparison helpers instead of relying on raw
    enum ordering across resistance and support families.
  - Add retry state/reason support for `SUPERSEDED` without treating it as a
    loss/profit class.
  - Provide deterministic latch, replace, discard, promote and reset helpers.
- **Dependencies**: current pivot snapshot and level availability contracts.
- **Acceptance criteria**:
  - At most one candidate exists.
  - R3 is deeper than R2/R1 for bearish campaigns; S3 is deeper than S2/S1 for
    bullish campaigns.
  - Equal, shallower, opposite-side and invalid pivot-set candidates cannot
    overwrite the latch.
- **Validation**:
  - Static depth table for R1-R3 and S1-S3.
  - Constructor/reset review proves no stale candidate survives initialization
    accidentally.
- **Rollback**: remove enum/state/helpers together after persisted state is
  cleared while flat.

### Task 4.2: Observe Deeper Admission Without Opening A Second Campaign

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
- **Description**:
  - Split normal admission context into the existing full new-campaign gate and
    a candidate-admission gate that differs only by excluding the occupied-slot
    predicate.
  - While one Pivot HFT lifecycle owns the slot, evaluate the same session,
    resources, data, band, pivot, direction, protection, market, spread and
    daily admission conditions that a new campaign would require.
  - If the current micro close independently admits a strictly deeper same-side
    available level, latch it without creating a campaign, entry intent, daily
    consumption or broker request.
  - Update only on meaningful state changes; do not rescan history or log each
    tick. The existing level-history cache remains authoritative.
  - If a deeper level appears while a same-level retry campaign is already
    tracking and the slot is flat, replace that retry campaign immediately with
    a new initial deeper campaign. Do not broaden replacement of unrelated
    initial campaigns beyond the existing policy.
- **Dependencies**: Task 4.1 and existing admission helpers.
- **Acceptance criteria**:
  - Candidate observation cannot open a second position or pending campaign.
  - The admitted candidate survives later micro bars even when its original
    touch becomes burned.
  - Existing spread, session, protection, daily, market and indicator guards
    are not bypassed.
  - No full-history scan or indicator-handle creation is added to the tick hot
    path.
- **Validation**:
  - Trace candidate qualification with each admission guard false in turn.
  - Confirm no `ORDER_SEND_RESULT`, daily start or second campaign occurs at
    latch time.
  - Performance review of the added per-tick branch.
- **Rollback**: remove observation before removing candidate state.

### Task 4.3: Promote The Candidate Before Same-Level Rearm

- **Location**:
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
- **Description**:
  - At finalization, preserve the existing retry-eligible definition: locally
    requested, non-external close and net result `<= 0`.
  - Before setting same-level `reattempt_pending`, validate a latched candidate
    against the stored pivot-set identity and terminal session/resource rules.
  - If valid, mark the old level's next retry `SUPERSEDED`, prevent
    `POSITION_REARMED` for that retry, finalize the old lifecycle and promote
    the candidate as a distinct initial broker campaign.
  - Record supersession provenance separately from `retry_source_id` so the new
    campaign remains retry `0` while still identifying the displaced level and
    execution.
  - Seed a fresh directional extreme and require normal retracement, daily,
    margin, spread, broker status and protection checks before broker entry.
  - Apply the same rule when `Pivot_HFT_Start_Real_Retry=0`: suppress no
    same-level retry because none is allowed, but still promote the deeper new
    pivot campaign.
- **Dependencies**: Tasks 4.1-4.2 and Sprint 3 route contract.
- **Acceptance criteria**:
  - One non-positive R2 outcome cannot produce both R2 retry and R3 initial.
  - Promoted R3 is `retry_number=0`, `BROKER`, with a new sequence and fresh
    risk geometry when it eventually triggers.
  - No old virtual slippage/cost model is inherited as if R3 were an R2 retry.
  - A positive or external/protection close discards the candidate and produces
    no promotion.
- **Validation**:
  - BUY and SELL traces for loss, flat/BE, profit and external close.
  - Threshold `0`, `1`, `2` and `3` traces prove promoted deeper entries are
    always initial broker campaigns.
  - Confirm one blocking lifecycle/campaign throughout each transition.
- **Rollback**: revert promotion and finalization changes as one unit while flat.

### Task 4.4: Persist And Invalidate The Latch Correctly

- **Location**:
  - `services/trading_signals/pivot_hft_recovery.mqh`
  - `services/trading_signals/pivot_hft_indicators.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
- **Description**:
  - Extend the checkpoint schema backward-compatibly with candidate fields;
    older valid Sprint 2 records recover with no candidate rather than failing
    open.
  - Persist latch/replace/discard transitions when tied to an active broker
    lifecycle.
  - Discard on positive completion, external/protection close, session/resource
    shutdown, pivot-set rollover/change or explicit recovery quarantine.
  - Show the current candidate and its owning level in read-only panel/chart
    state, including terminal discard or promotion reason.
- **Dependencies**: Tasks 4.1-4.3 and Sprint 2 checkpoint versioning.
- **Acceptance criteria**:
  - Recompile with active R2 plus latched R3 restores both exactly.
  - Session or pivot invalidation emits one discard and leaves no later R3
    promotion.
  - Panel state cannot change trading authority.
- **Validation**:
  - Demo restart with active broker position and candidate.
  - Session close and macro rollover cases.
  - Backward checkpoint read using a Sprint 2 schema fixture with no candidate.
- **Rollback**: flatten, clear candidate/checkpoint state, then revert Sprint 4.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks are complete.
- [ ] Static R2-to-R3 and S2-to-S3 traces supersede non-positive outcomes.
- [ ] Static positive/external/session/pivot traces discard the latch.
- [ ] Static threshold `0` trace permits deeper initial promotion but no
      same-level retry.
- [ ] Checkpoint schema/recovery review preserves a latch attached to an active
      broker lifecycle; compiled restart evidence remains deferred to Sprint 5.
- [ ] Supersession static and lifecycle trace validation passes; final
      compilation remains deferred to Sprint 5 by explicit user instruction.
- [ ] Exactly one Sprint 4 commit is created with the proposed message.
- [ ] The rollback point is recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Campaign Auditability, Documentation And Release QA

**Goal**: Make routing, recovery and supersession statistically auditable
without changing tester scoring, then complete focused regression evidence and
operator guidance.

**Dependencies**: completed behavior and safety Sprints 1-4.

**Tracked scope**:
`services/trading_signals/pivot_hft_diagnostics.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_recovery.mqh`,
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`,
new `scripts/audit_pivot_hft_retry.py`, `README.md`,
`docs/guides/pivot-hft-strategy-inputs.md`, this plan

**Commit**: `Sprint 5: audit and document Pivot HFT supersession`

**Demo/Validation**:

- Run the final MetaEditor compile with zero errors/warnings and remove
  `BUILD.log`.
- Run a focused `Every tick based on real ticks` matrix for thresholds
  `0`, `1`, `2` and `3`, including the 2024-01-05 first-day window and a
  repeatable deeper-overlap window.
- Run the offline checker against the new log and require zero routing,
  orphan-lifecycle, duplicate-transition and supersession invariant failures.
- Perform demo restart, corrupt-checkpoint and unresolved-fill close tests before
  considering live rollout.

**Rollback point**: the Sprint 4 commit. Sprint 5 runtime diagnostics can be
reverted independently; a full rollback of earlier lifecycle Sprints still
requires flat state and recovery-file cleanup in reverse order.

### Task 5.1: Add A Versioned Campaign And Recovery Audit Summary

- **Location**:
  - `services/trading_signals/pivot_hft_diagnostics.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - relevant event emitters in execution, lifecycle, detection and recovery
- **Description**:
  - Bump the audit schema and keep event payload keys unique.
  - Add bounded run counters for initial broker fills, virtual retries, broker
    retries, deeper candidates latched/replaced/discarded/promoted, same-level
    retries suppressed, recovery restores/quarantines, emergency closes and
    reconciliation failures.
  - Emit explicit transition events with old/new level, sequence, execution id,
    candidate admission bar, logical retry, attempt and canonical reason.
  - Emit one `RUN_SUMMARY` before `RUN_END`; counters are diagnostic only and
    cannot feed entry decisions or `OnTester()`.
  - Redact account/server fingerprint and recovery file path details from audit
    rows beyond a non-sensitive status label.
- **Dependencies**: Sprints 1-4 event contracts.
- **Acceptance criteria**:
  - Each promoted candidate has exactly one latch and one promote event.
  - Each suppressed retry has no corresponding broker/virtual fill.
  - Each broker fill is normal-managed or emergency-managed, never neither.
  - Audit failures do not change trading decisions.
- **Validation**:
  - Duplicate-key scan on every new event family.
  - Reconcile summary counters against raw event counts for one focused run.
- **Rollback**: restore prior audit schema and remove counters without touching
  trading state.

### Task 5.2: Add A Dependency-Free Offline Audit Checker

- **Location**: new `scripts/audit_pivot_hft_retry.py`
- **Description**:
  - Build a Python-standard-library CLI that accepts an explicit audit file and
    optional run id; never hard-code or copy private logs.
  - Validate threshold routing, comment/audit retry agreement when comments are
    preserved, fill/finalization reconciliation, one lifecycle per broker fill,
    emergency-close closure, candidate transition cardinality and absence of a
    suppressed retry fill.
  - Report aggregate counts and the first bounded set of violations, not full
    raw rows or credentials.
  - Include a `--self-test` mode with synthetic, non-private event lines for
    parser and invariant coverage.
- **Dependencies**: Task 5.1 schema.
- **Acceptance criteria**:
  - Exit `0` only when all selected-run invariants pass; non-zero on malformed
    schema or behavioral violations.
  - Handles the current schema-2 baseline as read-only legacy input and the new
    schema as authoritative validation.
  - Uses no third-party package or network access.
- **Validation**:
  - `python3 scripts/audit_pivot_hft_retry.py --self-test`
  - `python3 scripts/audit_pivot_hft_retry.py --file <rotated-query-debug-path> --run-id <focused-run>`
- **Rollback**: delete the standalone script; no runtime rollback required.

### Task 5.3: Document Exact Strategy And Recovery Semantics

- **Location**:
  - `README.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - this plan's execution record during implementation
- **Description**:
  - Document the exact `0/1/N` retry boundary and distinguish retry number from
    attempt number with broker-comment examples.
  - State explicitly that no Fibonacci logic is used or planned.
  - Document deeper-level candidate admission, deepest-only replacement,
    cross-bar persistence, non-positive promotion, positive/external discard,
    fresh retracement and threshold `0` deeper-initial behavior.
  - Document checkpoint authority, safety-only quarantine, emergency fill close,
    local file location class, cleanup and flat-state rollback requirement.
  - Preserve the statement that `OnTester()` scoring is unchanged and that any
    campaign-based scoring redesign requires a separate evidence-driven plan.
- **Dependencies**: final behavior from Sprints 1-4.
- **Acceptance criteria**:
  - Operator docs contain no ambiguous phrase such as "after retry N" where
    "from retry N inclusive" is intended.
  - Docs do not imply a deeper candidate is entered at its historical touch
    price.
  - Recovery docs do not expose account or license data.
- **Validation**:
  - `rtk grep "Fibonacci|Start_Real_Retry|supersed|recovery|OnTester" README.md docs/guides/pivot-hft-strategy-inputs.md`
  - Proofread examples against the code matrix and audit checker.
- **Rollback**: revert docs with the Sprint 5 commit.

### Task 5.4: Execute The Final Tester And Demo Matrix

- **Location**:
  - portable MetaEditor/MT5 installation
  - rotated terminal-common `query_debug.txt`
  - `scripts/audit_pivot_hft_retry.py`
- **Description**:
  - Compile the exact portable EA and remove the inspected build log.
  - Use `Every tick based on real ticks` for timing-sensitive tester cases.
  - Run demo-only restart and forced safety cases that cannot be proven by a
    normal tester pass.
  - Record pass/fail evidence and remaining broker-dependent risk without
    committing raw private logs.
- **Dependencies**: Tasks 5.1-5.3.
- **Acceptance criteria**:
  - Threshold `0`: initial broker; no same-level retry; independently admitted
    deeper pivot may promote as broker retry `0`.
  - Threshold `1`: same-level retries `1+` broker.
  - Threshold `2`: retry `1` virtual; retries `2+` broker; comments and audit
    agree.
  - Threshold `3`: retries `1-2` virtual; retries `3+` broker.
  - R2/S2 non-positive plus latched R3/S3: old retry suppressed, deeper initial
    promoted once.
  - Positive, external, session-close and pivot-rollover outcomes discard the
    latch once.
  - Restart with valid checkpoint restores the exact local stop/trailing state.
  - Missing/corrupt checkpoint or forced registration failure closes exact
    scoped exposure and blocks new entries until flat.
  - Broker fills plus virtual fills reconcile to finalizations, with no orphan
    emergency lifecycle.
  - `OnTester()` source formula remains unchanged.
- **Validation**:
  - MetaEditor command from `AGENTS.md` using the exact portable paths.
  - Inspect `BUILD.log` for `0 errors, 0 warnings`, then remove it.
  - Run the audit checker and retain only its aggregate pass/fail summary.
- **Rollback**: if any safety case fails, do not roll out live; revert the
  failing Sprint while flat or update this plan before continuing.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks are complete.
- [ ] Audit schema and offline checker pass their focused validation.
- [ ] Documentation matches exact implemented semantics.
- [ ] MetaEditor compile reports zero errors and zero warnings.
- [ ] `BUILD.log` is inspected and removed.
- [ ] Strategy Tester threshold/supersession matrix passes.
- [ ] Demo restart and fail-close matrix passes.
- [ ] `OnTester()` scoring remains unchanged.
- [ ] Exactly one Sprint 5 commit is created with the proposed message.
- [ ] Final residual risks and rollout/rollback instructions are recorded.

## Testing Strategy

- **Pure/static**:
  - Trace ordinal-to-retry and threshold routing for retry numbers `0..5` and
    thresholds `0`, `1`, `2`, `3` and a larger `N`.
  - Trace resistance/support depth comparisons and candidate replacement.
  - Verify every position/deal/close/recovery path filters symbol, runtime magic,
    ticket and position identifier as applicable.
  - Verify `OnTester()` source is unchanged.
- **Compile**:
  - Compile once in Sprint 5 with the MetaEditor command in `AGENTS.md`.
  - Treat warnings as failures, inspect the current `BUILD.log`, then remove it.
- **Integration**:
  - Correlate `run + sequence + execution_id + position_id` through send, fill,
    checkpoint, close and finalization.
  - Correlate displaced execution/level to candidate latch, suppressed retry and
    promoted new sequence.
  - Require every verified broker fill to be normal-managed or emergency-managed.
- **Strategy Tester**:
  - Use `Every tick based on real ticks`, representative BUY/SELL chains and
    discrete thresholds.
  - Re-run the first-day 2024-01-05 scenario used for the screenshots and a
    window with deeper-level overlap.
  - Verify no second position/campaign, stale entry replay or guard bypass.
- **Demo broker lifecycle**:
  - Recompile/reload during one managed position before and after trailing
    advances.
  - Corrupt/delete one checkpoint slot, then both, and confirm fallback versus
    quarantine behavior.
  - Exercise broker close failure/temporary disabled mode and eventual retry.
- **Security/privacy**:
  - Recovery files contain strategy state only, use scoped hashed filenames and
    never contain license keys or credentials.
  - Audit and CLI summaries do not print account/server identity or full raw rows.
- **Performance/reliability**:
  - No new full-history scan, repeated indicator creation, unbounded array growth
    or per-tick file write.
  - Candidate logs and checkpoint writes occur only on state transitions.
- **Frontend/accessibility**:
  - Recovery, retry source and supersession remain understandable through text,
    not color alone; chart rendering remains non-authoritative.
- **Operational**:
  - Test and demo first; require flat state before checkpoint-schema rollback.
  - No migration, dependency or backend rollout is required.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Confirmed fill cannot be registered | Live exposure has no local SL/trailing owner | Emergency state, exact-ticket close, quarantine and protection retry | Every broker fill is normal- or emergency-managed |
| Daily budget counted only after registration | A real failed-registration fill can exceed daily policy | Consume once at verified-fill boundary | Fill and daily-start counts reconcile |
| Checkpoint is torn or stale | Wrong local stop may be restored | Two slots, generation, checksum, read-back and broker identity validation | Highest valid matching generation selected |
| Recovery store is unavailable | New live positions would be non-durable | Preflight while flat; safety-only quarantine when exposure exists | No broker entry while storage unhealthy |
| Comment is truncated or broker-modified | Recovery or audit identity could be wrong | Comment is hint only; checkpoint, deal and position identity are authoritative | Recovery succeeds without comment reliance |
| Multiple scoped positions exist | One-position contract is already violated | Quarantine and close all exact scoped positions | No arbitrary adoption or new entry |
| Candidate gate bypasses normal risk guards | Deeper level gains unfair admission | Reuse every normal admission predicate except occupied slot | Guard-false matrix produces no latch |
| Burned level erases a valid latch | Cross-bar deeper opportunity is lost again | Grandfather the already admitted candidate | Latch survives its admission candle close |
| Stale candidate enters at old price | Delayed execution distorts risk/statistics | Fresh extreme and normal retracement after promotion | No order at historical candidate quote |
| Old retry and deeper initial both execute | Duplicate exposure and invalid statistics | Finalize/suppress old retry before promotion | One campaign and one fill path only |
| Threshold `0` blocks deeper new pivots | Different pivot levels are incorrectly treated as retries | Separate same-level retry eligibility from new-level promotion | R2 loss may promote admitted R3 as retry `0` |
| Threshold off-by-one regresses | Real money begins one retry early/late | One canonical route helper plus discrete matrix | At threshold `2`, only retry `1` is virtual |
| Candidate survives terminal event | Stale campaign can reopen later | Explicit positive/external/session/pivot/recovery discard | One terminal discard and no later promotion |
| Checkpoint write floods hot path | Latency and disk wear increase | Write only material lifecycle transitions | No ordinary-tick writes in audit |
| Rollback reads incompatible state | Old code mismanages an open position | Backward reader plus flat-only lifecycle rollback | Flat state and scoped cleanup before revert |
| Metrics influence trading or tester score | Observability changes strategy behavior | Diagnostics-only counters; unchanged `OnTester()` | No diagnostic symbol in admission/execution decisions |

## Rollback Plan

- Never roll back Sprints 1, 2 or 4 while an exact symbol-and-magic broker
  position is open. First stop new entries, close/reconcile exposure, verify
  flat state and identify the scoped checkpoint slots.
- **Sprint 5**: revert its single commit to remove schema/counters, checker and
  docs while retaining implemented safety and supersession behavior.
- **Sprint 4**: while flat, clear the persisted candidate through the active
  cleanup path, then revert its single commit to restore pre-supersession retry
  behavior.
- **Sprint 3**: revert its single commit to restore prior comments/display and
  routing call structure. Recovery must continue treating comments as hints.
- **Sprint 2**: while flat, remove only validated recovery slots for the exact
  scope, then revert its single commit to remove checkpoint/recovery behavior.
- **Sprint 1**: while flat and with no emergency close pending, revert its single
  commit to restore the former post-fill path.
- For a full rollback, revert Sprints in reverse order, compile the resulting EA,
  inspect zero errors/warnings, remove `BUILD.log`, and repeat the baseline
  no-position startup check.
- No database, backend, license, secret or dependency rollback is required.

## Execution Order

1. Read planner `references/execution-state.md`, initialize redacted active-plan
   state and verify the clean baseline.
2. Execute Sprint 1. Run its focused non-compile validation, create exactly one
   Sprint 1 commit and record its rollback point.
3. Continue Sprints 2, 3 and 4 in written order. For each Sprint, verify the
   prior commit, run the focused non-compile gate and create exactly one commit.
4. Execute Sprint 5 last, including the sole MetaEditor compile, audit checker,
   available tester/demo validation and exactly one Sprint 5 commit.
5. Never skip a Sprint gate or mix a later Sprint's implementation into an
   earlier Sprint commit unless it is strictly required for correctness and
   recorded in the execution notes.
6. Do not claim runtime completion until both the real-tick tester matrix and
   demo restart/fail-close matrix pass.
7. Do not roll out live merely because compilation passes; record residual
   broker-specific risks and obtain explicit rollout authorization.

## Completion Checklist

- [ ] Every confirmed broker fill becomes normal-managed or emergency-managed.
- [ ] Daily-start accounting occurs exactly once per verified broker fill.
- [ ] Restart restores exact broker lifecycle state or quarantines and closes.
- [ ] Checkpoint storage is versioned, scoped, validated and transition-bounded.
- [ ] Broker comments distinguish logical retry from execution attempt.
- [ ] Threshold `0`, `1` and `N >= 2` semantics match the fixed contract.
- [ ] No Fibonacci calculation or related strategy logic is added.
- [ ] One deepest same-side candidate survives occupied micro bars.
- [ ] Eligible non-positive outcomes suppress the old retry and promote the
  deeper level once as broker retry `0`.
- [ ] Positive/external/session/pivot outcomes discard the candidate.
- [ ] Threshold `0` disables same-level retry but permits a deeper new initial.
- [ ] Audit metrics and the offline checker reconcile every focused run.
- [ ] `OnTester()` scoring remains unchanged.
- [ ] Every Sprint passes its validation gate and has exactly one commit.
- [ ] The sole Sprint 5 build log is inspected and removed.
- [ ] Final Strategy Tester and demo safety matrices pass before live rollout.
