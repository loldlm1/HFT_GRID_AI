# Plan: Pivot HFT Entry Safety And Retry Visibility

**Generated**: 2026-08-02
**Status**: Implementation complete through Sprint 4; manual Strategy Tester QA
pending user
**Estimated Complexity**: Critical / trading-sensitive
**Execution Policy**: One authorized contiguous batch for Sprints 1-3, with one
statically validated commit per Sprint and one MetaEditor compile after Sprint
3. Sprint 4 is a separate one-Sprint trading-sensitive batch with one final
compile and one commit. Strategy Tester QA is deferred to the user after
implementation.

## Overview

Harden Pivot HFT against positions whose local SL is already reached immediately
after a market fill, while making same-fill-candle retries and broker-close
reconciliation unambiguous on the chart and in `query_debug.txt`.

The January 6 audit found no orphaned lifecycle state: all 46 fills had matching
local closes and finalizations. The failure mode was instead a local SL of
`25.56` points competing with spread plus fill slippage, followed by repeated
same-candle rearm. The panel also counted `CLOSE_WAIT` as `Active`, which made a
server-closed ticket look live until the next reconciliation tick.

The implementation will add a fail-closed entry-distance policy before order
send, a second check against the actual fill and fresh close-side quote, and
explicit retry/close-wait visualization. It will preserve the existing
admission-latched retry contract: an eligible negative or flat local close may
rearm inside its fill candle without another Bollinger or pivot-side admission
test.

Sprint 4 extends that completed safety work with a bounded retry policy per
pivot level. The initial entry remains attempt zero; the public retry number is
zero-based relative to the internal campaign ordinal, so internal ordinal `2`
is displayed and audited as market retry `1`.

## Scope

- **In scope**:
  - Refresh broker stop/freeze constraints before a Pivot HFT entry attempt.
  - Require the requested initial local SL to cover current spread plus the
    existing buffered broker-distance helper.
  - Block unsafe order sends without silently widening the configured risk.
  - Revalidate the actual fill against a fresh close-side quote and fail safe
    through the owned local-close lifecycle when slippage invalidates the
    pre-send calculation.
  - Preserve and expose same-fill-candle retry state without requiring price to
    retouch the original pivot.
  - Separate live positions from `CLOSE_WAIT` in the panel and object labels.
  - Extend bounded audit/config fields for deterministic Strategy Tester QA.
  - Add a non-negative maximum market-retry input per admitted pivot level.
  - Align audit and frontend retry numbers so the first re-entry is `RETRY 1`.
  - Update the active strategy guide and README behavior summary.
- **Out of scope**:
  - Server-side SL/TP, pending orders, lot sizing, or account-risk sizing.
  - A retry cooldown, delay, simulated/paper retry, or skipped-retry model.
  - Changes to pivot admission, Bollinger calculations, latest outer-level
    replacement, winning-level consumption, session filters, daily budgets,
    protection, license, symbol/magic scope, or single-flight ownership.
  - Include-pipeline changes, new helper files, external dependencies, CI, a
    headless Strategy Tester matrix, or a custom test harness.
- **Fixed decisions**:
  - Entry safety is fail-closed. The EA must not increase the requested SL
    distance automatically because that would silently increase monetary risk.
  - The pre-send minimum is:

    ```text
    broker_floor_points = EffectiveBrokerDistancePoints(
      g_symbol_constraints, 0.0, 1.0)
    required_initial_sl_points = current_spread_points + broker_floor_points
    ```

    `EffectiveBrokerDistancePoints` already resolves the strictest of broker
    stops/freeze levels and adds a one-tick safety buffer, including its current
    conservative fallback when the broker reports zero.
  - `Max_Spread` remains the broad liquidity guard. The new entry-distance guard
    is a separate, stricter viability check tied to the resolved local SL.
  - Broker stops/freeze values are used as a conservative EA safety floor. The
    SL remains local and is not submitted as a server SL.
  - After a verified fill, use the actual position entry price plus a fresh
    `MqlTick`; do not assume the cached pre-send quote still represents the
    executable close side.
  - A post-fill distance failure closes through
    `pivot_hft_position_lifecycle.mqh`, receives its own close-trigger label,
    and remains eligible for the existing same-fill-candle rearm rules.
  - A rearmed campaign tracks a fresh directional extreme from the post-close
    quote. It does not require another pivot touch or live Bollinger-side test.
  - Rearm preserves the admitted campaign sequence id and increments its retry
    ordinal; it does not create a logically unrelated pivot campaign.
  - `Pivot_HFT_Max_Retries_Per_Level = 0` allows only the initial market entry;
    `N > 0` allows market retries `1..N` after their preceding non-positive
    locally requested closes.
  - Negative retry limits fail initialization. The default is `1`, matching the
    requested first-retry behavior while preventing unbounded same-level churn.
  - The existing internal ordinal remains `1` for the initial entry and `2` for
    the first retry. User-facing audit/frontend fields derive
    `retry_number = max(0, retry_ordinal - 1)`.
  - Frontend state remains read-only and cannot influence trading decisions.
