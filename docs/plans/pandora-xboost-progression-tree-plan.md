# Plan: Pandora XBoost Progression Tree

**Generated**: 2026-06-23
**Estimated Complexity**: Critical / Trading-Sensitive

## Overview

Implement a Pandora XBoost progression tree that uses Strategy Tester-generated
statistics to decide which branch should be eligible for real broker execution.
The tree is rooted in the first Pandora signal of the day. Local simulated
branches collect idempotent statistics, while inference can open one real
broker position at a time when the selected branch is statistically eligible.

The first implementation should keep the feature operationally simple:

- `Pandora_Box_Max_Entries = 1` controls the single Pandora root signal per day.
- `Pandora_XBoost_Max_Depth = N` controls the maximum number of XBoost real
  broker decisions/trades derived from that root signal for the day.
- XBoost is sequential: open, manage, close, classify event, decide next depth.
- XBoost does not open simultaneous real long and short positions.
- XBoost does not open the next real position while the previous real XBoost
  position is still active, even if the active position is in profit.
- New depth starts only after a close event such as SL, TP, BE, trailing-BE, or
  trailing stop in profit.
- When inference does not have a valid candidate, the EA continues local
  simulation only so the day can still add idempotent statistics.

This plan covers the complete feature through real broker inference logic. The
user will run manual Strategy Tester/live QA and may create follow-up plans from
those findings.

## Confirmed Product Decisions

- Include all Sprints needed for training, inference, panel visibility, and real
  broker execution logic.
- XBoost should decide and potentially open the first real trade immediately
  from the Pandora root if that root candidate is in the eligible Top 3.
- If no XBoost candidate qualifies, do not fall back to broker execution through
  Pandora normal. Keep local XBoost simulation active for idempotent statistics.
- Do not hard-code a specific preset such as 1:3 or trailing-indefinite. The
  business logic must support independent, idempotent strategy IDs for any
  preset.
- The existing Pandora trailing mode input decides whether the strategy uses
  trailing. XBoost should not introduce an independent trailing engine.
- Initial event taxonomy:
  - root: `ROOTL`, `ROOTS`
  - initial stops: `SLL1`, `SLS1`
  - fixed TP: `TPL`, `TPS`
  - trailing moved to BE: `TBE`
  - trailing BE close: `TBEL`, `TBES`
  - trailing profit stop by step: `TTPLn`, `TTPSn`
  - forced/protection/manual close: `FORCE_CLOSE`
- Add additional close events during implementation only when the lifecycle
  exposes a real state that cannot be safely represented by the initial list.
- Use CSV/local files for persistence. Do not use SQLite in this plan.
- Do not add MQL5 test/CI harnesses in this plan. Validation during
  implementation is static review plus one final MetaEditor compile/correction
  Sprint. Manual Strategy Tester/live QA belongs to the user after the feature
  is implemented.
- Use experimental minimum samples:
  - depth 1: `30`
  - depth 2: `20`
  - depth 3: `12`
  - deeper depths, if enabled later, must be explicitly defined before use.
- The panel should show the branches the model is waiting for next so the user
  can visually anticipate which real positions may open.
- Do not add a separate `Pandora_XBoost_Allow_Broker` safety input. When XBoost
  is configured for inference on a real account, it may place real broker
  orders subject to all existing guards and XBoost scoring gates.
- Do not change or special-case `Pandora_Box_Stop_On_First_Win` for XBoost in
  this plan. Treat it as existing Pandora behavior outside this feature scope.

## Non-Goals

- Do not implement SQLite, external services, Python preprocessing, or database
  dependencies.
- Do not create a machine-learning library or complex model runtime in MQL5.
  The first scorer should be deterministic and explainable.
- Do not open simultaneous XBoost broker positions.
- Do not open a hedge/reversal while the previous XBoost broker position is
  still active.
- Do not bypass license, magic-number, symbol, spread, margin, session,
  drawdown, market-status, broker-disabled, or protection guards.
- Do not mix statistics from different strategy IDs or schema versions.
- Do not create headless Strategy Tester matrix tests or any MQL5 test/CI
  harness.

## Prerequisites

- Read `AGENTS.md` and `docs/planner-execution-discipline.md` before executing.
- Execute this critical/trading-sensitive plan one Sprint per batch.
- Create one brief commit per completed Sprint before continuing, unless the
  user explicitly forbids commits or git is unavailable.
