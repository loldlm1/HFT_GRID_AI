# Plan: Pivot HFT Retracement Campaign Continuity

**Generated**: 2026-08-02
**Status**: Active
**Complexity**: Critical / trading-sensitive
**Execution**: Sprints 1-3 in order, one validated commit per Sprint

## Objective

Keep an admitted Pivot HFT retracement campaign eligible for its existing
same-fill-candle reattempt after a local flat or losing close, even when the
current quote has returned inside the Bollinger band or crossed back through
the pivot. Preserve all campaign boundaries, execution guards, and the latest
outer-level replacement rule.

## Consolidated Prior Work

The two completed Pivot HFT plans are archived and remain the durable record of
the current band-risk, fixed-R, immediate-entry, and winning-ladder behavior:

- `docs/plans/archive/pivot-hft-volatility-sl-tp-plan.md`
- `docs/plans/archive/pivot-hft-immediate-entry-band-risk-consumption-plan.md`

This file is the only active Pivot HFT implementation plan for the current
change. The unrelated root `.plan.md` is a historical Grid Sequence refactor
artifact and is outside this plan.

## Query Debug Audit

**Source**:
`C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\query_debug.txt`

**Run**: US30, M3 micro bars, M30 classic pivots, 50-point retracement,
6.25% full-band local SL, 1.5-R trailing step, and 5.0-R fixed local TP.

Observed event totals:

- 72 `CAMPAIGN_ARMED`
- 67 `ENTRY_TRIGGERED`, 67 order sends, and 67 verified fills
- 5 `CAMPAIGN_REPLACED`
- 1 `CAMPAIGN_CARRIED_FORWARD`
- 56 `POSITION_REARMED`
- 3 `REARM_EXPIRED`
- 0 campaign cancellations in the focused run

Findings:

1. Initial pending retracement tracking is not canceled by a band refresh or
   by returning inside the band. The S2 campaign armed at 14:32:55 on January
   7 was carried into the next M3 bar at 14:33:00 and filled at 14:33:05.
2. The five armed campaigns without fills were deliberately replaced by a
   newly touched outer pivot level. That latest-level behavior is unrelated to
   Bollinger invalidation and remains required.
3. The actual live-band coupling is in post-close rearm. The current helper
   requires the close to remain beyond both the stored pivot and the latest
   Bollinger edge before recreating the admitted campaign.
4. Ticket 50 closed flat at 15:08:13 during its fill candle, but its close was
   below R1 after the bearish retracement. The live side test deferred rearm
   until the M3 candle changed, producing `REARM_EXPIRED` at 15:09:00.
5. Tickets 98 and 132 closed after their fill candles had already changed.
   Their expiry is consistent with the existing fill-candle boundary and does
   not justify extending retries across candles.

The narrow correction is therefore to latch initial admission for post-close
rearm. Bollinger and pivot-side price predicates remain required to arm a new
campaign, but they are not re-applied to an already admitted campaign.

## Fixed Decisions

- Add no new public input or optimization dimension.
- Keep initial campaign admission unchanged: the current micro close must be on
  the allowed side of the cached previous-closed-bar Bollinger band and touch
  an eligible classic pivot.
- Keep active retracement tracking unchanged across later band refreshes and
  micro-bar transitions.
- For a local close eligible for reattempt, do not recheck the current quote
  against the pivot price or live Bollinger edge.
- Retain the existing same-fill-micro-bar boundary for reattempts.
- Refresh the pivot snapshot and require the stored pivot level price to remain
  unchanged before rearming. A changed pivot set permanently invalidates that
  reattempt and receives one bounded audit event.
- Preserve latest outer-level replacement, profitable ladder consumption,
  session and pivot-set cancellation, daily budgets, protection, market status,
  spread, margin, symbol/magic, license, and single-flight guards.
- Keep the hot path allocation-free and add no indicator handle, history scan,
  harness, CI module, fixture, parser, or Strategy Tester automation.
- Run the complete MetaEditor compile only in Sprint 3. The user owns manual
  Strategy Tester QA after handoff.

## Sprint 1: Plan Consolidation And Audit Contract

**Goal**: Archive completed Pivot HFT plans and establish one evidence-backed
active execution contract.