- **Assumptions**:
  - The existing one-tick buffered broker helper is the approved safety margin;
    no public buffer input is required for this focused correction.
  - Legitimate rapid retries can still occur up to the configured per-level
    maximum; no time cooldown is introduced.
  - The portable MetaEditor install and the user-provided real-tick US30 history
    remain available during implementation validation.

## Named Resources

- **Project instructions**:
  - `AGENTS.md`
  - `docs/planner-execution-discipline.md`
- **Current behavior and contracts**:
  - `docs/plans/archive/pivot-hft-retracement-campaign-continuity-plan.md`
  - `docs/plans/archive/pivot-hft-volatility-sl-tp-plan.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - `README.md`
- **Business and lifecycle implementation**:
  - `HFT_Grid_AI.mq5`
  - `microservices/core/enums.mqh`
  - `microservices/utils/broker_constraints_helper.mqh` (reuse; avoid changing
    unless implementation proves an existing helper defect)
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_risk_geometry.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
- **Frontend implementation**:
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
- **Validation resources**:
  - `TERMINAL_COMMONDATA_PATH\Files\query_debug.txt`
  - `C:\Program Files\MetaTrader 5-1\MetaEditor64.exe`
  - `HFT_Grid_AI.mq5`
- **Official MQL5 documentation**:
  - Symbol properties, including `SYMBOL_TRADE_STOPS_LEVEL`,
    `SYMBOL_TRADE_FREEZE_LEVEL`, `SYMBOL_POINT`, and tick properties:
    <https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants>
  - `SymbolInfoInteger` error-aware property lookup:
    <https://www.mql5.com/en/docs/marketinformation/symbolinfointeger>
  - `CTrade::PositionClose` and trade-result verification:
    <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclose>
- **Operational resources**: no migrations, secrets, backend changes, feature
  flags, or new dependencies.

## Prerequisites

- Confirm `rtk git status --short` is clean or isolate unrelated user changes.
- Read `C:\Users\loldlm\.codex\skills\planner\references\execution-state.md`
  and initialize the redacted active-plan state before Sprint 1 implementation.
- Preserve the January 6 audit file outside git as the behavioral baseline; do
  not copy private/full logs into the plan or hook state.
- Do not add an MQL5 harness or CI module for this plan.
- Execute Sprints 1-3 in order inside the authorized batch. Complete each
  Sprint's static gate and commit before touching the next Sprint.
- Run MetaEditor only once, after Sprint 3 implementation. The user will rotate
  `query_debug.txt` and execute the documented Strategy Tester QA afterward.

## Sprint 1: Fail-Closed Pre-Send Entry Distance

**Goal**: Prevent a Pivot HFT market order when its requested local SL cannot
leave spread plus a buffered broker-distance margin on the close side.

**Dependencies**: clean baseline, current broker helper contract, current
retracement-continuity behavior.

**Tracked scope**:
`HFT_Grid_AI.mq5`, `services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_risk_geometry.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`

**Commit**: `Sprint 1: block unsafe pivot hft entry distances`

**Demo/Validation**:

- Statically trace a narrow band-based SL through the new guard and verify the
  blocked path cannot reach `Buy`/`Sell`, fill registration, or daily-signal
  registration.
- Reserve runtime evidence for the user-run Strategy Tester matrix after the
  final Sprint 3 compile.

**Rollback point**: the commit immediately preceding Sprint 1; rollback is a
revert of the single Sprint 1 commit.

### Task 1.1: Resolve An Auditable Entry-Safety Snapshot

- **Location**:
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_risk_geometry.mqh`
- **Description**:
  - Add the minimum state required to retain requested SL, current spread,
    broker stops, broker freeze, buffered broker floor, and required SL points
    for the current entry attempt.
  - Reuse `EffectiveBrokerDistancePoints`; do not duplicate stop/freeze math.
  - Keep band width, initial SL, trailing step, and fixed TP geometry immutable
    and unchanged. The safety snapshot evaluates viability; it does not clamp
    those values.
  - Treat invalid point/tick values or an unavailable broker-constraint refresh
    as a fail-closed entry-safety result with an actionable reason.
- **Dependencies**: `SymbolTradingConstraints`, `g_points_spread`, current
  `PivotHftRiskGeometry` resolution.