- Keep the include pipeline unchanged.
- Before every Sprint implementation, inspect `git status --short` and avoid
  mixing unrelated user changes.
- Do not compile after intermediate Sprints. Each implementation Sprint should
  be validated by focused static review, scope review, and local reasoning only.
- Compile only in the final compile/correction Sprint. MetaEditor may be run
  headless or with its UI; currently MT5 may be open while MetaEditor is not.
- During the final compile/correction Sprint, read `BUILD.log`, fix errors or
  warnings introduced by the plan, and remove `BUILD.log` after inspection:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
Get-Content -LiteralPath "C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
Remove-Item -LiteralPath "C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

## Proposed Public Inputs

Keep the public input surface small:

- `Pandora_XBoost_Mode`
  - `PANDORA_XBOOST_DISABLED`: current behavior, default.
  - `PANDORA_XBOOST_TRAINING`: local simulation and idempotent stats only.
  - `PANDORA_XBOOST_INFERENCE`: load stats and allow eligible broker execution.
- `Pandora_XBoost_Strategy_Id`
  - User-managed preset ID. Statistics are isolated by this value plus schema
    version and context fields.
- `Pandora_XBoost_Max_Depth`
  - Maximum sequential XBoost depth and maximum real XBoost broker trades
    derived from the root signal for the day.

Use code-level constants for initial thresholds to avoid many inputs:

- `PANDORA_XBOOST_MIN_SAMPLES_DEPTH_1 = 30`
- `PANDORA_XBOOST_MIN_SAMPLES_DEPTH_2 = 20`
- `PANDORA_XBOOST_MIN_SAMPLES_DEPTH_3 = 12`
- `PANDORA_XBOOST_MIN_EXPECTANCY_R = 0.05`
- `PANDORA_XBOOST_MIN_EDGE_R = 0.05`
- `PANDORA_XBOOST_DEPTH_PENALTY_R = 0.03`

Promote thresholds to public inputs only after manual QA shows they need runtime
tuning.

## Core Data Contracts

### Strategy Key

The strategy key must isolate incompatible presets:

```text
schema_version|strategy_id|symbol|timeframe|entry_type|trailing_mode|points_mode|box_window|max_depth
```

The user-facing `Pandora_XBoost_Strategy_Id` is part of this key, but the EA
should also include enough runtime configuration in the key to reduce accidental
mixing when a preset ID is reused.

### Node Key

Each candidate branch should have a stable node key:

```text
strategy_key|root_date|root_side|parent_event|depth|candidate_side
```

Examples:

```text
...|2026-06-23|ROOTL|ROOTL|1|L
...|2026-06-23|ROOTL|SLL1|2|S
...|2026-06-23|ROOTS|TTPS2|3|L
```

### Sample ID

Every training sample must be idempotent:

```text
strategy_key|root_date|node_path|depth|candidate_side|close_event
```

Before adding a sample, the runtime checks the in-memory sample ID set. If it
already exists, skip it.

### Statistics

Aggregate stats should be stored and loaded as numeric values:

```text
node_key,samples,wins,losses,be,total_r,avg_r,avg_win_r,avg_loss_r,
max_win_r,max_loss_r,max_drawdown_r,expectancy_r,last_seen
```

For trailing-based presets, outcome quality is based on R multiple, not only
binary win/loss.

## Sprint 1: XBoost Contracts And Configuration

**Goal**: Add feature contracts, inputs, and inert runtime state with no trading
behavior change.
**Commit**: `Sprint 1: add Pandora XBoost contracts`
**Demo/Validation**:
- No compile in this Sprint.
- Static review confirms contracts are inert when XBoost is disabled.
- Default inputs preserve existing Pandora behavior.
- XBoost mode labels and max depth clamp are deterministic.

### Task 1.1: Add XBoost Enums And Constants

