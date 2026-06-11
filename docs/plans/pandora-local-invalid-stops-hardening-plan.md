# Plan: Pandora Local Invalid Stops Hardening

**Generated**: 2026-06-10
**Estimated Complexity**: Critical / Trading-Sensitive

## Overview

Harden the current Pandora local/market execution mode so broker stop, spread,
and freeze constraints do not unnecessarily prevent a valid deterministic local
entry from attaching to a real broker market position.

This plan intentionally excludes real broker pending orders
(`BUY_STOP`, `SELL_STOP`, `BUY_LIMIT`, `SELL_LIMIT`). The EA should continue to
use the current local trigger and market `Buy/Sell` path. The source of truth
for Pandora SL/TP/trailing remains the deterministic local entry or the later
real broker fill. Broker-side SL/TP remains an extra protection layer that may
start exact, wide, pending, or temporarily absent, then tighten toward the exact
local targets when broker rules allow it.

The core change is to stop treating `TRADE_RETCODE_INVALID_STOPS` as a final
unrecoverable broker-open failure when the market order itself is otherwise
valid. Instead, the EA should pre-check broker SL/TP candidates, avoid sending a
known invalid SL/TP request, and prefer a deterministic fallback sequence:
exact broker stops, widened broker-safe stops, then market open without initial
broker SL/TP followed by post-fill stop synchronization.

## Confirmed Scope

- Keep the existing local/market execution model.
- Do not implement real pending orders in this plan.
- Preserve Pandora local SL/TP/trailing as the source of truth.
- Preserve magic-number, symbol, comment, session, daily budget, protection,
  market-status, spread, margin, volume, and license guards.
- Treat local guardrails and request-construction failures as pre-send
  limitations. Broker retcodes, including market closed, trading disabled,
  invalid volume, no money, invalid fill, and close-only/disabled states, are
  authoritative only when returned by `OrderSend`.
- Treat broker stop/freeze/spread limitations as operable constraints whenever
  there is still a valid, scoped, market-open execution path.
- Only the final Sprint runs the MetaEditor compile and related BUILD.log error
  review, per the current user instruction.

## Confirmed Execution Decisions

- A short-lived broker position with no initial server SL/TP is acceptable only
  after `OrderCheck` proves exact and widened SL/TP candidates fail because of
  invalid stops, while the market request without SL/TP is otherwise valid.
  Local SL/TP remains active immediately in EA state, and broker protection is
  synchronized as soon as it becomes legal.
- Invalid-stops recovery is Pandora-only in this plan. Non-Pandora grid market
  opens keep their current behavior unless explicitly changed later.
- Invalid-stops recovery resolves in the same tick through the deterministic
  candidate cascade: exact broker SL/TP -> widened broker-safe SL/TP -> market
  open without initial broker SL/TP -> post-fill broker stop synchronization.
- Invalid volume reported by `OrderCheck` is repairable once in the same tick by
  refreshing symbol constraints and recalculating/renormalizing volume. The
  resulting request is still sent so `OrderSend` remains the broker source of
  truth.

## Retcode Policy

### Same-Tick Repair Candidates

- `TRADE_RETCODE_INVALID_STOPS`: try exact SL/TP, widened SL/TP, then no initial
  broker SL/TP if the no-stop market request passes `OrderCheck`.
- `TRADE_RETCODE_INVALID_VOLUME`: refresh symbol constraints and recalculate
  normalized volume once. If the repaired request still fails, stop.
- `TRADE_RETCODE_INVALID_FILL`: optionally select a broker-supported filling
  mode once. If no supported filling mode passes `OrderCheck`, stop.

### Bounded Retry Candidates

- `TRADE_RETCODE_PRICE_CHANGED`
- `TRADE_RETCODE_REQUOTE`
- `TRADE_RETCODE_PRICE_OFF`
- `TRADE_RETCODE_TIMEOUT`
- `TRADE_RETCODE_CONNECTION`
- `TRADE_RETCODE_TOO_MANY_REQUESTS`
- `TRADE_RETCODE_LOCKED`
- `TRADE_RETCODE_FROZEN`
- `TRADE_RETCODE_ERROR` only when `OrderCheck` and local diagnostics do not
  indicate a final request/configuration failure.

Before retrying timeout, locked, frozen, or ambiguous errors, first search for
an already-open matching position by magic, symbol, and comment so the EA does
not duplicate a position after a delayed server response.

### Final Broker Limitations

These classifications apply to `OrderSend` results only. An `OrderCheck`
result never finalizes or blocks the Pandora broker-open attempt.