- **Acceptance criteria**:
  - BUY and SELL use the same point-distance policy.
  - The required SL equals fresh spread plus the buffered max stop/freeze floor.
  - No allocation, history scan, indicator access, or chart operation is added
    to the entry hot path.
- **Validation**:
  - Review formulas against `SYMBOL_POINT` and `SYMBOL_TRADE_TICK_SIZE`.
  - `rtk grep "EffectiveBrokerDistancePoints|required_initial_sl|entry_safety" services\trading_signals`
  - `rtk git diff --check`
- **Rollback**: remove only the new safety snapshot fields/helper and restore
  the previous pure risk-geometry contract.

### Task 1.2: Enforce The Guard Before Buy/Sell

- **Location**:
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**:
  - Refresh `g_symbol_constraints` immediately before evaluating the final entry
    distance, using the existing refresh helper and a Pivot HFT context label.
  - Resolve risk geometry, then block before `Buy`/`Sell` when
    `initial_sl_points < required_initial_sl_points`.
  - Return the campaign to tracking through the existing retryable-entry path;
    do not reset the admitted pivot or require a new pivot touch.
  - Emit one bounded `ENTRY_RISK_DISTANCE_BLOCKED` row per blocked intent with
    direction, level, attempt, requested SL, required SL, spread, stops, freeze,
    broker floor, tick size, and reason.
  - Extend the startup `CONFIG` row with `max_spread`, daily-limit values, and
    the initial stop/freeze snapshot so future audits can reconstruct the guard.
  - Do not call `RegisterPivotHftDailySignalStart` unless a fill is verified.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - Unsafe geometry sends no broker request and creates no local position state.
  - Safe geometry follows the unchanged raw entry/fill-registration path.
  - Spread, margin, market status, session, daily budget, direction, and
    single-flight guards retain their current order and fail-closed behavior.
- **Validation**:
  - Inspect the call path from `PivotHftEntryIntentReady` through guard, risk
    geometry, safety distance, `Buy`/`Sell`, and daily-start registration.
  - Confirm statically that a blocked intent has no path to
    `ORDER_SEND_RESULT`, `FILL_REGISTERED`, or daily-start registration.
  - Defer compilation to the single final Sprint 3 gate and runtime evidence to
    the user's manual Strategy Tester QA.
- **Rollback**: restore the prior execution path and `CONFIG` payload; keep no
  partially used safety fields.

### Sprint 1 Gate

- [x] All Sprint 1 tasks complete.
- [x] Static blocked-entry validation passes and the deferred runtime scenario
  is documented for user QA.
- [x] The diff shows no risk widening, new input, include change, or unrelated
  cleanup.
- [x] Residual risks are documented.
- [x] Exactly one Sprint 1 commit is created with the proposed message.
- [x] The rollback point is recorded.
- [x] Sprint 2 starts only after this gate and commit complete.

**Execution record**:

- Static checks: entry-distance guard precedes `Buy`/`Sell` and daily-start
  registration; formula is spread plus `EffectiveBrokerDistancePoints(...,
  0.0, 1.0)`; `rtk git diff --check` passed.
- Runtime/compile: intentionally deferred under the authorized execution
  override; MetaEditor runs once after Sprint 3 and the user runs tester QA.
- Rollback point: `c540a49` (revert the Sprint 1 commit).

## Sprint 2: Post-Fill Safety And Explicit Retry Lifecycle

**Goal**: Detect rare slippage/gap cases that invalidate the pre-send distance,
close them through the owned lifecycle, and rearm a clearly identified retry
without a pivot retouch.

**Dependencies**: Sprint 1 gate and commit.

**Tracked scope**:
`microservices/core/enums.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_detection.mqh`

**Commit**: `Sprint 2: reconcile post-fill safety and retry state`

**Demo/Validation**:

- A safe fill remains active and follows unchanged TP/trailing/SL behavior.
- A fill whose actual entry-to-close-side buffer is below the broker floor is
  closed once with the new entry-safety trigger and fully finalized.
- A non-positive eligible close produces a retry campaign in the same fill
  candle, with a fresh extreme and threshold, even when price is inside the band
  or across the original pivot.

**Rollback point**: the Sprint 1 commit; rollback is a revert of the single
Sprint 2 commit while retaining pre-send protection.