- **Location**:
  - `microservices/core/enums.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Add XBoost mode enum, close-event enum, candidate status enum,
  schema version, threshold constants, and max-depth clamp constants.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Default mode is disabled.
  - Event enum covers root, SL, TP, BE, trailing-BE, trailing profit stop, and
    force/protection close.
  - Constants are code-level, not public inputs.
- **Validation**:
  - Static review for enum naming and no include cycles.

### Task 1.2: Add Minimal Public Inputs

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Add `Pandora_XBoost_Mode`,
  `Pandora_XBoost_Strategy_Id`, and `Pandora_XBoost_Max_Depth` in the Pandora
  input group.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - XBoost disabled by default.
  - Max depth defaults to `3` and clamps to the supported range.
  - No `Allow_Broker` input is added.
- **Validation**:
  - Manual review of Inputs ordering and defaults.

### Task 1.3: Add Runtime State Containers

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh` (new)
  - `services/trading_signals.mqh`
- **Description**: Add inert structs for root state, node state, candidate
  stats, top candidates, and runtime counters. Include the new module through
  the existing trading-signals aggregator without re-including sibling
  aggregators.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance Criteria**:
  - Constructors initialize all fields explicitly.
  - Copy constructors copy all new fields where arrays/assignments require it.
  - `SignalParams` has only the minimal fields needed to associate a running
    signal with XBoost root/depth/node IDs.
- **Validation**:
  - Constructor/copy review.

## Sprint 2: In-Memory Stats Storage And Idempotent CSV Persistence

**Goal**: Load and save XBoost stats without touching per-tick disk IO.
**Commit**: `Sprint 2: add Pandora XBoost stats persistence`
**Demo/Validation**:
- No compile in this Sprint.
- In training mode, OnInit loads existing files once and OnDeinit writes pending
  updates in batch.
- Re-running the same tester range does not duplicate sample IDs.

### Task 2.1: Define File Names And CSV Schema

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/pandora_xboost_storage.mqh` (new)
- **Description**: Add file naming helpers for sanitized strategy IDs, sample
  ledger CSV, and aggregate stats CSV under MT5 `MQL5/Files`.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - File names include schema version and sanitized strategy ID.
  - Paths never include account numbers, license values, or secrets.
  - CSV headers are stable and documented in helper constants.
- **Validation**:
  - Static review of filename sanitization and no sensitive fields.

### Task 2.2: Load Stats Into Memory

- **Location**:
  - `services/trading_signals/pandora_xboost_storage.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**: Add `PandoraXBoostLoad()` and call it during initialization
  after Pandora runtime config is available. Load aggregate stats into arrays
  sorted/indexed by key hash, and load sample IDs into an in-memory set-like
  array.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Load is skipped when mode is disabled.
  - Malformed rows are ignored with compact diagnostics.
  - No per-tick file reads are introduced.
- **Validation**:
  - Manual review of OnInit ordering and file-open error handling.

### Task 2.3: Batch Save Pending Samples And Aggregates

- **Location**:
  - `services/trading_signals/pandora_xboost_storage.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**: Add `PandoraXBoostSave()` and call it during deinit. Append
  pending sample rows and rewrite/flush the aggregate stats snapshot.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - No writes happen on every tick.
  - Duplicate sample IDs are skipped before pending append.
  - File handles are closed in all paths.
- **Validation**:
  - Static review of batch save and duplicate-sample skip paths.

## Sprint 3: Tree Keys, Event Classification, And Local Node Samples

**Goal**: Classify Pandora/XBoost events into deterministic tree nodes and
produce idempotent local samples.
**Commit**: `Sprint 3: classify Pandora XBoost tree events`
**Demo/Validation**:
- No compile in this Sprint.
- Root, SL, TP, BE, trailing-BE, trailing profit, and force/protection closes
  produce stable event labels.
- Local samples include R multiple and close event.

### Task 3.1: Build Strategy, Node, And Sample Key Helpers

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add helpers to compose strategy keys, node keys, sample IDs,
  compact display IDs, and key hashes.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Keys include schema version and strategy ID.
  - Key generation is deterministic across repeated tester runs.
  - Hash lookup always verifies the full key before accepting a match.
- **Validation**:
  - Manual review with example root and depth keys.

### Task 3.2: Classify Pandora Close Events For XBoost

- **Location**:
  - `services/trading_signals/grid_order_controller.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Extend Pandora close classification with XBoost-specific
  event labels without changing existing `PandoraCloseOutcomes` semantics.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Existing SL/TP/BE counters remain unchanged.
  - Step trailing records the trailing step index for `TTPLn`/`TTPSn`.
  - Force/protection closes map to `FORCE_CLOSE`.