- `TRADE_RETCODE_MARKET_CLOSED`
- `TRADE_RETCODE_TRADE_DISABLED`
- `TRADE_RETCODE_SERVER_DISABLES_AT`
- `TRADE_RETCODE_CLIENT_DISABLES_AT`
- `TRADE_RETCODE_CLOSE_ONLY`
- `TRADE_RETCODE_LONG_ONLY`
- `TRADE_RETCODE_SHORT_ONLY`
- `TRADE_RETCODE_ONLY_REAL`
- `TRADE_RETCODE_HEDGE_PROHIBITED`
- `TRADE_RETCODE_INVALID`
- `TRADE_RETCODE_INVALID_ORDER`
- `TRADE_RETCODE_INVALID_EXPIRATION`
- `TRADE_RETCODE_LIMIT_VOLUME`
- `TRADE_RETCODE_NO_MONEY`
- `TRADE_RETCODE_LIMIT_POSITIONS`
- `TRADE_RETCODE_LIMIT_ORDERS`
- `TRADE_RETCODE_REJECT` and `TRADE_RETCODE_CANCEL` unless diagnostics prove a
  transient server condition.

## Prerequisites

- Read `AGENTS.md` and `docs/planner-execution-discipline.md` before executing.
- Execute this critical/trading-sensitive plan one Sprint per batch.
- Create one brief commit per completed Sprint before continuing, unless the
  user explicitly forbids commits or git is unavailable.
- Do not compile before Sprint 4 unless the user changes the validation policy.
- Keep `BUILD.log` temporary: read it after compile validation and remove it.

## Sprint 1: Broker Constraint Freshness And Diagnostics

**Goal**: Make broker constraint inputs current and auditable before broker
send/modify decisions, without changing execution policy yet.

**Demo/Validation**:
- Static review confirms every broker open/SLTP-sync path can refresh or use a
  freshly validated broker constraint snapshot.
- Logs include enough context to explain future invalid-stop decisions without
  exposing account secrets.
- No MetaEditor compile in this Sprint by current instruction.

### Task 1.1: Add A Lightweight Constraint Refresh Boundary

- **Location**:
  - `microservices/utils/broker_constraints_helper.mqh`
  - `HFT_Grid_AI.mq5`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Introduce or reuse a narrow helper that refreshes
  `g_symbol_constraints` before broker-sensitive actions. Use it before market
  open sends and before broker SL/TP sync. Keep it cheap and symbol-scoped.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Broker constraints are refreshed immediately before Pandora broker send and
    broker stop synchronization.
  - Failed refresh is logged and does not bypass existing guards.
  - The helper does not create include cycles.
- **Validation**:
  - Static diff review for include layering and hot-path cost.

### Task 1.2: Normalize Constraint Units In One Place

- **Location**:
  - `microservices/utils/broker_constraints_helper.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Centralize the effective minimum broker distance used for
  Pandora protection. The value should consider stops level, freeze level,
  point size, tick size, and a small tick-sized safety buffer for server-side
  movement/rounding.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Pandora broker-safe stop calculations use one effective distance helper.
  - The helper never returns a negative or zero effective distance when symbol
    specs are available.
  - Existing exact local SL/TP calculations are not changed.
- **Validation**:
  - Static review of call sites and unit conversions.

### Task 1.3: Extend Broker Send Diagnostics

- **Location**:
  - `microservices/trading_signals/grid_order_logging.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Ensure invalid-stop diagnostics record the candidate policy
  used (`exact`, `wide`, or `no_initial_sltp`), refreshed stops/freeze levels,
  tick size, point size, Bid/Ask, spread, `OrderCheck` retcode/comment, and
  final send retcode/comment.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - A future invalid-stops event can be explained from `query_debug.txt`.
  - Logs stay compact and behind existing file-log gates.
  - No account number, license token, API key, or private credential is logged.
- **Validation**:
  - Static review of log fields and string lengths.

## Sprint 2: Pre-Send Stop Candidate Pipeline

**Goal**: Build a deterministic pre-send decision path that never knowingly
sends a market order with broker SL/TP values that `OrderCheck` already rejected
as invalid stops.

**Demo/Validation**:
- Static trace shows the broker request uses the first valid candidate from the
  ordered fallback list.
- Invalid SL/TP candidates are classified before `g_position.Buy/Sell`.
- No MetaEditor compile in this Sprint by current instruction.

### Task 2.1: Model Broker Stop Candidates

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Add a small Pandora-scoped candidate model for broker-open
  SL/TP values. Candidate order should be:
  1. exact local SL/TP if legal,
  2. widened broker-safe SL/TP with safety buffer,
  3. no initial broker SL/TP when invalid stops are the only blocker.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Candidate generation does not alter local SL/TP targets.
  - Candidate state records whether broker protection is exact, wide, pending,
    failed, or intentionally absent at open.
  - Candidate generation is Pandora-scoped.