### Task 2.1: Revalidate The Actual Fill Before Normal Management

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**:
  - Add one explicit close trigger such as
    `PIVOT_HFT_CLOSE_TRIGGER_ENTRY_SAFETY` and its stable audit label. Append
    the enum value without renumbering existing close-trigger constants.
  - Store the pre-send safety snapshot on the verified position state.
  - On the first lifecycle pass after registration, obtain one fresh `MqlTick`
    and calculate remaining stop buffer from the actual fill/local SL to Bid for
    BUY or Ask for SELL.
  - Evaluate entry safety before fixed TP, trailing, and the normal local SL.
    When the remaining buffer is below the buffered broker floor, capture the
    entry-safety trigger and use `PivotHftClosePositionLocally`; do not add a
    second close implementation.
  - Log `FILL_ENTRY_DISTANCE_INVALID` with ticket, fill, fresh quote, local SL,
    actual spread, available buffer, required broker floor, and the immutable
    risk geometry.
  - Preserve symbol/magic ticket ownership, retcode checks, close retry, history
    aggregation, and final net classification.
- **Dependencies**: Sprint 1 safety snapshot.
- **Acceptance criteria**:
  - A post-fill safety failure cannot be mislabeled as ordinary `INITIAL_SL`.
  - At most one managed broker position exists and at most one close request is
    active for its ticket.
  - Every accepted close still requires history-backed `POSITION_FINALIZED`.
  - No server SL/TP is introduced.
- **Validation**:
  - Trace BUY and SELL formulas and confirm the opposite-side quote is used.
  - Trace `PositionClose` boolean plus `ResultRetcode` validation.
  - Correlate `FILL_REGISTERED` -> `FILL_ENTRY_DISTANCE_INVALID` ->
    `LOCAL_CLOSE_SENT` -> `POSITION_FINALIZED` for one ticket.
  - `rtk git diff --check`
- **Rollback**: remove the new trigger and first-pass check while leaving Sprint
  1's pre-send block intact.

### Task 2.2: Make Rearm State Explicit And Preserve Its Contract

- **Location**:
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
- **Description**:
  - Record the source ticket and retry ordinal on a campaign created by
    `PivotHftTryRearmClosedPosition`.
  - Keep the existing same-fill-micro-bar boundary, unchanged-pivot identity
    check, single-flight gate, session, daily budget, protection, and market
    status checks.
  - Initialize the rearmed campaign extreme from the current entry-side quote
    and calculate the next threshold from that extreme. Do not reapply
    Bollinger-side admission or require the quote to retouch the pivot.
  - Preserve current latest outer-level replacement behavior.
  - Extend `POSITION_REARMED` with source ticket, retry ordinal, extreme, next
    threshold, and `admission=latched`.
  - Ensure an entry-safety close is eligible to rearm only after its position is
    history-finalized; never open a replacement while the previous ticket is in
    `CLOSE_WAIT`.
- **Dependencies**: Task 2.1 and the archived retracement-continuity contract.
- **Acceptance criteria**:
  - A negative/flat eligible close visibly creates retry state before any new
    pivot touch.
  - A fresh directional retracement can trigger the retry while price remains
    away from the original pivot.
  - A changed pivot set, changed fill candle, external/protection close, or
    failed lifecycle gate still prevents rearm exactly as today.
- **Validation**:
  - Static trace: finalization -> `reattempt_pending` -> rearm guards -> campaign
    creation -> extreme update -> entry intent.
  - Statically verify that price can remain inside the band/across the pivot
    after loss and still progress from `POSITION_REARMED` to a later
    `ENTRY_TRIGGERED` from the fresh extreme.
  - Defer compilation to the single final Sprint 3 gate and runtime evidence to
    the user's manual Strategy Tester QA.
- **Rollback**: revert retry metadata/audit changes and the entry-safety trigger
  as one Sprint 2 unit; Sprint 1 remains independently deployable.

### Sprint 2 Gate

- [x] All Sprint 2 tasks complete.
- [x] Safe-fill and post-fill-invalid paths are statically validated.
- [x] Retry-without-retouch paths and both directional formulas are statically
  reviewed; runtime evidence remains in the user QA matrix.
- [x] Ownership and state transitions statically prevent duplicate tickets,
  orphan state, or replacement during `CLOSE_WAIT`.
- [x] Exactly one Sprint 2 commit is created with the proposed message.
- [x] The rollback point is recorded.
- [x] Sprint 3 starts only after this gate and commit complete.

**Execution record**:

- Static checks: post-fill safety runs before fixed TP, trailing, and local SL;
  BUY uses `Bid - local_sl`, SELL uses `local_sl - Ask`; the close routes only
  through `PivotHftClosePositionLocally` with the appended `ENTRY_SAFETY`
  trigger.
- Rearm checks: history finalization precedes `POSITION_REARMED`; the admitted
  sequence is preserved, retry ordinal/source ticket are explicit, and the
  fresh entry-side quote seeds the next threshold without Bollinger readmission.