- **Validation**:
  - Static trace of local close and broker-history close paths.

### Task 3.3: Record Local Training Samples

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
- **Description**: When a Pandora/XBoost node closes, compute R multiple,
  build the sample ID, skip duplicates, and update in-memory aggregate stats.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - R multiple uses deterministic local SL distance for the node.
  - BE and trailing profit exits are represented correctly.
  - Protection closes do not masquerade as normal edge.
- **Validation**:
  - Static trace of sample add/skip and aggregate update paths.

## Sprint 4: Local Progression Tree Runtime

**Goal**: Generate and advance the XBoost local progression tree through max
depth without broker execution.
**Commit**: `Sprint 4: implement local XBoost progression tree`
**Demo/Validation**:
- No compile in this Sprint.
- Training mode creates one root per Pandora root signal and advances local
  depth only after close events.
- Max depth bounds the number of progression decisions for the day.

### Task 4.1: Initialize Root From Pandora Signal

- **Location**:
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: When a Pandora root signal is admitted and XBoost is enabled,
  initialize XBoost root state with root date, root side, depth `1`, and root
  event `ROOTL` or `ROOTS`.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - `Pandora_Box_Max_Entries = 1` still limits root signals.
  - XBoost disabled mode leaves current Pandora flow unchanged.
  - Training mode does not call broker from XBoost.
- **Validation**:
  - Static trace from Pandora root admission to XBoost root state.

### Task 4.2: Generate Local Candidate Branches

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: For each active depth/event, generate local long and short
  candidate branches for stats and scoring.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Candidate branches use existing Pandora price/point math where possible.
  - Candidate branches have deterministic entry, SL, trailing, and close state.
  - No broker order is sent in training mode.
- **Validation**:
  - Static review for hot-path array bounds and no unbounded growth.

### Task 4.3: Advance Depth After Local Close

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
- **Description**: After a node close, classify the event, record samples, then
  advance to the next depth when `depth < Pandora_XBoost_Max_Depth`.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - One close produces at most one next-depth transition.
  - Depth does not advance when max depth is reached.
  - Re-running the same day skips already recorded samples but still allows the
    local simulation to reconstruct state during the run.
- **Validation**:
  - Static trace for `Max_Depth = 1`, `2`, and `3`.

## Sprint 5: Scoring Engine And Inference Dry Run

**Goal**: Rank candidates from loaded stats and expose READY/WATCH/WAIT/BLOCK
decisions without broker execution changes yet.
**Commit**: `Sprint 5: add XBoost scorer and dry-run inference`
**Demo/Validation**:
- No compile in this Sprint.
- Inference mode can load prior stats and rank candidates in memory.
- No disk reads occur during per-tick candidate evaluation.

### Task 5.1: Implement Stats Lookup

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add hash-indexed stats lookup with full-key verification and
  a small cache for the last evaluated node.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Missing stats returns a WAIT/BLOCK-style candidate, not a broker action.
  - Hash collision cannot return the wrong node.
  - Lookup does not allocate unbounded arrays per tick.
- **Validation**:
  - Static review of lookup bounds and cache invalidation.

### Task 5.2: Implement Candidate Scoring

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add deterministic scoring using expectancy R, minimum
  samples by depth, edge over alternative side, and depth penalty.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Depth 1 requires at least 30 samples.
  - Depth 2 requires at least 20 samples.
  - Depth 3 requires at least 12 samples.
  - Candidates require positive expectancy and minimum edge before READY.
  - If long and short scores are too close, no broker-eligible candidate is
    selected.
- **Validation**:
  - Dry-run log examples for READY, WATCH, WAIT, and BLOCK.

### Task 5.3: Build Top 3 Next Candidates

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Build a compact sorted list of the next three candidates the
  model is waiting for from the current tree state.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Top 3 is based on the next expected event/depth, not unrelated historical
    global winners.
  - Each row includes display ID, status, samples, expectancy, and edge.
  - Training mode can display candidates as local-only/dry-run.
- **Validation**:
  - Static review of sorting and max-length display strings.

## Sprint 6: Broker Execution Gate For Sequential XBoost