**Files**: the two archived plans and this plan.

**Commit**: `Sprint 1: consolidate pivot hft continuity plan`

### Acceptance Criteria

- Both completed Pivot HFT plans live under `docs/plans/archive/`.
- This is the only active Pivot HFT plan.
- Audit totals and the distinction between initial tracking, outer-level
  replacement, and post-close rearm are recorded.
- No product code changes and no MetaEditor or Strategy Tester run occurs.

### Validation

- Verify plan paths/statuses and recent Sprint commits.
- Review the focused log counts and the carried/expired sequences.
- Run `rtk git diff --check` and inspect the Sprint-only diff.

### Sprint 1 Gate

- [x] Tasks and static validation complete.
- [x] Diff is limited to plan consolidation.
- [x] Exactly one Sprint 1 commit created.

## Sprint 2: Admission-Latched Same-Candle Rearm

**Goal**: Rearm an already admitted campaign without a moving live-band or
pivot-side price test.

**Dependencies**: Sprint 1 commit and gate.

**Files**: `services/trading_signals/pivot_hft_position_lifecycle.mqh`, this
plan.

**Commit**: `Sprint 2: preserve admitted retracement rearm`

### Tasks

1. Replace the live quote/band rearm predicate with an unchanged-pivot-level
   check based on the refreshed pivot snapshot and the stored pivot price.
2. Remove the unnecessary current-close and Bollinger snapshot requirements
   from post-close rearm only.
3. Keep fill-candle expiry, single-flight, position lifecycle, protection,
   session, daily-budget, and market-status gates in their current order.
4. Mark a changed pivot set completed with one explicit `REARM_INVALIDATED`
   audit record instead of silently waiting for candle expiry.
5. Record `admission=latched` on successful rearm for manual QA traceability.

### Acceptance Criteria

- A ticket-50-equivalent flat close can rearm during the same fill candle even
  when the quote is inside the current band or back through its pivot.
- A reattempt never crosses the position fill-candle boundary.
- A changed pivot level price cannot rearm.
- New campaigns still require the existing Bollinger and pivot admission math.
- Outer-level replacement and all trading-safety guards are unchanged.
- No input, indicator, include-order, compile, or Strategy Tester change occurs.

### Validation

- Trace finalization -> reattempt flag -> guard checks -> pivot identity ->
  campaign start for both directions.
- Search for live-band references in the rearm path and confirm they remain in
  initial detection.
- Review scope, hot-path cost, logging bounds, and `rtk git diff --check`.

### Sprint 2 Gate

- [x] Tasks and static validation complete.
- [x] Trading guard order and campaign boundaries reviewed.
- [x] Exactly one Sprint 2 commit created.

## Sprint 3: Documentation And Final Compile

**Goal**: Document the corrected campaign semantics and compile the integrated
EA once.

**Dependencies**: Sprint 2 commit and gate.

**Files**: `docs/guides/pivot-hft-strategy-inputs.md`, this plan, plus only
implementation files requiring compile repair.

**Commit**: `Sprint 3: document and validate retracement continuity`

### Acceptance Criteria

- The guide states that Bollinger/pivot geometry admits a campaign but does not
  invalidate its active retracement or same-candle rearm as price retraces.
- The guide retains outer-level replacement, pivot-set rollover, session, and
  fill-candle boundaries.
- The exact portable MetaEditor compile finishes with zero errors and zero
  warnings; the current `BUILD.log` is inspected and removed.
- No harness, CI, automated Strategy Tester run, or unrelated artifact is added.
- Final status/diff review finds no unrelated changes.

### Final Compile Command

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /portable /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

### Sprint 3 Gate

- [ ] Documentation and final compile complete.
- [ ] Compile reports zero errors and zero warnings; `BUILD.log` removed.
- [ ] Exactly one Sprint 3 commit created.

## Execution Record

| Sprint | Status | Commit | Validation |
| --- | --- | --- | --- |
| 1 | Complete | `757fc3f` | Plan paths, focused audit, and static diff review |
| 2 | Complete | This Sprint 2 commit | Rearm flow and safety-scope static review |
| 3 | Pending | Pending | Sole full MetaEditor compile and final review |