- Runtime/compile: intentionally deferred under the authorized execution
  override; MetaEditor runs once after Sprint 3 and the user runs tester QA.
- Rollback point: `506a965` (revert the Sprint 2 commit).

## Sprint 3: Visual Clarity, Documentation, And Final Validation

**Goal**: Make live, close-wait, safety-blocked, and retry states visually
unambiguous, then document and validate the complete correction.

**Dependencies**: Sprint 2 gate and commit.

**Tracked scope**:
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`,
`HFT_Grid_AI.mq5`, `README.md`,
`docs/guides/pivot-hft-strategy-inputs.md`, and this plan only when recording
implementation completion status/evidence

**Commit**: `Sprint 3: expose and validate safe pivot hft retries`

**Demo/Validation**:

- The panel distinguishes `Live`, `CloseWait`, and campaign retry ordinal.
- A safety-blocked campaign shows requested versus required SL and does not look
  like a live position.
- Position and campaign chart labels identify `CLOSE WAIT`, `RETRY TRACKING`,
  and `RETRY ENTRY READY` without affecting execution.
- The full EA compiles once with zero errors and warnings. The January 6-style
  real-tick regression remains documented for the user's manual QA.

**Rollback point**: the Sprint 2 commit; rollback is a revert of the single
Sprint 3 commit, leaving both business-safety Sprints intact.

### Task 3.1: Render Distinct Lifecycle And Retry States

- **Location**:
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
- **Description**:
  - Replace the combined `Active` count with separate live-position and
    `CLOSE_WAIT` counts.
  - Prefix position detail rows with `LIVE` or `CLOSE WAIT`.
  - When campaign retry ordinal is greater than one, render `RETRY N TRACKING`
    or `RETRY N ENTRY READY`, plus the source ticket when available.
  - Show the current safety snapshot compactly: requested SL, required SL,
    spread, and broker floor. Mark a blocked intent as `RISK BLOCKED`, not as a
    position.
  - Include retry ordinal in campaign pivot/extreme/threshold object labels.
  - Preserve current object names, bounded updates, visual/non-visual gating,
    cleanup, and the rule that chart state never enters trading decisions.
- **Dependencies**: Sprint 1 safety snapshot and Sprint 2 retry metadata.
- **Acceptance criteria**:
  - A server-closed ticket in local reconciliation is visibly `CLOSE WAIT`, not
    merely `Active`.
  - A rearmed campaign is visible immediately after finalization, before any
    new pivot touch.
  - Completed tickets and obsolete dynamic objects disappear on the next normal
    visualization sync.
- **Validation**:
  - Statically inspect rendered strings for live, close-wait, retry tracking,
    retry ready, and risk-blocked states.
  - Verify non-visual guards and deinit/session cleanup paths for panel text and
    `PIVOT_HFT_` objects. Runtime screenshots remain user QA.
  - `rtk git diff --check`
- **Rollback**: restore the previous panel strings/object labels without
  touching Sprint 1-2 trading state.

### Task 3.2: Document And Run The Final Gate

- **Location**:
  - `README.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - `HFT_Grid_AI.mq5` only for compile repair or final bounded config fields
  - `docs/plans/pivot-hft-entry-safety-retry-visibility-plan.md` only for status
    and validation evidence during execution
- **Description**:
  - Document the entry-safety formula, fail-closed behavior, post-fill safety
    trigger, same-fill-candle retry semantics, and frontend labels.
  - State clearly that stop/freeze values form a conservative local-EA floor;
    SL/TP remain absent on the server.
  - Document the then-residual risk that valid rapid retries remained possible
    because Sprints 1-3 added no cap/cooldown. Sprint 4 supersedes the cap part
    while retaining the no-cooldown behavior.
  - Run the single final compile and hand off the real-tick matrix below for the
    user's manual QA. Do not copy the private/full log into git.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Documentation matches implemented formulas and event names exactly.
  - Full compile has zero errors and zero warnings.
  - Static ownership and lifecycle review supports one finalization per fill,
    with no duplicate ticket path or outstanding replacement during close wait.
  - The unsafe January 6 geometry and forced-slippage cases are explicitly
    included in the user-run QA matrix.
- **Validation**:
  - Compile command:

    ```powershell
    & "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
    ```

  - Inspect `BUILD.log`, require zero errors/warnings, then remove it.
  - `rtk git diff --check`
  - `rtk git status --short`
  - Inspect the Sprint-only diff for symbol/magic scope, retcodes, hot-path work,
    audit redaction, frontend-only reads, and cleanup.