**Goal**: Allow inference mode to place real broker orders for eligible XBoost
candidates while preserving a strict sequential lifecycle.
**Commit**: `Sprint 6: enable sequential XBoost broker execution`
**Demo/Validation**:
- No compile in this Sprint.
- Inference mode can open the root trade immediately when the root candidate is
  READY and in Top 3.
- XBoost never opens a second real broker position while one XBoost position is
  active.

### Task 6.1: Build XBoost Broker Candidate From Scored Branch

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Convert the selected scored candidate into a `SignalParams`
  / `GridOrderState` path that reuses existing Pandora broker-realistic market
  open, local SL/TP/trailing, retry, and broker SL/TP sync behavior.
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Existing spread, margin, volume, session, market-status, and broker guards
    remain authoritative.
  - Candidate side can be long or short regardless of root side, but only one
    selected side is sent to broker.
  - Broker comments are deterministic and short enough for MT5 comment limits,
    such as `pandora_xb_pos_n` or an equivalent compact format.
- **Validation**:
  - Static trace from candidate selection to `OrderSend`.

### Task 6.2: Enforce Sequential Broker Ownership

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
- **Description**: Track active XBoost broker ownership so a new real XBoost
  position cannot open until the previous XBoost broker/local lifecycle is
  closed.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - No simultaneous XBoost broker positions.
  - No long/short hedge is opened while another XBoost broker position is
    running.
  - A profitable trailing position does not trigger the next broker depth until
    it actually closes.
- **Validation**:
  - Static trace showing active trailing profit does not open an opposite broker
    position before trailing close.

### Task 6.3: Bind Max Depth To Real Daily Trade Budget

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
- **Description**: Treat `Pandora_XBoost_Max_Depth` as the maximum number of
  sequential real XBoost broker decisions/trades for the root day.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - `Max_Depth = 1` allows at most one real XBoost trade from the root.
  - `Max_Depth = 2` allows at most two sequential real XBoost trades.
  - `Max_Depth = 3` allows at most three sequential real XBoost trades.
  - When a candidate is not READY, the depth can continue locally for stats but
    does not consume a real broker trade count unless a broker send is attempted.
- **Validation**:
  - Static trace of max-depth broker budget with depths 1, 2, and 3.

## Sprint 7: Close Event Integration, Budgets, And Daily Reset

**Goal**: Finalize the operational daily lifecycle so XBoost roots, broker
trades, local samples, and daily cleanup remain consistent.
**Commit**: `Sprint 7: finalize XBoost daily lifecycle`
**Demo/Validation**:
- No compile in this Sprint.
- A day with no eligible candidate still records local stats.
- A day with eligible candidates opens at most max-depth sequential broker
  trades and then stops.

### Task 7.1: Integrate Root Budget With Pandora Daily State

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Ensure Pandora root admission and XBoost progression do not
  double-count or prematurely finish the day when XBoost is still collecting
  local depth statistics.
- **Dependencies**: Sprint 6.
- **Acceptance Criteria**:
  - `Pandora_Box_Max_Entries = 1` admits one root signal.
  - XBoost local progression can continue from that root until max depth or day
    completion.
  - Existing daily signal budgets and protection locks are still respected.
- **Validation**:
  - Static review of `PandoraRegisterSideOutcome()` interactions.

### Task 7.2: Preserve Existing Stop-On-First-Win Behavior

- **Location**:
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Do not change `Pandora_Box_Stop_On_First_Win` in this plan.
  Review the XBoost integration points and keep the existing Pandora behavior
  outside the XBoost feature scope.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - No new XBoost-specific first-win input or branch is added.
  - Existing Pandora first-win behavior is not deliberately changed.
  - XBoost still cannot keep opening broker trades after max depth or protection
    lock.
- **Validation**:
  - Static review of XBoost integration points that interact with daily outcome
    registration.