- **Validation**:
  - Static review against Pandora local target fields and stop sync statuses.

### Task 2.2: Use OrderCheck As An Advisory Candidate Probe

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Use `OrderCheck` as an advisory probe for each candidate. If
  a candidate reports `TRADE_RETCODE_INVALID_STOPS`, evaluate the next
  candidate instead of knowingly sending those stop values. If the check
  reports invalid volume, refresh constraints and recalculate normalized
  volume once. All other preflight results continue to `OrderSend`, whose
  result is authoritative.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - The final request is the exact request most recently inspected by
    `OrderCheck`.
  - `INVALID_STOPS` no longer causes a one-shot final rejection when the no-stop
    market request can be constructed.
  - `INVALID_VOLUME` receives exactly one same-tick repair attempt before
    `OrderSend`.
  - No `OrderCheck` retcode blocks a constructible Pandora market request.
- **Validation**:
  - Static control-flow review confirms only invalid stops changes candidates
    and every constructible final request reaches `OrderSend`.

### Task 2.3: Preserve Deterministic Local Admission

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Ensure local admission still occurs from broker-realistic
  executable Bid/Ask and does not move because broker protection is widened or
  omitted at open.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Exact local SL/TP/trailing targets remain anchored to the active local entry
    or real broker fill.
  - Broker protection candidates never become the local source of truth.
  - Markers continue to distinguish executed broker positions from local
    rejected entries.
- **Validation**:
  - Static state transition review.

## Sprint 3: Invalid-Stops Recovery And Post-Fill Protection Sync

**Goal**: Make a successful market fill recover cleanly from initial broker
stop limitations and tighten broker-side protection when legal.

**Demo/Validation**:
- Static trace shows `INVALID_STOPS` can lead to a real broker fill if the
  market request without invalid SL/TP is valid.
- Post-fill SL/TP sync retries legal wide/exact protection without disrupting
  local lifecycle.
- No MetaEditor compile in this Sprint by current instruction.

### Task 3.1: Refine Pandora Retcode Classification

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Adjust Pandora-only classification so
  `TRADE_RETCODE_INVALID_STOPS` is final only after all safe candidates fail,
  or when the no-initial-SLTP fallback is not allowed. Classify invalid volume
  as repairable once, then final if the repaired request still fails. Keep no
  money, market closed, disabled trading, close-only, direction-only, and hard
  account/symbol restrictions final.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - The classification reflects the candidate pipeline outcome, not just the raw
    first retcode.
  - Invalid-volume classification records whether the one allowed volume repair
    was attempted.
  - Non-Pandora behavior is unchanged.
  - Existing chart labels still map `ERR_Stops` when the EA ultimately gives up.
- **Validation**:
  - Static review of retry/final functions and label helpers.

### Task 3.2: Reconcile Send Success With Broker Stop Status

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: After a successful broker fill, mark broker execution as
  executed even if initial broker SL/TP was absent or wide. Immediately schedule
  or invoke `GridRefreshPandoraStopsAfterFill()` using refreshed constraints.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - A position opened with no initial SL/TP is not mislabeled as local rejected.
  - Broker stop status becomes pending, wide, targeted, or failed based on sync
    outcome.
  - Local close logic still owns SL/TP/BE/trailing decisions.
- **Validation**:
  - Static review of state writes around `PandoraMarkBrokerExecuted()`.

### Task 3.3: Throttle And Retry Stop Tightening Deterministically

- **Location**:
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Keep the existing throttled stop sync loop, but ensure it
  recomputes candidates from refreshed constraints and does not keep attempting
  a known-illegal exact target while price remains inside broker stop/freeze
  distance.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Broker stop sync attempts are not noisy per tick.
  - Exact local target is restored when legal.
  - Failed broker stop modification is non-fatal to local lifecycle.
- **Validation**:
  - Static hot-path/logging review.

## Sprint 4: Focused Regression And Compile Gate

**Goal**: Validate the completed local/market hardening path with compile,
diagnostic review, and targeted manual/tester scenarios related to invalid
stops, broker constraints, and local determinism.

**Demo/Validation**:
- MetaEditor compile passes with no errors or warnings related to this change.
- `BUILD.log` is read, summarized, and removed.
- Targeted scenarios produce expected diagnostics and state transitions.

### Task 4.1: Compile With Project Gate

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `BUILD.log` temporary only
- **Description**: Run the project MetaEditor compile command.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Compile command completes.
  - `BUILD.log` is inspected for errors and warnings.
  - `BUILD.log` is removed after inspection.
- **Validation**:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

### Task 4.2: Validate Invalid-Stops Recovery Scenarios