- **Rollback**: revert the Sprint 3 commit. If a compile-only repair touched a
  business file, confirm the revert leaves Sprint 1-2 compiling before handoff.

### Sprint 3 Gate

- [x] All Sprint 3 tasks complete.
- [x] The single final compile passes; the manual QA matrix is handed off to the
  user without claiming runtime evidence.
- [x] `BUILD.log` and temporary tester artifacts are removed.
- [x] Documentation and audit event names match implementation.
- [x] Final diff contains no unrelated changes, secrets, private log content, or
  new dependency.
- [x] Exactly one Sprint 3 commit is created with the proposed message.
- [x] The final rollback point is recorded.

**Execution record**:

- Static checks: panel separates `Live` and `CloseWait`; retry/source and
  requested/required safety labels are read-only frontend state; object names,
  non-visual gating, and cleanup remain unchanged.
- Compile: portable MetaEditor generated the EA with `0 errors, 0 warnings` in
  `8870 ms`; `BUILD.log` was inspected and removed. The default non-portable
  data folder lacked `Include\\Trade\\Trade.mqh`, so it was not valid compile
  evidence for this portable installation.
- Runtime QA: intentionally not run. The guide contains the user-run real-tick
  matrix, including the January 6 narrow-SL regression profile.
- Rollback point: `50ff942` (revert the Sprint 3 commit).

## Sprint 4: Bound Market Retries Per Pivot Level

**Goal**: Let the operator cap real market retries for one admitted pivot level
without changing initial admission, local-close classification, or audit
sequence ownership.

**Dependencies**: Sprint 3 gate and commit; existing same-fill-candle rearm,
single-flight ownership, daily budgets, and local-close lifecycle.