### Task 7.3: Reset And Cleanup Runtime State

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/market_signal_cleanup.mqh`
  - `HFT_Grid_AI.mq5`
- **Description**: Clear daily/root state at the right window/day boundaries and
  deinit paths, while preserving loaded stats and pending save buffers until
  deinit save.
- **Dependencies**: Task 7.2.
- **Acceptance Criteria**:
  - New day starts with no stale active root.
  - Pending broker retry/close states are not lost on normal per-tick reset.
  - Deinit closes file handles and flushes pending stats.
- **Validation**:
  - Manual review of cleanup/deinit paths.

## Sprint 8: Panel Top 3 And Tester Comment Visibility

**Goal**: Show the next XBoost branches expected by the model in the existing
panel/comment path.
**Commit**: `Sprint 8: show XBoost top candidates in panel`
**Demo/Validation**:
- No compile in this Sprint.
- Live panel/tester comment shows current root, depth, broker count, and Top 3
  next candidates.
- Panel remains compact and does not churn chart objects per tick.

### Task 8.1: Add XBoost Summary Lines

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/frontend/grid_visualization.mqh`
  - `services/frontend/pandora_box_panel.mqh`
- **Description**: Add helper to append compact XBoost summary lines to the
  existing `summary_lines` array.
- **Dependencies**: Sprint 7.
- **Acceptance Criteria**:
  - Summary shows mode, root side/date, depth, and real broker count.
  - Summary shows up to three next candidates with display ID, status, samples,
    expectancy R, and edge R.
  - Strings stay short enough for the existing panel width constraints.
- **Validation**:
  - Static review of summary-line ordering and panel string lengths.

### Task 8.2: Preserve Existing Pandora Panel Behavior

- **Location**:
  - `services/frontend/pandora_box_panel.mqh`
  - `services/frontend/grid_visualization.mqh`
- **Description**: Ensure XBoost lines complement the Pandora summary without
  hiding market-status errors, license/magic info, or active signal summaries.
- **Dependencies**: Task 8.1.
- **Acceptance Criteria**:
  - Market-status error line remains visible.
  - Existing Pandora summary still appears.
  - If line count exceeds panel limits, overflow is explicit and compact.
- **Validation**:
  - Static review of panel overflow behavior and existing summary visibility.

## Sprint 9: Documentation And Manual Validation Workflow

**Goal**: Document usage, training/inference workflow, and manual QA scenarios.
**Commit**: `Sprint 9: document Pandora XBoost workflow`
**Demo/Validation**:
- Documentation explains training, replay, validation, and walk-forward usage.
- User can run a two-pass tester workflow without guessing which files to use.

### Task 9.1: Update Pandora Inputs Guide

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
- **Description**: Document XBoost mode, strategy ID, max depth, stats files,
  idempotent samples, and panel fields.
- **Dependencies**: Sprint 8.
- **Acceptance Criteria**:
  - Clearly states that same-range replay is a functional check, not edge
    validation.
  - Clearly states that out-of-sample validation or walk-forward is required for
    edge evaluation.
  - Explains that max depth equals max sequential XBoost real trades from one
    root day.
- **Validation**:
  - Proofread docs.
  - Verify file paths and input names match code.

### Task 9.2: Add Tester Scenario Checklist

- **Location**:
  - `docs/guides/pandora-box-strategy-inputs.md`
  - optional `docs/guides/pandora-xboost-workflow.md`
- **Description**: Add manual scenarios for training pass, replay pass,
  validation pass, no-candidate local-only day, root broker execution, trailing
  profit close then next depth, and max-depth stop.
- **Dependencies**: Task 9.1.
- **Acceptance Criteria**:
  - Scenarios do not require headless tester matrix tests.
  - Scenarios identify expected panel/log/stat outcomes.
  - Scenarios cover no duplicate samples on repeated runs.
- **Validation**:
  - Proofread docs.
  - Manual static review against implemented logs and panel labels.

## Sprint 10: Final Compile And Warning Cleanup

**Goal**: Run the single project compile gate after all implementation Sprints
are complete, then fix any compile errors or warnings introduced by the plan.
**Commit**: `Sprint 10: final XBoost compile cleanup`
**Demo/Validation**:
- MetaEditor compile is run once for the full EA.
- `BUILD.log` is inspected and removed after review.
- Compile ends with zero errors and zero warnings, or any remaining warnings are
  documented with a clear reason they are unrelated and pre-existing.

### Task 10.1: Run Final MetaEditor Compile

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `BUILD.log` temporary artifact
- **Description**: Run MetaEditor compile after all code/documentation Sprints
  are implemented. MetaEditor may be run headless or with UI; MT5 may already be
  open while MetaEditor is closed.