- **Location**:
  - Strategy Tester visual/manual demo chart
  - `query_debug.txt` when file logs are enabled
- **Description**: Run focused scenarios for Pandora broker execution with
  exact stops legal, exact stops illegal but wide legal, exact/wide illegal but
  no-initial-SLTP market open legal, invalid volume repaired once, invalid
  volume still invalid after repair, and hard blockers such as no money or
  market closed.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Legal exact stops open as targeted.
  - Wide stops open and later tighten when legal.
  - Invalid-stops-only open can execute without initial SL/TP if approved by the
    pre-execution decision.
  - Invalid volume is recalculated/renormalized once; if still invalid, it is
    final.
  - No money, market closed, disabled trading, and unrepaired invalid fill
    remain final blockers.
- **Validation**:
  - Manual/tester log review.
  - Chart marker and panel state review.

### Task 4.3: Review Diff And Documentation

- **Location**:
  - `README.md`
  - `docs/guides/pandora-box-strategy-inputs.md`
  - changed implementation files
- **Description**: Update user-facing docs only if behavior changed visibly.
  Review the full diff for unrelated changes, scope creep, unsafe logs, and
  trading-risk regressions.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Docs accurately describe temporary wide/pending/no-initial broker
    protection if implemented.
  - No unrelated refactors are included.
  - Changed files and validation results are ready for handoff.
- **Validation**:
  - `git diff --check`
  - Manual diff review.

## Testing Strategy

- Sprints 1-3 use static review only, per the user instruction that compile and
  error checks belong to the final Sprint.
- Sprint 4 runs the MetaEditor compile gate, inspects and removes `BUILD.log`,
  and performs focused invalid-stops/manual tester scenarios.
- Use "Every tick based on real ticks" for scenarios where spread, stop/freeze
  distance, and tick-level local SL/TP timing matter.

## Potential Risks And Gotchas

- Some brokers may reject a market order without initial SL/TP if account or
  symbol policy requires protection. The candidate pipeline still sends the
  constructible request and treats the resulting `OrderSend` retcode as the
  final broker response.
- A short-lived broker position without server SL/TP is a risk if the terminal,
  VPS, network, or EA dies before stop sync. This is why the fallback must be
  explicit and documented.
- Freeze/stops levels can change during session transitions. Refreshing before
  send and before modify reduces stale-data risk but cannot eliminate server
  race conditions completely.
- `OrderCheck` is advisory. The server can still reject the later `Buy/Sell` if
  price, spread, mode, or constraints change between check and send. The final
  send retcode remains authoritative.
- Widened broker SL/TP must never replace the exact local SL/TP source of truth.
- Expanding this behavior outside Pandora would increase blast radius; keep the
  first implementation Pandora-scoped unless explicitly approved.

## Rollback Plan

- Revert the Sprint commits in reverse order.
- If only runtime behavior is problematic, first disable the new no-initial-SLTP
  fallback and keep exact/wide broker SLTP candidates.
- If diagnostics are too noisy, revert only the added log fields while keeping
  the execution fix.
- Restore previous `TRADE_RETCODE_INVALID_STOPS` final behavior only if broker
  safety policy rejects the fallback model.

## Post-Plan Runtime Sprints

### Sprint 5: OrderCheck Runtime Diagnostics

**Goal**: Capture candidate-level `OrderCheck` evidence in Strategy Tester
without changing the execution decision.

**Status**: Completed in commit `732b82c`.

### Sprint 6: Authoritative Market OrderSend

**Goal**: Make `OrderCheck` advisory for Pandora market opens while retaining
the deterministic invalid-stops candidate cascade.

**Tasks**:

- Build the final Pandora `MqlTradeRequest` once per selected candidate.
- Run `OrderCheck` against that request.
- Use only `TRADE_RETCODE_INVALID_STOPS` to move from exact to wide and then to
  no initial SL/TP.
- Never block the broker-open attempt because of another `OrderCheck` result.
- Send the exact selected request with `OrderSend`.
- Base broker execution, rejection, retry, and final classification only on the
  `OrderSend` result.
- Preserve local SL/TP and later broker protection synchronization.

**Demo/Validation**:

- Static trace reaches `OrderSend` for every constructible Pandora market
  request regardless of the preflight retcode.
- Exact and wide candidates still fall back only on invalid stops.
- MetaEditor compile passes with zero errors and warnings.

### Sprint 7: Silent OrderCheck Compatibility

**Goal**: Accept Strategy Tester and broker environments that return a
successful but silent `OrderCheck`.

**Status**: Completed earlier in commit `5dbd2f0`, originally labeled Sprint 6.
The Git history is intentionally not rewritten.