**Tracked scope**:
`services/trading_management/ea_inputs.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_detection.mqh`,
`services/trading_signals/pivot_hft_execution.mqh`,
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`, `HFT_Grid_AI.mq5`,
`README.md`, `docs/guides/pivot-hft-strategy-inputs.md`, and this plan.

**Commit**: `Sprint 4: bound pivot hft retries per level`

**Demo/Validation**:

- `0` finalizes a non-positive initial close without `POSITION_REARMED`.
- `1` permits exactly market retry `1`; a second rearm is blocked.
- `2` permits market retries `1` and `2`; a third rearm is blocked.
- The panel and bounded audit payloads call internal ordinal `2` `RETRY 1`.
- The EA compiles once with zero errors and warnings. Runtime evidence remains
  the user's manual real-tick Strategy Tester QA.

**Rollback point**: the Sprint 3 commit; rollback is a revert of the single
Sprint 4 commit.

### Task 4.1: Add And Enforce The Retry Limit

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**:
  - Add `Pivot_HFT_Max_Retries_Per_Level` as a non-negative `int`, default `1`.
  - Keep the initial market entry outside the retry budget. Derive public retry
    number `0` for the initial entry and `retry_ordinal - 1` afterward.
  - At finalization of an eligible non-positive local close, rearm only when
    the next public retry number is at most the configured maximum.
  - When exhausted, complete the existing level lifecycle and emit one bounded
    `RETRY_LIMIT_REACHED` event with sequence, ticket, current/next retry,
    configured maximum, direction, level, and net result.
  - Preserve positive-result ladder consumption, external/protection close
    behavior, same-fill-candle expiry, pivot-set validation, daily limits,
    symbol/magic scope, and single-flight ownership.
  - Add the configured maximum to `CONFIG`; reject negative values during
    `OnInit` before trading resources become active.
- **Acceptance criteria**:
  - `0`, `1`, and `N` mean initial-only, first retry, and retries `1..N`.
  - Exhaustion sends no market request, creates no campaign, and consumes no
    daily signal start.
  - No simulated retry, hidden ordinal advance, history scan, or per-tick log is
    introduced.
- **Validation**:
  - Statically trace initial ordinal `1`, retry ordinal `2`, and the next-retry
    comparison for limits `0`, `1`, and `2`.
  - Search every assignment/read of `retry_ordinal` and confirm the legacy
    sequence contract remains intact.
  - `rtk git diff --check`
- **Rollback**: remove the input, helper, exhaustion branch, config field, and
  validation while restoring unconditional eligible rearm.

### Task 4.2: Align Retry Audit, Visuals, Docs, And Final Gate

- **Location**:
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
  - `README.md`
  - `docs/guides/pivot-hft-strategy-inputs.md`
  - this plan
- **Description**:
  - Add derived `retry_number` to campaign, trigger, fill, rearm, retryable, and
    limit audit rows while retaining `retry_ordinal` for backward correlation.
  - Render the first re-entry as `RETRY 1`, not internal ordinal `2`, and show
    the configured maximum in the existing panel without feeding frontend state
    back into execution.
  - Document exact `0`, `1`, and `N` semantics, default, same-candle boundary,
    and absence of cooldown.
  - Run the one final portable MetaEditor compile, inspect the fresh log, remove
    `BUILD.log`, review the Sprint-only diff, and create one Sprint 4 commit.
- **Acceptance criteria**:
  - Audit consumers can distinguish internal ordinal from public retry number.
  - Frontend labels and docs match the input semantics exactly.
  - Full compile has zero errors and zero warnings; no harness, CI module, or
    headless tester matrix is added.
- **Validation**:
  - `rtk grep "retry_number|RETRY_LIMIT_REACHED|Max_Retries" HFT_Grid_AI.mq5 services README.md docs\\guides`
  - Compile the portable EA once, inspect `BUILD.log`, require zero
    errors/warnings, and remove the log.
  - `rtk git diff --check`
  - Review symbol/magic scoping, daily-start placement, lifecycle completion,
    frontend-only reads, bounded logging, and unrelated changes.
- **Rollback**: revert the Sprint 4 commit, restoring unlimited eligible
  same-candle retries and the previous ordinal labels.

### Sprint 4 Gate

- [x] All Sprint 4 tasks complete.
- [x] Static `0`, `1`, and `2` retry-limit traces pass.
- [x] The single final compile passes with zero errors and warnings.
- [x] `BUILD.log` is inspected and removed.
- [x] Documentation and audit/frontend retry numbers match implementation.
- [x] Final diff contains no unrelated changes, secrets, private log content,
  harness, CI module, or new dependency.
- [x] Exactly one Sprint 4 commit is created with the proposed message.
- [x] Runtime real-tick QA is explicitly handed to the user.

**Execution record**:

- Static checks: internal ordinal `1` maps to initial retry number `0`; limits
  `0`, `1`, and `2` block next retry numbers `1`, `2`, and `3` respectively.
  Exhaustion completes the level before campaign creation or daily-start
  registration.
- Audit/frontend: public `retry_number` is emitted alongside the preserved
  `retry_ordinal`; the panel and chart labels render internal ordinal `2` as
  `RETRY 1` and show the configured maximum.
- Compile: portable MetaEditor generated the EA with `0 errors, 0 warnings` in
  `10480 ms`; `BUILD.log` was inspected and removed.
- Runtime QA: intentionally not run. The guide now includes the user-run
  real-tick matrix for retry limits `0`, `1`, and `2`.
- Rollback point: `fc62b98` (revert the Sprint 4 commit after it is created).

## Testing Strategy

- **Pure/static checks**:
  - Review point/tick conversions and BUY/SELL close-side formulas.
  - Verify the safety floor uses spread plus buffered max(stops, freeze), not a
    max that would omit spread.
  - Verify no risk value is silently widened and the retry limit is applied
    only after an eligible finalized close.
  - Trace retry limits `0`, `1`, and `2` against internal ordinals `1..4`.
- **Integration**:
  - Correlate entry intent, safety decision, broker send, fill registration,
    local close, history finalization, and retry creation by run/ticket.
  - Require equal fill/finalization counts after the tester run.
- **End-to-end/manual Strategy Tester (user-run after implementation)**:
  - Use `Every tick based on real ticks`, US30, visual mode, micro M3, pivot M30,
    retracement `50`, band SL percent `6.25`, step ratio `1.5`, and fixed TP
    ratio `5.0` as the January 6 regression profile.
  - Unsafe pre-send case: expect `ENTRY_RISK_DISTANCE_BLOCKED` and no order.
  - Safe entry case: expect normal fill and unchanged local SL/BE/trailing/TP.
  - Post-fill slippage case when reproducible: expect one `ENTRY_SAFETY` close,
    one finalization, then visible retry tracking.
  - Retry-away-from-pivot case: after a negative close, keep price inside the
    band/across the pivot and confirm a fresh retracement can trigger.
  - Close-delay case: panel shows `CloseWait 1`, `Live 0`, then clears after
    history finalization.
  - Repeat representative BUY and SELL cases.
  - Retry-limit matrix: with the same losing setup, confirm `0` has no rearm,
    `1` has only `RETRY 1`, and `2` can reach `RETRY 2` but not `RETRY 3`.
- **Security/trading scope**:
  - Verify every position/deal/history lookup remains scoped to `_Symbol` and
    runtime `g_magic_number`.
  - Verify logs contain no account, license, credential, or private payload.
- **Performance**:
  - Broker constraint refresh occurs only on an entry attempt.
  - Fresh post-fill tick lookup occurs only after a verified fill.
  - No per-tick history scan, allocation loop, noisy log, or chart churn is
    introduced.
- **Accessibility/visual QA**:
  - Ensure labels are readable against the existing chart theme and do not rely
    on color alone; state words must carry the distinction.
- **Migration/operations**:
  - No data migration or deployment step.
  - Inspect and remove `BUILD.log` after the single final compile. The user will
    rotate `query_debug.txt` before manual QA.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Safety floor blocks more trades than `Max_Spread` alone | Lower trade count | Log requested/required components and preserve campaign tracking | Blocked event with no broker send |
| Automatic SL widening increases money risk | Critical drawdown change | Explicitly block; never clamp the SL | Requested SL remains immutable |
| Broker constraints change after `OnInit` | Stale floor | Refresh immediately before entry attempt | Audit row shows current stops/freeze |
| Fill slippage invalidates a safe preview | Position can still open too close to SL | Fresh post-fill tick and lifecycle-owned safety close | `FILL_ENTRY_DISTANCE_INVALID` chain |
| Post-fill safety close loops into repeated fills | Churn and costs | Pre-send floor, fresh retry retracement, same-candle boundary, existing budgets; record as residual risk | No repeated unsafe fills in regression profile |
| Retry appears to require a pivot retouch | Misleading QA and missed defect reports | Explicit retry metadata, threshold line, and away-from-pivot scenario | `POSITION_REARMED` then `ENTRY_TRIGGERED` away from pivot |
| Retry limit is off by one | Extra or missing market position per level | Keep internal ordinal, derive public retry number once, and trace `0/1/2` | No rearm at `0`; last fills are `RETRY 1` and `RETRY 2` for limits `1` and `2` |
| `CLOSE_WAIT` looks live | Operator confusion | Separate panel counts/status words | `Live 0 | CloseWait 1` screenshot |
| Frontend state leaks into execution | Trading regression | Read-only rendering from authoritative state | No frontend symbol referenced by trading modules |
| New event payload becomes noisy | Tester/log overhead | Emit only on state transition/attempt, never per tick | Bounded event counts |

## Rollback Plan

- **Sprint 1**: revert its single commit to restore the original pre-send risk
  behavior and remove all unused safety snapshot fields/config keys.
- **Sprint 2**: revert its single commit to remove post-fill safety trigger and
  retry metadata while retaining Sprint 1's pre-send block.
- **Sprint 3**: revert its single commit to restore prior frontend/docs while
  retaining both business-safety Sprints.
- **Sprint 4**: revert its single commit to restore unlimited eligible retries
  and the previous internal-ordinal frontend labels while retaining Sprints
  1-3.
- After any rollback, compile with the portable MetaEditor command, inspect
  zero errors/warnings, remove `BUILD.log`, and run `rtk git status --short`.
- There are no migrations, persisted schemas, server settings, or dependencies
  requiring a separate rollback.

## Execution Order

1. Read planner `references/execution-state.md` and initialize redacted active
   plan state.
2. Implement Sprint 1, run its static gate, and create exactly one Sprint 1
   commit.
3. Advance to Sprint 2 only after the Sprint 1 gate and commit; repeat the
   static gate and one-commit discipline.
4. Advance to Sprint 3 only after the Sprint 2 gate and commit.
5. Run the only MetaEditor compile after all Sprint 3 implementation, inspect
   zero errors/warnings, remove `BUILD.log`, and create the Sprint 3 commit.
6. Mark implementation complete and hand the documented Strategy Tester matrix
   to the user for manual QA.
7. Extend the completed plan with Sprint 4, execute that single
   trading-sensitive Sprint, compile once, commit once, and return the expanded
   retry-limit matrix to the user for manual QA.

## Completion Checklist

- [x] Unsafe entry distance is blocked without risk widening.
- [x] Actual fills are revalidated and unsafe fills use the explicit safety
  close trigger.
- [x] Eligible negative/flat closes rearm within the fill candle without pivot
  retouch or live-band readmission.
- [x] Live, close-wait, retry, and risk-blocked states are visually distinct.
- [x] Static lifecycle review is complete; fill/finalization reconciliation is
  explicitly deferred to the user's Strategy Tester QA.
- [x] Every Sprint has passed its validation gate.
- [x] Every Sprint has exactly one Sprint-specific commit.
- [x] Final compile has zero errors/warnings and `BUILD.log` is removed.
- [x] Residual rapid-retry risk and rollback instructions are current.
- [x] Market retries are bounded by the non-negative per-level input.
- [x] Public retry numbering starts at `1` while preserving internal ordinals.
- [x] Sprint 4 passes static validation, final compile, diff review, and commit.