- **Dependencies**: Sprint 9.
- **Acceptance Criteria**:
  - Compile command targets the project entrypoint.
  - `BUILD.log` is read immediately after compile.
  - `BUILD.log` is removed after inspection.
- **Validation**:
  - Run:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
Get-Content -LiteralPath "C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
Remove-Item -LiteralPath "C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

### Task 10.2: Fix Compile Errors And Warnings

- **Location**:
  - Files touched by Sprints 1-9
- **Description**: Correct any syntax errors, type errors, constructor/copy
  issues, include ordering issues, or warnings introduced by XBoost.
- **Dependencies**: Task 10.1.
- **Acceptance Criteria**:
  - Fixes remain scoped to XBoost implementation unless a compile failure proves
    a directly related integration issue.
  - No unrelated refactors are added.
  - `BUILD.log` is removed after the final pass.
- **Validation**:
  - Re-run the compile command until the final result is clean or remaining
    unrelated warnings are documented.

## Sprint 11: Common File Storage And Dataset Diagnostics

**Goal**: Move XBoost CSV persistence to the MT5 common Files sandbox with a
stable terminal-separated folder layout, and make the active dataset path easy
to audit from tester logs and panel/comment output.
**Commit**: `Sprint 11: move XBoost stats to common files`
**Demo/Validation**:
- No compile in this Sprint.
- Static review confirms all XBoost file reads/writes use `FILE_COMMON`.
- `Enable_Logs` output includes the common folder, stats filename, samples
  filename, and load/save counts.
- Panel/tester comment shows a compact common-dataset hint when XBoost is
  enabled.

### Task 11.1: Add Common Storage Path Helpers

- **Location**:
  - `services/trading_signals/pandora_xboost_storage.mqh`
- **Description**: Add helper functions for a common storage folder rooted at
  `PandoraXBoost`, separated by a deterministic MT5 terminal key, account
  server, strategy ID, symbol, and timeframe. Ensure write paths create missing
  folders before opening files.
- **Dependencies**: Sprint 10.
- **Acceptance Criteria**:
  - Stats and samples filenames resolve to subpaths under `FILE_COMMON`.
  - Folder and filename components are sanitized.
  - Terminal separation does not expose account numbers or credentials.
- **Validation**:
  - Static review of FileOpen/FileIsExist/FolderCreate flags and path strings.

### Task 11.2: Expose Dataset Diagnostics

- **Location**:
  - `services/trading_signals/pandora_xboost_storage.mqh`
  - `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add compact helpers for dataset folder/filename labels and
  append them to logs and XBoost panel/comment summary lines.
- **Dependencies**: Task 11.1.
- **Acceptance Criteria**:
  - `PANDORA_XBOOST_LOAD` and `PANDORA_XBOOST_SAVE` logs identify the common
    folder and stats/samples files.
  - Panel/comment includes loaded stat count, known sample ID count, pending
    sample count, and a short common dataset folder hint.
  - No per-tick disk reads or writes are introduced.
- **Validation**:
  - Static review of summary-line length and hot-path cost.

## Sprint 12: XBoost Chart Audit Visibility

**Goal**: Make local XBoost branches and trailing lines visually distinguishable
in Strategy Tester so multiple local branches do not overwrite each other's
chart objects.
**Commit**: `Sprint 12: improve XBoost chart audit labels`
**Demo/Validation**:
- No compile in this Sprint.
- Static review confirms grid object names remain stable but include unique
  XBoost node identity when present.
- XBoost line labels show depth, display ID, local/broker mode, and trailing
  step when relevant.

### Task 12.1: Add XBoost-Aware Object Names

- **Location**:
  - `microservices/frontend/grid_visual_utils.mqh`
  - `services/trading_signals/market_signal_cleanup.mqh`
- **Description**: Extend grid object name generation with a compact XBoost
  token derived from node path/hash/depth when a signal is XBoost-enabled, so
  simultaneous local long/short or deeper branch visuals cannot collide.
- **Dependencies**: Sprint 11.
- **Acceptance Criteria**:
  - Non-XBoost object names remain unchanged.
  - XBoost object names remain deterministic across draw/remove calls.
  - Object names are short enough for chart object handling.
- **Validation**:
  - Static review of draw/remove symmetry.

### Task 12.2: Add XBoost-Aware Line Labels And Summaries

- **Location**:
  - `microservices/frontend/grid_visual_utils.mqh`
  - `services/frontend/grid_visualization.mqh`
- **Description**: Include compact XBoost metadata in chart line labels and
  active signal summaries without changing trade state or scoring behavior.
- **Dependencies**: Task 12.1.
- **Acceptance Criteria**:
  - Labels identify branch depth and display ID.
  - Trailing-active labels expose the current trailing step index.
  - Active signal summary distinguishes local-only versus broker-selected
    XBoost branches.
- **Validation**:
  - Static review of label strings and existing panel width limits.

## Validation Strategy

- **Intermediate Sprint validation**: Do not compile after Sprints 1-9. Use
  focused static review, scope review, and path tracing only.
- **Extension Sprint validation**: Sprints 11-12 are validated with static path
  and chart-object review, then the EA is compiled once after the extension
  batch.
- **Final compile gate**: Run MetaEditor compile only at the planned final
  compile gates. Read and remove `BUILD.log`.
- **No MQL5 test/CI harnesses**: Do not build unit tests, script harnesses,
  headless tester matrices, or CI for this feature.
- **Static review focus**: Check include layering, constructors/copy constructors,
  array bounds, file handles, hot-path cost, magic/symbol scope, and broker
  guard reuse.
- **Manual QA handoff scenario: training pass**:
  - Run Strategy Tester in `PANDORA_XBOOST_TRAINING`.
  - Confirm sample and aggregate files are created.
  - Repeat the same date range and confirm no duplicate samples.
- **Manual QA handoff scenario: replay pass**:
  - Run the same range in `PANDORA_XBOOST_INFERENCE`.
  - Treat this as functional validation only, not predictive edge validation.
  - Confirm Top 3 panel rows and broker gates match loaded stats.
- **Manual QA handoff scenario: out-of-sample validation**:
  - Train period A.
  - Validate period B using frozen stats from A.
  - Confirm broker decisions only occur for READY candidates.
- **Manual QA handoff scenario: sequential broker lifecycle**:
  - Root candidate READY opens real position immediately.
  - Missing/weak candidate opens no broker position and continues local stats.
  - Active trailing position reaches profit but no opposite broker trade opens
    until it closes.
  - Trailing close records `TTPLn`/`TTPSn` and advances next depth.
  - `Max_Depth = 1`, `2`, and `3` cap real XBoost broker trades.
- **Manual QA handoff scenario: protection paths**:
  - Market disabled/close-only blocks broker action.
  - Spread/margin/volume guard blocks broker action.
  - Protection force-close records `FORCE_CLOSE`.

## Potential Risks And Gotchas

- Same-period replay can look profitable because the model saw the same period.
  Treat it only as an integration check.
- A reused `Pandora_XBoost_Strategy_Id` can mix incompatible presets. Include a
  runtime configuration signature in the strategy key and document preset
  discipline.
- Deep branches have fewer samples. Use lower sample thresholds by depth and
  apply depth penalty so shallow noisy data does not dominate.
- `Pandora_Box_Stop_On_First_Win` is intentionally out of scope for this plan.
  Do not add XBoost-specific first-win behavior unless a later plan requests it.
- Broker comment length is limited. Use short deterministic comments and keep
  full XBoost IDs in local stats/log state rather than broker comments.
- On netting accounts, opposite-side opens may close/reduce existing exposure.
  Sequential ownership must prevent XBoost from opening a new broker position
  while any XBoost broker position is active.
- CSV parsing must be robust to malformed rows and not block live startup with
  excessive logs.
- File writes must be batched and file handles must close on deinit.
- Top 3 panel rows can become too long. Use compact R formatting and capped
  display IDs.
- Statistics are local to this terminal/files folder. Moving terminals requires
  moving the stats files intentionally.

## Rollback Plan

- Set `Pandora_XBoost_Mode = PANDORA_XBOOST_DISABLED` to restore current
  Pandora behavior.
- If a Sprint introduces compile or runtime instability, revert only that
  Sprint's commit.
- XBoost stats files are external runtime artifacts. They can be archived or
  removed from `MQL5/Files` without changing source code.
- Keep all XBoost code isolated behind mode checks so disabled mode does not
  alter existing Pandora root detection, broker send, stop sync, or close
  accounting.
