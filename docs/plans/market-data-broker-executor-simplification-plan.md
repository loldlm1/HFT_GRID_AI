# Plan: Market Data Scraper And Broker Executor Simplification

**Generated**: 2026-07-28
**Status**: Active implementation; Sprint 5 static/Python gate passed
**Planning Review**: Complete; no blocking clarification remains
**Estimated Complexity**: High
**Risk Class**: Critical - this removes licensing, configurable protection, spread/session gates, and the multi-leg execution lifecycle while preserving real broker execution
**Execution Baseline**: `a502e28460dba295bdc0194b7a0eaf72364285e0`, 81 tracked MQL5 files and 30,882 lines

**Sprint 5 Evidence**: The Sprint 5 starting commit `641e326` contained 59
tracked MQL5 files and 17,533 lines. The validated working tree contains 41
tracked MQL5 files and 13,557 lines (18 files and 3,976 lines removed during
Sprint 5; 40 files and 17,325 lines below the execution baseline).

## Overview

Refound the Expert Advisor as a small, always-on M1 extremum market-data collector with one broker execution path. `EXTREMUM_V1` remains the only signal source, derives its own direction from the current Stoch Structure extremum, and may track multiple attempts concurrently. The public input surface becomes limited to deterministic market-data time selection, lot sizing, statistics, ML, pattern audit, and debug controls.

The implementation will delete the license/entitlement stack, account settings, drawdown protection, user session filters, spread threshold, direction/concurrency configuration, daily limits, lot sequencing, lot multiplication, variable TP, partial TP, and generic multi-leg/grid code. It will retain a mandatory broker-safety kernel for every observed attempt and every pre-send decision: account margin mode, actual broker session, symbol trade mode, bid/ask, spread as an observed fact, stops/freeze distances, volume limits and step, margin, `OrderCheck`, terminal Algo Trading permission, stable symbol/magic scope, order retcodes, and broker reconciliation.

Schema v8 will distinguish broker facts from normalized analysis time. `FIXED_TIME_SESSIONS` leaves timestamps unchanged. `EXNESS_SESSION` normalizes DST-shifting market times for research, including the US30 example where winter broker time `14:30` is stored with analysis time `13:30`. Normalization affects exports, derived time features, ML research, and pattern-audit matching only. It must never move bar scheduling, synthesize bars, bypass the real broker session, or alter live order timing.

Target runtime flow:

```text
minimal inputs
-> M1 Stoch Structure/extremum observation
-> intrinsic attempt and observation-time broker snapshot
-> deterministic schema v8 export
-> raw broker-time breakout trigger
-> fresh pre-send broker checks
-> optional tester-only ML/pattern denial
-> one broker position with broker-side SL and fixed 1R TP
-> ticket-first broker reconciliation
-> broker-confirmed outcome export
```

## Scope

- **In scope**:
  - Preserve the always-on `EXTREMUM_V1` cycle, revision, attempt, simulation, statistics, ML, and pattern-audit concepts.
  - Remove these active input groups and all exclusively dependent runtime logic:
    - `+= Execution Foundation EA =+`
    - `+= Account Settings EA =+`
    - `+= Protection Risk Management =+`
    - `+= Time Filter Session Manager =+`
    - `+= Extremum Engine =+`
    - `+= Strategy Risk Settings =+`, except the two lot inputs moved to a minimal broker-execution group.
  - Leave exactly these final input groups and fields:

    | Input group | Inputs |
    | --- | --- |
    | `+= Market Data Time =+` | `Broker_Session` |
    | `+= Broker Execution =+` | `Lot_Type`, `Lot_Strategy_Size` |
    | `+= Signal Statistics Export =+` | `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id` |
    | `+= ML Shadow Inference =+` | `ML_Inference_Mode`, `ML_Model_Export_Id` |
    | `+= Pattern Audit Playback =+` | `Enable_Pattern_Audit_Overlay`, `Pattern_Audit_Set_Id` |
    | `+= Developer Debug Settings =+` | `Enable_Logs`, `Enable_File_Logs` |

  - Reduce `Lot_Type` to `EXECUTION_LOT_FIXED_SIZE=0` and `EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT=1`.
  - Define `Lot_Strategy_Size` as lots in fixed mode and percent of live account balance risked at the planned stop in percentage mode.
  - Use one position per intrinsic attempt, one broker-side stop, and a fixed 1R broker-side take profit.
  - Keep market-data collection active on non-hedging accounts, but fail broker execution closed because multiple attempt-owned tickets cannot be reconciled safely on netting/exchange accounts.
  - Replace the license-derived magic number with a stable nonzero internal magic derived from a fixed EA namespace and `_Symbol`.
  - Capture broker checks at attempt observation and again immediately before a send; only the pre-send result can authorize the order.
  - Replace schema v7 with schema v8 and update current MQL5/Python ML and audit tooling.
  - Remove active compatibility branches for schemas v4-v7 and removed input semantics. Historical artifacts stay immutable and require their historical code revision.
  - Remove license/addon/session product documentation and rewrite active architecture, workflow, environment, and agent guidance.
  - Record before/after MQL5 file count and line count to demonstrate net context reduction.
- **Out of scope**:
  - Adding a raw tick database, external scraper service, REST API, message queue, or remote executor protocol.
  - Adding another signal engine, timeframe, indicator confirmation, direction selector, or concurrency selector.
  - Reintroducing a configurable spread threshold, drawdown guard, trading-hours filter, daily budget, lot sequence, multiplier, variable R target, partial TP, or multi-leg grid.
  - Migrating old `.set` files, license-derived magic numbers, open broker positions, schema v4-v7 datasets, or historical model exports.
  - Approving a model for MT5 runtime. Schema v8 model artifacts remain research-only until a separate plan authorizes one.
  - Adding MQL5 unit tests, custom Strategy Tester harnesses, test EAs/scripts, agentic MQL5 CI, or new test modules.
  - Editing archived plans or research evidence other than adding an archive index link at final closeout.
- **Fixed decisions**:
  - `EXTREMUM_V1` remains always on, M1, both directions by structural derivation, and unrestricted by a configurable concurrency limit.
  - The engine still deduplicates the same source/revision so an unchanged extremum does not emit repeated broker orders every bar.
  - Spread is exported as a market fact but is not an admission threshold.
  - Actual broker trading sessions and symbol trade modes remain hard execution checks and are never replaced by normalized analysis time.
  - Broker execution requires `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`. Other account margin modes still collect/export attempts and broker checks but must record an unsupported-margin-mode block and never send an order.
  - Mandatory broker checks run before tester-only ML or pattern-audit filtering and run again immediately before `OrderSend`.
  - Signal observation and broker eligibility checks run regardless of `Enable_Signal_Feature_Export`; that input controls persistence, not whether safety facts are gathered.
  - `ML_INFERENCE_SHADOW` cannot change execution. `ML_INFERENCE_FILTER` remains Strategy Tester-only and may only deny an otherwise broker-eligible entry.
  - Broker-side SL and TP are required for new orders; local state does not own a virtual-only stop or target.
  - Broker state remains authoritative after a fill for ticket, volume, entry price, SL/TP, close state, and realized profit.
  - Schema v8 stores both broker time and normalized analysis time. Durations, causal ordering, and broker lifecycle ordering use broker time; session, weekday, cyclical time, normalized calendar grouping, and pattern matching use analysis time. Any duplicate analysis timestamp is ordered by broker time and stable event identity.
  - No MetaEditor syntax check or compile runs in Sprints 1-5. Sprint 6 owns the first and final compilation gate for the whole implementation.
  - No new MQL5 test or CI files are created. Existing Python data-contract tests may be updated in place because they validate exported data tooling, not MQL5 runtime behavior.
- **Assumptions**:
  - The prohibition on custom tests applies to MQL5 harnesses/modules and new CI. Existing compact Python schema fixtures remain maintainable and will be updated rather than replaced by new test modules.
  - Only one instance of this EA runs per account and symbol. A configurable instance/magic input is intentionally not retained.
  - The stable internal magic may differ from every license-derived historical magic; live deployment occurs only when old-version positions for the symbol are flat.
  - Exness US30 and most Exness instruments follow US DST. Known Exness UK-DST metal exceptions are handled from their base symbol prefix rather than silently applying the US rule.
  - Holiday closures, one-off broker schedule changes, missing ticks, and maintenance pauses remain raw broker facts; the system does not fabricate missing market data.

## Deterministic Time Contract

| Mode | Raw broker timestamp | Analysis timestamp | Execution effect |
| --- | --- | --- | --- |
| `FIXED_TIME_SESSIONS` | Preserved | Same as broker time | None |
| `EXNESS_SESSION`, US-DST instrument, summer | Preserved, for example `13:30` | `13:30`, offset `0` | None |
| `EXNESS_SESSION`, US-DST instrument, winter | Preserved, for example `14:30` | `13:30`, offset `-60` minutes | None |
| `EXNESS_SESSION`, documented UK-DST exception | Preserved | Adjusted using the Exness UK-DST calendar | None |

Rules:

- Every helper accepts the event's broker timestamp as an argument. It must not substitute local wall-clock time.
- `TimeCurrent()` and bar/extremum timestamps remain the raw runtime sources.
- Analysis time is computed only when constructing export, ML, audit, or display facts.
- Every row with normalized time includes the applied offset or an equivalent manifest/row contract that makes the conversion auditable.
- Offset arithmetic applies to the complete date-time value, including deterministic previous/next-day rollover when normalization crosses midnight.
- DST boundary rows may have duplicate or skipped analysis-clock hours; broker time remains available to disambiguate them.
- File/event chronology never sorts by normalized analysis time alone; use broker time plus stable event identity as the causal ordering key.
- `Broker_Session` is a time-basis selector, not an execution-hours selector.

## Named Resources

- **Project instructions**:
  - `AGENTS.md`
  - `README.md`
  - `docs/plans/README.md`
  - `$planner` execution handoff: `/home/loldlm/.codex/skills/planner/references/execution-state.md`
- **Primary implementation files**:
  - `HFT_Grid_AI.mq5`
  - `services/core/enums.mqh`
  - `services/core/base_structures.mqh`
  - `services/trading_tools.mqh`
  - `services/trading_management.mqh`
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_management/extremum_engine_config.mqh`
  - `services/trading_management/market_conditions_functions.mqh`
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/utils/broker_constraints_helper.mqh`
  - `services/utils/time_offset_helper.mqh` (replace with `services/utils/market_data_time.mqh`)
  - `services/trading_signals.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/market_status_controller.mqh`
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/execution_lot_math.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
  - `services/trading_signals/execution_logging.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/extremum_engine_state.mqh`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
- **Expected source deletions after references are removed**:
  - `services/license_service_setup.mqh`
  - `services/shared/license_guard_v1/`
  - `services/Bcrypt.mqh`
  - `services/JsonParser.mqh`
  - `services/trading_management/addon_runtime_policy.mqh`
  - `services/trading_management/session_time_filter_context.mqh`
  - `services/trading_signals/session_time_filter_manager.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/signal_lot_strategy.mqh`
  - `services/trading_signals/execution_leg_helpers.mqh`
  - `services/trading_signals/execution_planner.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
  - `services/trading_signals/execution_indicator_cache.mqh`
  - `services/trading_signals/execution_price_resolver.mqh`
  - `services/trading_management/trading_management_strategies.mqh` if present under the canonical name; the current empty file is `services/trading_management_strategies.mqh`
  - `services/trading_management_strategies.mqh`
  - `services/trading_management/strategy_structure_context.mqh` once base-only structure access is direct
  - `services/trading_management/structure_fibonacci_levels.mqh` once no active executor/frontend reference remains
  - `services/trading_signals/market_signal_filters.mqh` once no active filter remains
  - `Chu_Sniper_Trailing_QA.mq5`
  - `services/frontend/ea_license_light_version.mqh`
  - `services/frontend/lightweight_status_layout.mqh`
  - `services/frontend/lightweight_status_ui.mqh`
  - `services/frontend/chart_style_guide.mqh` if no retained execution-line dependency remains
- **Python schema/research files**:
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/validate_phase1_run.py`
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/model_config.py`
  - `tools/deterministic_signal_ml/model_artifact_contract.py`
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/extremum_engine_audit.py`
  - `tools/deterministic_signal_ml/pattern_audit.py`
  - `tools/deterministic_signal_ml/pattern_playback_compare.py`
  - `tools/deterministic_signal_ml/summarize_filter_run.py`
  - `tools/deterministic_signal_ml/README.md`
  - `tools/deterministic_signal_ml/tests/test_extremum_engine_schema.py`
  - `tools/deterministic_signal_ml/tests/test_extremum_engine_research_contract.py`
  - `tools/deterministic_signal_ml/tests/test_extremum_engine_audit.py`
  - Replace `tools/deterministic_signal_ml/tests/fixtures/schema_v7_extremum_engine/` with a schema v8 fixture; do not add another test module.
- **Active documentation**:
  - `AGENTS.md`
  - `README.md`
  - Replace `docs/architecture/execution-foundation.md` with `docs/architecture/market-data-broker-executor.md`
  - `docs/workflows/extremum-engine-statistics-flow.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md`
  - `docs/environment/mt5-agentic-workflows.md`
  - `docs/addons/README.md`
  - `docs/addons/base.md`
  - Delete `docs/addons/session-time-filter.md`
  - `docs/product_copy/en/README.md`
  - `docs/product_copy/en/base-ea.md`
  - Delete `docs/product_copy/en/addon-session-time-filter.md`
  - `docs/product_copy/es/README.md`
  - `docs/product_copy/es/base-ea.md`
  - Delete `docs/product_copy/es/addon-session-time-filter.md`
  - `docs/plans/README.md`
- **Validation resources**:
  - `tools/mt5/compile_mt5.py`
  - MetaEditor under `/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MetaEditor64.exe`
  - MT5 Common Files schema v8 run directory
  - Human Strategy Tester on Exness US30 summer and winter periods
- **Current official documentation**:
  - MQL5 `TimeCurrent`: https://www.mql5.com/en/docs/dateandtime/timecurrent
  - MQL5 `SymbolInfoSessionTrade`: https://www.mql5.com/en/docs/marketinformation/symbolinfosessiontrade
  - MQL5 symbol trade mode, stops/freeze, and volume properties: https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
  - MQL5 `OrderCalcMargin`: https://www.mql5.com/en/docs/trading/ordercalcmargin
  - MQL5 `OrderCalcProfit`: https://www.mql5.com/en/docs/trading/ordercalcprofit
  - MQL5 `OrderCheck`: https://www.mql5.com/en/docs/trading/ordercheck
  - MQL5 account margin modes: https://www.mql5.com/en/docs/constants/environment_state/accountinformation#enum_account_margin_mode
  - Exness instrument trading hours and DST policy, updated 2026-07-28: https://get.exness.help/hc/en-us/articles/4405235684498-Instrument-trading-hours

## Prerequisites

- Begin execution from a clean working tree based on commit `a502e28460dba295bdc0194b7a0eaf72364285e0` or record the actual replacement baseline before Sprint 1.
- Read `/home/loldlm/.codex/skills/planner/references/execution-state.md` and initialize active-plan state before editing implementation files.
- Record baseline tracked `.mq5`/`.mqh` file count and total line count without storing full file contents in evidence.
- Confirm no live account has open positions owned by the old license-derived magic for the target symbol. If positions exist, keep the old EA deployed until flat; do not force migration.
- Record the demo/tester account margin mode. Only `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` may execute; other modes are accepted for collection-only validation.
- Use demo or Strategy Tester for implementation acceptance. Live rollout is not part of this plan.
- Preserve existing external schema v7 run folders, datasets, audits, and models. Schema v8 uses new IDs and directories.
- Keep the current pinned Python environment. Do not add packages.

## Sprint 1: Remove Commercial, Account, Protection, And User Session Layers

**Goal**: The extremum engine runs continuously without licensing, configurable account/protection controls, user session windows, spread threshold, direction mode, or concurrency mode, while retaining actual broker market-status checks and a stable internal execution identity.
**Dependencies**: Prerequisites and clean baseline.
**Tracked scope**: transition instructions and plan index, `HFT_Grid_AI.mq5`, input/enums/aggregators, license/session/protection services, market status, logging, and license/status frontend files.
**Commit**: `refactor: remove legacy commercial and runtime gates`
**Demo/Validation**:

- Static input inspection shows the five removed groups are absent; the Strategy Risk group may remain only until Sprint 2.
- Static source inspection shows no license initialization, online result upload, entitlement request, removal timer, user session gate, drawdown protection gate, `Max_Spread` threshold, direction gate, or concurrency gate remains.
- The active instructions explicitly authorize the ordered simplification and state that Sprints 1-5 use static/Python logic validation only; the final real compile is reserved for Sprint 6.
- No MetaEditor command runs in this sprint.

**Rollback point**: The pre-Sprint 1 baseline commit. Revert the single Sprint 1 commit to restore the complete license/protection/session behavior.

### Task 1.0: Align Transition Instructions Before Code Changes

- **Location**: `AGENTS.md`, `docs/plans/README.md`.
- **Description**: Mark this plan as the active implementation plan and add a temporary transition contract before touching runtime files. The contract must explicitly authorize removal of the legacy license/account/protection/session layers, prohibit MQL5 harnesses/custom modules/CI, require static logic review in Sprints 1-5, and reserve the first and only MetaEditor compile for Sprint 6. Keep the final architecture wording for Sprint 5, but do not leave instructions that tell an implementer to preserve controls this plan removes.
- **Dependencies**: Prerequisites only.
- **Acceptance criteria**:
  - `docs/plans/README.md` links to this plan as active.
  - `AGENTS.md` contains no instruction that conflicts with the plan's explicit user decisions during Sprints 1-4.
  - The transition text preserves the non-negotiable broker-safety checks and the `ML_INFERENCE_SHADOW`/tester-only `ML_INFERENCE_FILTER` boundaries.
- **Validation**:
  - `rg -n 'market-data-broker-executor-simplification|final.*compile|No custom MQL5|MQL5.*CI|Broker_Session' AGENTS.md docs/plans/README.md`
  - `git diff --check`
- **Rollback**: Revert the Sprint 1 commit; restore the prior active-plan link and transition wording together with the runtime changes.

### Task 1.1: Remove Licensing And Establish Stable Internal Magic

- **Location**: `HFT_Grid_AI.mq5`, `services/license_service_setup.mqh`, `services/shared/license_guard_v1/`, `services/Bcrypt.mqh`, `services/JsonParser.mqh`, `services/trading_management/addon_runtime_policy.mqh`, `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/execution_logging.mqh`.
- **Description**: Delete license validation, entitlement mapping, online daily results, WebRequest dependencies, lifecycle removal callbacks, the license timer, and the `Custom_Magic` input. Introduce one stable nonzero `ulong` execution magic derived from a fixed EA namespace and `_Symbol`; set it during `OnInit` and use it consistently for order requests and ticket/symbol reconciliation. Do not derive it from `ChartID`, time, account number, or mutable runtime state.
- **Dependencies**: Task 1.0.
- **Acceptance criteria**:
  - `OnInit`, `OnTimer`, and `OnDeinit` have no license lifecycle calls; remove `OnTimer` and timer setup when no other timer consumer remains.
  - All license and encryption/parser files listed above are deleted after reference checks.
  - The internal magic is stable across restarts for the same symbol and cannot be zero.
  - Position selection remains ticket-first and then verifies symbol plus the internal magic.
  - No account number, magic, license key, or former secret is added to public research rows.
- **Validation**:
  - `rg -n 'LicenseService|LicenseGet|EA_License_Key|Custom_Magic|LICENSE_SHARED_|WebRequest|EALifecycle|EventSetTimer|OnTimer' HFT_Grid_AI.mq5 services --glob '*.mq5' --glob '*.mqh'`
  - `rg -n 'g_execution_magic|request\.magic|POSITION_MAGIC' HFT_Grid_AI.mq5 services/trading_signals --glob '*.mq5' --glob '*.mqh'`
- **Rollback**: Revert Sprint 1 as one unit; partial restoration is unsafe because historical magic ownership depends on the license service.

### Task 1.2: Remove User Session Filtering And Add Analysis-Time Selection

- **Location**: `services/trading_management/ea_inputs.mqh`, `services/core/enums.mqh`, `services/utils/time_offset_helper.mqh`, new `services/utils/market_data_time.mqh`, `services/trading_management/session_time_filter_context.mqh`, `services/trading_signals/session_time_filter_manager.mqh`, `services/trading_management.mqh`, `services/trading_signals.mqh`, `HFT_Grid_AI.mq5`.
- **Description**: Delete Asia/London/New York allow/force-close windows, manual DST offsets, runtime session monitoring, force-close queues, and session addon coupling. Add `BrokerSessionTimeModes` with exactly `FIXED_TIME_SESSIONS=0` and `EXNESS_SESSION=1`, plus `input BrokerSessionTimeModes Broker_Session = FIXED_TIME_SESSIONS`. Replace the old offset helper with a small analysis-time helper implementing the deterministic time contract.
- **Dependencies**: Task 1.1 removes addon entitlement dependencies.
- **Acceptance criteria**:
  - No user-configured session window can block, delay, or force-close a signal.
  - `Broker_Session` is the only time-basis input.
  - `FIXED_TIME_SESSIONS` returns the original timestamp with zero offset.
  - `EXNESS_SESSION` follows official US DST for US30/most instruments and official UK DST for documented exception prefixes, including broker suffix-safe symbol matching.
  - The helper does not read `TimeLocal()` and does not change `OnTick` bar scheduling.
- **Validation**:
  - `rg -n 'Session_(Asia|London|NewYork|Time_Dst)|SessionTimeFilter|SESSION_FILTER_|DST_MODE_|addon_session_time_filter' HFT_Grid_AI.mq5 services --glob '*.mq5' --glob '*.mqh'`
  - `rg -n 'FIXED_TIME_SESSIONS|EXNESS_SESSION|Broker_Session|Normalize.*Analysis|offset_minutes' services --glob '*.mqh'`
- **Rollback**: Revert Sprint 1; schema v8 has not started, so no data migration is needed yet.

### Task 1.3: Remove Configurable Protection, Spread, Direction, And Concurrency Gates

- **Location**: `services/trading_management/ea_inputs.mqh`, `services/core/enums.mqh`, `services/trading_signals/protection_risk_filter.mqh`, `services/trading_signals/market_signal_state.mqh`, `services/trading_signals/market_signal_detection.mqh`, `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/market_status_controller.mqh`, `HFT_Grid_AI.mq5`.
- **Description**: Delete drawdown thresholds, account-size fallback, market-close guard, protection locks, configured direction checks, configured concurrency checks, and `Max_Spread` admission. Preserve and simplify market status around actual `SYMBOL_TRADE_MODE`, real broker sessions, account margin mode, and direction-specific LONGONLY/SHORTONLY behavior. Continue observing spread without blocking on a configured maximum. A non-hedging account may continue collecting data, but execution must remain fail-closed.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance criteria**:
  - Both directions are derived only from PEAK/BOTTOM structure.
  - Multiple distinct attempts may coexist; same-source dedupe remains.
  - `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` is the only mode that can authorize a broker send; netting/exchange modes produce a recorded unsupported-margin-mode block and no order.
  - Unsupported account margin mode no longer returns `INIT_FAILED`; the engine remains available for collection and analysis.
  - CLOSEONLY, DISABLED, LONGONLY, and SHORTONLY modes produce direction-correct broker eligibility facts.
  - Market-status failure blocks new sends but does not overwrite broker facts or trigger a removed protection force-close path.
  - High spread is recorded and visible but is not itself a block reason.
- **Validation**:
  - `rg -n 'Protection_Risk_|Account_Size|Market_Close_Guard|Max_Spread|Strategy_Direction_Mode|Signal_Concurrency_Mode|ProtectionRisk|DirectionAllowed|SignalConcurrencyAllowsAttempt' HFT_Grid_AI.mq5 services --glob '*.mq5' --glob '*.mqh'`
  - `rg -n 'ACCOUNT_MARGIN_MODE|INIT_FAILED|SYMBOL_TRADE_MODE|SymbolInfoSessionTrade|spread_points|LONGONLY|SHORTONLY|CLOSEONLY|DISABLED' HFT_Grid_AI.mq5 services --glob '*.mq5' --glob '*.mqh'`
- **Rollback**: Revert the full Sprint 1 commit; do not cherry-pick only protection code back into the new magic/session shell.

### Task 1.4: Remove License/Addon Status UI Coupling

- **Location**: `services/frontend.mqh`, `services/frontend/ea_license_light_version.mqh`, `services/frontend/lightweight_status_ui.mqh`, `services/frontend/lightweight_status_layout.mqh`, `services/frontend/execution_visualization.mqh`, `HFT_Grid_AI.mq5`.
- **Description**: Remove license panels, addon rows, manual execution toggle, persistent license error rendering, and chart event handling that only supports the old UI. Retain only chart work that materially supports human inspection of current entry/SL/TP when it remains cheap and independent of trading decisions.
- **Dependencies**: Tasks 1.1-1.3.
- **Acceptance criteria**:
  - Frontend code cannot toggle execution state or depend on entitlement data.
  - Non-visual Strategy Tester remains free of chart work.
  - No chart object or UI variable participates in broker eligibility.
- **Validation**:
  - `rg -n 'CreateLicensePanel|CollectAddonUiState|LicenseCopy|EA_CHART_ERROR|ManualSignalEntryEnabled|SetManualSignalEntryEnabled' HFT_Grid_AI.mq5 services/frontend services/trading_signals --glob '*.mq5' --glob '*.mqh'`
  - `git diff --check`
- **Rollback**: Revert Sprint 1.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Static Sprint 1 validation passes and evidence records only relevant matches/counts.
- [ ] No MetaEditor compile or syntax check was run.
- [ ] Residual risks, especially internal magic ownership and live-position incompatibility, are documented.
- [ ] Exactly one Sprint 1 commit is created with the proposed sprint message.
- [ ] The Sprint 1 commit hash is recorded as the rollback point.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Replace Multi-Leg Risk Logic With One Broker Position

**Goal**: Every accepted extremum attempt owns one small execution state and at most one broker position, with fixed or balance-percentage lot sizing, broker-side SL, fixed 1R TP, and mandatory pre-send checks.
**Dependencies**: Sprint 1 gate.
**Tracked scope**: Signal/execution structs, lot math, planner/controller/lifecycle, broker checks, reconciliation, logging, and tick cleanup.
**Commit**: `refactor: reduce execution to one broker position`
**Demo/Validation**:

- Static call tracing shows one order state per signal and no multi-leg, multiplier, partial-TP, daily-limit, or target-currency branch.
- Mandatory broker checks are present at observation and pre-send, and only the pre-send result authorizes `OrderSend`.
- No MetaEditor command runs in this sprint.

**Rollback point**: Sprint 1 commit. Revert Sprint 2 to restore the old multi-leg execution implementation on top of the simplified shell only for diagnosis; do not deploy that mixed rollback live.

### Task 2.1: Finalize The Minimal Input And Enum Surface

- **Location**: `services/trading_management/ea_inputs.mqh`, `services/core/enums.mqh`.
- **Description**: Remove `Lot_Multiplier`, `Signal_Lot_Strategy`, `TP_Percent`, `Partial_TP_Mode`, `Daily_Signal_Limit`, and `Daily_Signal_Limit_Mode`. Replace the Strategy Risk group with the two-field Broker Execution group. Delete enums/constants used only by removed settings, multi-leg states, strategy contexts, entry styles, and obsolete range compatibility where no active engine dependency remains.
- **Dependencies**: Sprint 1 final input removals.
- **Acceptance criteria**:
  - The final input table in Scope is exact; no additional `input` declarations remain.
  - `ExecutionLotTypes` contains only fixed size ordinal `0` and account-balance percentage ordinal `1`.
  - Removed enum names are absent from active source.
- **Validation**:
  - `rg -n '^input group|^input\b' services/trading_management/ea_inputs.mqh`
  - `rg -n 'Lot_Multiplier|Signal_Lot_Strategy|TP_Percent|Partial_TP|Daily_Signal|EXECUTION_LOT_TARGET_CURRENCY|SignalLotStrategy|DailySignalLimit' HFT_Grid_AI.mq5 services --glob '*.mq5' --glob '*.mqh'`
- **Rollback**: Revert Sprint 2.

### Task 2.2: Collapse Signal State To One Execution Order

- **Location**: `services/trading_signals/signal_params_struct.mqh`, `services/trading_signals/execution_leg_helpers.mqh`, `services/trading_signals/execution_planner.mqh`, `services/trading_signals/execution_lifecycle.mqh`, `services/trading_signals/execution_controller.mqh`, `services/trading_signals/tick_signals_manager.mqh`.
- **Description**: Replace `ExecutionLegState execution_legs[]` and partial-TP fields with one explicit execution state containing planned entry, stop, 1R target, requested/normalized lot, broker ticket, broker entry/close facts, send/check status, and terminal reason. Keep the existing `SignalParams` name unless a smaller direct rename clearly reduces code without adding adapters. Delete generic grid/leg helpers rather than leaving always-false branches.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - One signal cannot own multiple tickets or execution legs.
  - Waiting, send-attempted, broker-active, broker-closed, canceled, and failed states are explicit.
  - Source dedupe and revision expiration do not cancel or overwrite a broker-active position.
  - All removed array/partial-TP fields disappear from constructors and copy constructors.
- **Validation**:
  - `rg -n 'execution_legs|ExecutionLegState|level_index|next_level|partial_tp|basket|signal_lot_sequence' services/trading_signals --glob '*.mqh'`
  - `rg -n 'position_ticket|broker_entry_confirmed|broker_close_confirmed|realized_profit|terminal_reason' services/trading_signals/signal_params_struct.mqh services/trading_signals/execution_controller.mqh services/trading_signals/execution_broker_reconciliation.mqh`
- **Rollback**: Revert Sprint 2 as one unit; state layout and lifecycle code must stay aligned.

### Task 2.3: Implement Two Fail-Closed Lot Modes And Fixed 1R Geometry

- **Location**: `services/trading_signals/execution_lot_math.mqh`, `services/trading_signals/execution_controller.mqh`, `services/utils/broker_constraints_helper.mqh`.
- **Description**: In fixed mode, treat `Lot_Strategy_Size` as requested lots. In percentage mode, calculate the risk budget from current `ACCOUNT_BALANCE`, then use `OrderCalcProfit` from the current pre-send entry side to the structural stop to solve loss per lot. Normalize volume down to broker step/max without silently increasing risk to the broker minimum. Define TP as exactly one planned risk distance from entry; remove variable TP and target-currency math.
- **Dependencies**: Task 2.2.
- **Acceptance criteria**:
  - Invalid balance, stop distance, `OrderCalcProfit`, volume, or minimum-volume risk fails closed and records an actionable reason.
  - Fixed mode never silently increases a below-minimum request.
  - Percentage mode never rounds volume upward above the risk budget.
  - TP is bullish `entry + risk` or bearish `entry - risk` and remains directionally valid.
- **Validation**:
  - `rg -n 'ACCOUNT_BALANCE|OrderCalcProfit|SYMBOL_VOLUME_MIN|SYMBOL_VOLUME_MAX|SYMBOL_VOLUME_STEP|Normalize.*Volume|risk_budget|1R' services/trading_signals/execution_lot_math.mqh services/trading_signals/execution_controller.mqh`
  - Code review truth table for fixed lot, percentage lot, below-minimum volume, above-maximum volume, invalid stop, and zero balance.
- **Rollback**: Revert Sprint 2.

### Task 2.4: Enforce Observation And Pre-Send Broker Checks

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_management/market_conditions_functions.mqh`, `services/trading_signals/market_status_controller.mqh`, `services/trading_signals/market_signal_detection.mqh`, `services/trading_signals/execution_controller.mqh`.
- **Description**: Define one broker snapshot/check result that captures symbol, direction, account margin mode, raw time, bid/ask/spread, trade mode, actual session-open state, terminal/MQL trade permission, stops/freeze levels, requested/normalized volume, free/required margin, entry/SL/TP distance validity, and `OrderCheck` facts. Record an observation snapshot for every intrinsic attempt and recapture all mutable facts immediately before send. Observation may be incomplete for `OrderCheck`; pre-send must be complete and allowed. A non-hedging margin mode is an explicit execution block, never a reason to stop market-data collection.
- **Dependencies**: Tasks 2.2-2.3.
- **Acceptance criteria**:
  - No order send path exists outside the pre-send check function.
  - Actual market closure, direction-incompatible trade mode, invalid stops/freeze, invalid volume, insufficient margin, disabled Algo Trading, or failed `OrderCheck` blocks the send.
  - High spread alone does not block.
  - Check phase and block source/reason are explicit for later schema export.
- **Validation**:
  - `rg -n 'OrderSend|OrderCheck|OrderCalcMargin|ACCOUNT_MARGIN_MODE|SymbolInfoSessionTrade|SYMBOL_TRADE_STOPS_LEVEL|SYMBOL_TRADE_FREEZE_LEVEL|SYMBOL_TRADE_MODE|TERMINAL_TRADE_ALLOWED|MQL_TRADE_ALLOWED' HFT_Grid_AI.mq5 services/trading_signals services/trading_management --glob '*.mq5' --glob '*.mqh'`
  - Static call trace confirms each `OrderSend` call is dominated by the pre-send eligibility result.
- **Rollback**: Revert Sprint 2.

### Task 2.5: Send Broker-Side Protection And Reconcile Broker Facts

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/tick_signals_manager.mqh`, `services/trading_signals/execution_logging.mqh`.
- **Description**: Submit one market request with normalized volume, internal magic, structural SL, and fixed 1R TP. Capture retcode/ticket without treating local send success as a confirmed fill. Reconcile ticket-first and derive close state/profit from broker history/position facts. Preserve symbol/magic scoping and keep local state from overwriting broker entry, volume, close, or realized profit.
- **Dependencies**: Task 2.4.
- **Acceptance criteria**:
  - Every new order request has nonzero SL and TP that passed broker-distance checks.
  - Broker fill confirmation, not `OrderSend` alone, marks the execution active.
  - Broker close confirmation is required for broker outcome rows.
  - Cleanup of a canceled no-position attempt cannot close or mutate unrelated positions.
- **Validation**:
  - `rg -n 'request\.sl|request\.tp|request\.magic|OrderSend|TRADE_RETCODE|PositionSelectByTicket|HistoryDeal|POSITION_MAGIC|POSITION_SYMBOL' services/trading_signals --glob '*.mqh'`
  - `git diff --check`
- **Rollback**: Revert Sprint 2; do not run an old and new executor concurrently on the same account/symbol.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] Static execution and lot truth-table reviews pass.
- [ ] No removed multi-leg/risk identifier remains in active source.
- [ ] No MetaEditor compile or syntax check was run.
- [ ] Exactly one Sprint 2 commit is created with the proposed sprint message.
- [ ] The Sprint 2 commit hash is recorded as the rollback point.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Introduce Schema V8 Broker And Analysis Facts

**Goal**: MQL5 exports an auditable schema v8 that pairs raw broker time with normalized analysis time and records broker safety checks for every attempt without retaining obsolete admission/leg contracts.
**Dependencies**: Sprint 2 gate.
**Tracked scope**: Time helper, statistics exporter, ML inference, pattern playback, execution-check callbacks, and MQL5 schema constants.
**Commit**: `feat: export deterministic broker checks in schema v8`
**Demo/Validation**:

- Static headers and row builders agree on the schema v8 file set.
- Time-derived features use analysis time; broker durations/reconciliation use broker time.
- Existing ML and pattern inputs remain present and their execution boundaries remain fail-closed.
- No MetaEditor command runs in this sprint.

**Rollback point**: Sprint 2 commit. Revert Sprint 3 to restore the pre-v8 source state; preserve any generated v8 folders and never relabel them as v7.

### Task 3.1: Define The Schema V8 File Contract

- **Location**: `services/trading_signals/deterministic_signal_statistics_export.mqh`.
- **Description**: Set schema version 8 and use exactly these run files: `run_manifest.tsv`, `engine_cycles.tsv`, `engine_revisions.tsv`, `engine_attempts.tsv`, `execution_checks.tsv`, `signal_features.tsv`, `signal_outcomes.tsv`, and `run_summary.tsv`. Delete `signal_admissions.tsv` and `signal_leg_outcomes.tsv` generation. Preserve simulated attempt outcomes in `engine_attempts.tsv` and broker-confirmed results in `signal_outcomes.tsv`.
- **Dependencies**: Sprint 2 single-position state.
- **Acceptance criteria**:
  - Each header has one matching row builder and one summary counter.
  - No leg table or configurable-risk fields remain.
  - Manifest records schema, engine, timeframe, lot mode/size, broker-session mode, time policy, and configuration ID.
  - Configuration ID excludes removed inputs and includes `Broker_Session`.
- **Validation**:
  - `rg -n 'SCHEMA_VERSION|HEADER|signal_admissions|signal_leg_outcomes|execution_checks|run_summary' services/trading_signals/deterministic_signal_statistics_export.mqh`
  - Manual column-count comparison between every v8 header and its row builder.
- **Rollback**: Revert Sprint 3.

### Task 3.2: Pair Broker And Analysis Timestamps

- **Location**: `services/utils/market_data_time.mqh`, `services/trading_signals/deterministic_signal_statistics_export.mqh`, `services/trading_signals/signal_params_struct.mqh`, `services/trading_signals/extremum_engine_state.mqh`.
- **Description**: Replace ambiguous event timestamp columns with explicit broker/analysis pairs and applied offset for run, cycle, revision, attempt, check, feature, entry, and outcome events. Keep raw broker timestamps in runtime state; compute analysis fields only while exporting or constructing research features.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Every normalized timestamp can be traced to its raw timestamp and offset.
  - Outcome duration and M1-bar duration use broker timestamps.
  - Causal row ordering and chronological split order use broker time; duplicate normalized timestamps cannot reorder observations.
  - `entry_session_bucket`, `entry_weekday`, `session_id`, `time_sin`, and `time_cos` use analysis entry time.
  - `FIXED_TIME_SESSIONS` produces equality between paired fields.
- **Validation**:
  - `rg -n 'broker_time|analysis_time|offset_minutes|entry_session_bucket|entry_weekday|time_sin|time_cos' services/trading_signals/deterministic_signal_statistics_export.mqh services/utils/market_data_time.mqh`
  - Static search confirms normalization helpers are not used for bar scheduling, actual session checks, margin, price, or `OrderSend` timing.
- **Rollback**: Revert Sprint 3; do not convert v8 rows in place.

### Task 3.3: Export Observation And Pre-Send Check Rows

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/market_signal_detection.mqh`, `services/trading_signals/execution_controller.mqh`, `services/trading_signals/deterministic_signal_statistics_export.mqh`.
- **Description**: Append `execution_checks.tsv` rows for at least `ATTEMPT_OBSERVED`, `PRE_SEND`, `SEND_RESULT`, and terminal/reconciliation events where relevant. Include broker constraints, prices, spread, trade/session permissions, lot/margin facts, distance checks, `OrderCheck`, final status, and block source/reason. Deduplicate repeated identical check events without suppressing changed broker facts.
- **Dependencies**: Task 3.2 and Sprint 2 snapshot contract.
- **Acceptance criteria**:
  - Every intrinsic attempt has an observation check row even when execution is impossible.
  - When export is enabled, every runtime observation has a corresponding `ATTEMPT_OBSERVED` row; disabling export does not skip the check logic.
  - Every observation row records account margin mode and an explicit unsupported-margin-mode block when the account is not hedging.
  - Every send attempt has a pre-send row and send-result row.
  - Each check row carries stable run/cycle/revision/attempt identity, a monotonic check sequence, phase, broker/analysis timestamps, and a machine-readable block source/reason.
  - Failed checks never create broker outcome rows.
  - Export buffering remains bounded and flushes on normal deinit.
- **Validation**:
  - Static call trace from `TryCreateExtremumEngineSignal` and the send path to the exporter.
  - `rg -n 'ATTEMPT_OBSERVED|PRE_SEND|SEND_RESULT|execution_checks|block_source|order_check_retcode' services/trading_signals --glob '*.mqh'`
- **Rollback**: Revert Sprint 3.

### Task 3.4: Cut MQL5 ML And Pattern Playback To V8

- **Location**: `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`, `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`, `docs/workflows/deterministic-signal-ml-inference-flows.md` only if needed later in Sprint 5; implementation changes remain here.
- **Description**: Require exact schema v8/feature-set identity, construct time features from analysis time, and compare pattern observations using analysis time while retaining broker time in observation output. Remove schema-specific compatibility branches for v4-v7. Keep SHADOW passive and FILTER tester-only after mandatory broker checks and before broker send.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance criteria**:
  - No schema v8 runtime model is approved by this sprint.
  - Old or unapproved artifacts fail with one generic incompatible/not-approved path rather than legacy adapters.
  - Live runtime cannot enable FILTER.
  - ML/pattern denial records a check/admission reason without mutating lot, SL, TP, or broker facts.
- **Validation**:
  - `rg -n 'schema_v[4-7]|SCHEMA_VERSION = [4-7]|APPROVED_FOR_MT5_RUNTIME|MQL_TESTER|ML_INFERENCE_FILTER|analysis_time' services/trading_signals/deterministic_signal_* --glob '*.mqh'`
  - `git diff --check`
- **Rollback**: Revert Sprint 3.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] Schema header/row/counter review is complete.
- [ ] Time normalization is isolated from execution timing and actual market-session checks.
- [ ] No MetaEditor compile or syntax check was run.
- [ ] Exactly one Sprint 3 commit is created with the proposed sprint message.
- [ ] The Sprint 3 commit hash is recorded as the rollback point.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Cut Python Research Tooling To Schema V8

**Goal**: Current validators, Parquet assembly, audits, training, model contracts, and pattern comparison consume only schema v8 and enforce the raw/normalized time and broker-check contracts.
**Dependencies**: Sprint 3 gate.
**Tracked scope**: `tools/deterministic_signal_ml/` and its existing tests/fixture; no new dependency or test module.
**Commit**: `refactor: cut research tooling over to schema v8`
**Demo/Validation**:

- The updated schema v8 fixture validates, builds Parquet, and supports existing audit/research commands.
- Invalid time conversion, missing broker checks, orphan genealogy, simulated/broker mixing, and unapproved model artifacts fail closed through existing test modules.
- This sprint runs Python checks only; no MetaEditor command runs.

**Rollback point**: Sprint 3 commit. Revert Sprint 4 to restore v7 Python tooling; it will intentionally be incompatible with v8 exports.

### Task 4.1: Replace The Active Python Schema Contract

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`, `tools/deterministic_signal_ml/validate_phase1_run.py`.
- **Description**: Make 8 the sole active schema, define the new file/column set, remove active v4-v7 selection branches, validate broker/analysis timestamp plus offset consistency, and validate one observation check per attempt plus one pre-send/send-result chain per send attempt.
- **Dependencies**: Sprint 3 exact headers.
- **Acceptance criteria**:
  - `SUPPORTED_SCHEMA_VERSION == 8` and active compatibility tuples/maps do not list 4-7.
  - The validator rejects missing/extra files, duplicate IDs, orphan genealogy, inconsistent time conversion, impossible broker check ordering, and broker outcomes without confirmed entry/close facts.
  - Historical schema errors state that the historical code revision is required; they do not attempt migration.
- **Validation**:
  - `.venv/bin/python -m compileall tools/deterministic_signal_ml`
  - Existing schema test module, after in-place update.
- **Rollback**: Revert Sprint 4.

### Task 4.2: Update Dataset Assembly And Audit Semantics

- **Location**: `tools/deterministic_signal_ml/build_dataset.py`, `tools/deterministic_signal_ml/extremum_engine_audit.py`, `tools/deterministic_signal_ml/pattern_audit.py`, `tools/deterministic_signal_ml/report_writer.py`.
- **Description**: Read `execution_checks.tsv`, use analysis time for normalized calendar partition labels plus month/session/weekday features, retain broker time for causal ordering, duration, and event audit, and remove leg/admission joins. Keep engine simulation and broker outcome target families separate.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Parquet outputs mirror the schema v8 file set and include a typed execution-check table.
  - Training matrix point-in-time features cannot read final cycle or later broker facts.
  - Audits can compare broker eligibility/block reasons without conflating high spread observation with a threshold denial.
- **Validation**:
  - Build the in-repository v8 fixture with `--validate-only` and normal build into a temporary ignored artifact ID.
  - Compact DuckDB row counts for cycles, revisions, attempts, checks, features, outcomes, and training matrix.
- **Rollback**: Revert Sprint 4 and remove only temporary ignored outputs created for this sprint.

### Task 4.3: Update Model, Training, And Pattern Contracts

- **Location**: `tools/deterministic_signal_ml/model_config.py`, `tools/deterministic_signal_ml/model_artifact_contract.py`, `tools/deterministic_signal_ml/model_artifact_validator.py`, `tools/deterministic_signal_ml/train_model.py`, `tools/deterministic_signal_ml/pattern_playback_compare.py`, `tools/deterministic_signal_ml/summarize_filter_run.py`.
- **Description**: Introduce `schema_v8_extremum_engine_xgb`, require phase/schema 8, use broker time for causal chronological ordering with analysis time for normalized calendar groups/features, and remove old feature-set adapters. Keep runtime approval fail-closed and report broker-check denial categories separately from tester-only ML/pattern denials.
- **Dependencies**: Task 4.2.
- **Acceptance criteria**:
  - No v4-v7 feature-set ID is accepted by current training/runtime validation.
  - Research exports remain `RESEARCH_ONLY_NOT_APPROVED` by default.
  - Pattern comparison includes expected/observed analysis time and retains raw broker time for audit.
- **Validation**:
  - Existing research-contract and audit test modules after in-place update.
  - A compact fixture training invocation may stop for insufficient support but must pass schema/feature compatibility first.
- **Rollback**: Revert Sprint 4.

### Task 4.4: Replace The Existing Fixture Without Adding Tests

- **Location**: replace `tools/deterministic_signal_ml/tests/fixtures/schema_v7_extremum_engine/`; update the three existing `test_extremum_engine_*.py` modules.
- **Description**: Convert the compact fixture to schema v8 and update existing assertions for paired time, execution checks, single-position outcomes, and fail-closed artifacts. Do not create a new test directory hierarchy beyond the replacement fixture and do not add a fourth test module or any MQL5 test file.
- **Dependencies**: Tasks 4.1-4.3.
- **Acceptance criteria**:
  - Fixture includes summer/fixed and winter/Exness timestamp examples.
  - Fixture has one blocked observation and one fully checked broker-confirmed path.
  - Existing tests preserve frozen-anchor, orphan, outcome provenance, cycle split, and model approval checks.
- **Validation**:
  - `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
  - `git diff --check`
- **Rollback**: Revert Sprint 4.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Existing Python compile, unittest, fixture validation, and compact Parquet readback pass.
- [ ] No new test module, MQL5 harness, CI workflow, or dependency was added.
- [ ] No MetaEditor compile or syntax check was run.
- [ ] Exactly one Sprint 4 commit is created with the proposed sprint message.
- [ ] The Sprint 4 commit hash is recorded as the rollback point.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Delete Dead Context And Align Active Documentation

**Goal**: Remove no-op/legacy source and heavy license/status frontend code, simplify the include graph, and make all active instructions describe the market-data/broker-executor contract and current skill stack.
**Dependencies**: Sprint 4 gate.
**Tracked scope**: Remaining source candidates, aggregators, frontend, `AGENTS.md`, README, architecture/workflows/environment/product docs, and plan indexes.
**Commit**: `docs: align the market data broker executor foundation`
**Demo/Validation**:

- Active source has a smaller one-way include graph and net line/file deletion from baseline.
- Active docs contain no claims that license, user sessions, spread threshold, protection, multi-leg risk, or schema v7 remain.
- Repository policy clearly prohibits MQL5 harness/CI and schedules one final compile sprint for substantial multi-sprint MQL5 plans.
- No MetaEditor command runs in this sprint.

**Rollback point**: Sprint 4 commit. Revert Sprint 5 to restore docs/dead files without changing schema v8 runtime behavior.

### Task 5.1: Prune Proven-Dead Execution And Strategy Context

- **Location**: `services/trading_management.mqh`, `services/trading_signals.mqh`, the Expected source deletions list, and all remaining active `.mqh` references.
- **Description**: Use the canonical include closure and `rg` references to delete empty aggregators, no-op structure contexts, generic filters, old ATR/range/grid helpers, multi-leg files, and the noncanonical QA entrypoint after their consumers are gone. Do not delete `indicators/Stochastic_Structure.mq5`, `indicators/BB_Percent_Standard.mq5`, or another indicator source still required by `indicator_definitions_loader.mqh` or the environment workflow.
- **Dependencies**: Sprints 1-4 removed their consumers.
- **Acceptance criteria**:
  - Each deleted file has zero active include/function references immediately before deletion.
  - Aggregators contain one ordered include path with no sibling re-includes or cycles.
  - The active source retains only direct M1 extremum, broker execution, telemetry, ML/pattern, and cheap visualization dependencies.
- **Validation**:
  - `rg -n '#include' HFT_Grid_AI.mq5 services/*.mqh services/**/*.mqh`
  - `rg -n 'strategy_structure_context|structure_fibonacci_levels|market_signal_filters|execution_leg_helpers|execution_planner|execution_lifecycle|execution_indicator_cache|trading_management_strategies' HFT_Grid_AI.mq5 services --glob '*.mq5' --glob '*.mqh'`
  - Record final tracked `.mq5`/`.mqh` count and line count against prerequisites.
- **Rollback**: Revert Sprint 5.

### Task 5.2: Retain Only Minimal Human-Inspection Frontend

- **Location**: `services/frontend.mqh`, `services/frontend/`, `HFT_Grid_AI.mq5`, `services/trading_signals/market_signal_cleanup.mqh`.
- **Description**: Delete the responsive status dashboard, addon/license rows, toggle buttons, and obsolete style machinery. Keep only optional execution entry/SL/TP lines and bounded visual refresh if they materially support human Strategy Tester inspection; otherwise remove the frontend aggregator and chart callbacks entirely. Pattern playback remains file-driven and must not depend on the removed UI.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - No chart UI can enable/disable execution.
  - Visual mode can inspect planned/current entry, SL, and TP if the retained minimal lines are justified.
  - Nonvisual testing performs no chart object work.
  - Frontend removal does not affect ML, statistics, or broker decisions.
- **Validation**:
  - `rg -n 'OBJ_BUTTON|EA_CHART_UI|Addon|License|Enable_Chart_Lightweight_UI|OnChartEvent' HFT_Grid_AI.mq5 services/frontend services/trading_signals --glob '*.mq5' --glob '*.mqh'`
  - Static inspection of the retained chart refresh call path.
- **Rollback**: Revert Sprint 5.

### Task 5.3: Rewrite Project And Architecture Guidance

- **Location**: `AGENTS.md`, `README.md`, `docs/architecture/execution-foundation.md`, new `docs/architecture/market-data-broker-executor.md`, `docs/plans/README.md`.
- **Description**: Replace execution-foundation/risk language with the always-on scraper/executor flow, exact input contract, internal-magic limitation, actual-session versus analysis-time separation, mandatory broker checks, one-position lifecycle, schema v8, and deletion-first maintenance posture. Reconcile the named skill list with the installed `/home/loldlm/.codex/skills` stack: retain `mql5-production-engineering`, `token-saver-orchestrator`, explicitly invoked `planner`, and the installed `semantic-audit` skill when it remains relevant; remove only entries that are actually unavailable.
- **Dependencies**: Tasks 5.1-5.2 establish final architecture.
- **Acceptance criteria**:
  - `AGENTS.md` include order and safety rules match actual source.
  - `AGENTS.md` states no custom MQL5 tests/harnesses/CI and no compile in intermediate implementation sprints; one final real compile sprint is the default for substantial multi-sprint MQL5 plans unless a human explicitly changes policy.
  - `AGENTS.md` still requires static logic review every sprint and human Strategy Tester validation at final integration.
  - Active plan links point to this plan until final archive.
- **Validation**:
  - `rg -n 'license|entitlement|Protection_Risk|Session_Asia|Max_Spread|schema v7|multi-leg|partial TP' AGENTS.md README.md docs/architecture docs/plans/README.md`
  - `rg -n 'mql5-production-engineering|token-saver-orchestrator|planner|semantic-audit|final.*compile|MQL5.*CI|Broker_Session|schema v8' AGENTS.md README.md docs/architecture docs/plans/README.md`
- **Rollback**: Revert Sprint 5.

### Task 5.4: Update Workflows, Environment, Addons, And Product Copy

- **Location**: `docs/workflows/extremum-engine-statistics-flow.md`, `docs/workflows/deterministic-signal-ml-inference-flows.md`, `docs/environment/mt5-agentic-workflows.md`, `docs/addons/`, `docs/product_copy/en/`, `docs/product_copy/es/`.
- **Description**: Update commands and artifact lists to schema v8, document EXNESS/FIXED time semantics and human test dates, preserve ML boundaries, delete the session-time-filter addon pages and index entries, and rewrite base product copy around market-data collection and broker execution rather than license/protection controls.
- **Dependencies**: Task 5.3.
- **Acceptance criteria**:
  - Active operator commands use `--schema-version 8` and `schema_v8_extremum_engine_xgb`.
  - Session addon documentation is deleted, not deprecated.
  - Product copy does not promise removed controls.
  - Archived documents remain unchanged.
- **Validation**:
  - `rg -n 'schema v7|--schema-version 7|schema_v7_|addon_session_time_filter|Session_Asia|EA_License_Key|Protection_Risk|Max_Spread|Partial_TP' README.md AGENTS.md docs -g '!docs/plans/market-data-broker-executor-simplification-plan.md' -g '!docs/plans/archive/**' -g '!docs/research/archive/**'`
  - `git diff --check`
- **Rollback**: Revert Sprint 5.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] Active include/reference and documentation sweeps pass.
- [ ] Before/after source count demonstrates net deletion and is recorded compactly.
- [ ] No MetaEditor compile or syntax check was run.
- [ ] Exactly one Sprint 5 commit is created with the proposed sprint message.
- [ ] The Sprint 5 commit hash is recorded as the rollback point.
- [ ] Sprint 6 has not started before this gate completes.

## Sprint 6: Final Compile, Strategy Tester Acceptance, And Closeout

**Goal**: Validate the entire refoundation once, repair any integration defects within this sprint, obtain human Strategy Tester evidence, and archive the completed plan.
**Dependencies**: Sprint 5 gate and human access to MetaEditor/Strategy Tester.
**Tracked scope**: Integration fixes if needed, compact validation evidence, plan/archive indexes, and final documentation corrections only.
**Commit**: `chore: validate market data broker executor refoundation`
**Demo/Validation**:

- One final real MetaEditor compilation gate reports `0 errors, 0 warnings` and regenerates `.ex5`.
- Existing Python schema v8 checks pass.
- Human US30 summer/winter and broker-safety scenarios pass with compact evidence.
- The completed plan is archived and no active plan remains.

**Rollback point**: Sprint 5 commit before final integration fixes/evidence. If Strategy Tester reveals unsafe execution behavior, stop, leave Sprint 6 uncommitted, and fix within Sprint 6 before rerunning the final gates.

### Task 6.1: Run Final Static And Python Integration Checks

- **Location**: whole active repository, excluding immutable archives.
- **Description**: Run final removed-identifier, include, input, schema, secret/reference, formatting, and Python checks. Do not create a new harness to automate MQL5 behavior.
- **Dependencies**: Sprint 5.
- **Acceptance criteria**:
  - Final input surface is exact.
  - Active source/docs have no removed feature residue or old schema support.
  - Existing Python tests and fixture validation pass.
  - Git diff is whitespace-clean.
- **Validation**:
  - `rg -n 'EA_License_Key|LICENSE_SHARED_|Protection_Risk_|Session_Asia|Session_London|Session_NewYork|Max_Spread|Strategy_Direction_Mode|Signal_Concurrency_Mode|Lot_Multiplier|Signal_Lot_Strategy|TP_Percent|Partial_TP|Daily_Signal_Limit|schema_v[4-7]|schema v7' HFT_Grid_AI.mq5 services tools/deterministic_signal_ml AGENTS.md README.md docs -g '!docs/plans/market-data-broker-executor-simplification-plan.md' -g '!docs/plans/archive/**' -g '!docs/research/archive/**'`
  - `.venv/bin/python -m compileall tools/deterministic_signal_ml`
  - `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
  - `git diff --check`
- **Rollback**: Fix failures within Sprint 6 or revert uncommitted Sprint 6 work; do not bypass checks.

### Task 6.2: Run The Only MetaEditor Compile Sprint

- **Location**: `HFT_Grid_AI.mq5`, `tools/mt5/compile_mt5.py`, `logs/compile/agentic-build.log` (ignored artifact).
- **Description**: Run the preferred portable/headless real compile after all implementation and static checks. Do not run `/s` as acceptance. If the compile fails, make only integration corrections within Sprint 6 and rerun the real compile until the final result is clean.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - Final MetaEditor log reports `0 errors, 0 warnings`.
  - `.ex5` timestamp changes and generated binary remains ignored.
  - Evidence records command, log path, final status, binary timestamp/size, and only selected failure lines if corrections were needed.
- **Validation**:

  ```bash
  python3 tools/mt5/compile_mt5.py \
    --wine \
    --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" \
    --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" \
    --log "logs/compile/agentic-build.log" \
    --mode compile
  ```

- **Rollback**: Revert only uncommitted Sprint 6 corrections if they worsen the build; Sprint 5 is the last committed rollback point.

### Task 6.3: Run Human Strategy Tester And Chart Acceptance

- **Location**: MT5 Strategy Tester, Common Files schema v8 run folders, compact operator evidence.
- **Description**: Use identical tester configuration where comparisons matter and perform the following human checks. Do not add an automated MQL5 test EA/script.
- **Dependencies**: Task 6.2.
- **Acceptance criteria**:
  - One PEAK and one BOTTOM create the correct derived direction without direction inputs.
  - A deeper same-type extremum creates a revision and distinct attempt without duplicate emission from an unchanged source.
  - Multiple distinct attempts can coexist.
  - `FIXED_TIME_SESSIONS` exports broker time equal to analysis time.
  - Exness US30 summer data keeps `13:30 -> 13:30`; winter data records `14:30 broker -> 13:30 analysis` with `-60` offset.
  - Winter normalization does not let the EA trade at analysis `13:30` before the real broker opens at broker `14:30`.
  - High spread is captured but is not blocked solely by a removed threshold.
  - Closed market, incompatible trade mode, invalid stops/freeze, invalid/below-min volume, insufficient margin, or rejected `OrderCheck` creates a blocked execution-check fact and no broker order.
  - A hedging account can send one ticket per accepted attempt; a netting/exchange account continues collecting checks but never sends and records the unsupported-margin-mode reason.
  - One admissible attempt creates one broker position with internal magic, broker-side SL, fixed 1R TP, and ticket-first reconciliation.
  - Broker close creates one broker-confirmed outcome; simulated results remain separate.
  - SHADOW does not alter trading; FILTER is unavailable live and may only deny in tester after broker eligibility; pattern playback remains tester-scoped.
  - Open final cycle/attempt is censored cleanly and run summary reports `OK` only for natural completion.
- **Validation**:
  - Compact file names/sizes/row counts for one naturally completed schema v8 run.
  - Run `build_dataset.py --validate-only` on the real run, then build and compact DuckDB readback.
  - Human chart/ticket review for entry, SL, TP, position ticket, and close.
- **Rollback**: If any safety or data-lineage check fails, do not commit Sprint 6; correct and repeat the affected final checks.

### Task 6.4: Record Closeout And Archive The Plan

- **Location**: this plan, `docs/plans/README.md`, new `docs/plans/archive/market-data-broker-executor-simplification-2026-07-28/README.md`, archived copy of this plan, and active documentation links.
- **Description**: Record compact compile/Python/tester evidence, residual risks, final source reduction counts, and the Sprint 1-6 commit hashes. Mark the plan completed, move it into the dated archive folder, and set active planning status to none.
- **Dependencies**: Tasks 6.1-6.3 all pass.
- **Acceptance criteria**:
  - Evidence does not paste full logs, TSVs, Parquet, model JSON, or query debug files.
  - Archive README identifies schema v8, final commit, compile status, tester dates/symbol, and known residual risks.
  - `docs/plans/README.md` reports no active plan.
  - Working tree is clean after the one Sprint 6 commit.
- **Validation**:
  - `git status --short`
  - `git log --oneline -8`
  - `find docs/plans -maxdepth 2 -type f -printf '%p\n' | sort`
- **Rollback**: Revert Sprint 6 to restore the active plan and pre-closeout documentation; external schema v8 run artifacts remain preserved.

### Sprint 6 Gate

- [ ] All Sprint 6 tasks complete.
- [ ] Final static and existing Python checks pass.
- [ ] Final real MetaEditor compile passes with `0 errors, 0 warnings` and regenerated `.ex5` evidence.
- [ ] Human Strategy Tester and chart acceptance passes.
- [ ] Residual risks and deployment restrictions are recorded.
- [ ] Exactly one Sprint 6 commit is created with the proposed sprint message.
- [ ] The Sprint 6 commit hash is recorded as the final rollback point.
- [ ] The plan is archived only after every final gate passes.

## Testing Strategy

- **MQL5 unit/harness testing**: None. Do not create custom test EAs, scripts, include-based unit tests, Strategy Tester harnesses, or CI workflows.
- **Per-sprint MQL5 validation**: Sprints 1-5 use static call tracing, exact identifier searches, input/header/row contract review, truth tables, `git diff --check`, and compact source metrics. They do not invoke MetaEditor syntax or compile modes.
- **Final MQL5 integration**: Sprint 6 runs the only MetaEditor compile phase and requires a real compile with `0 errors, 0 warnings`; `/s` is not acceptance evidence.
- **Python contracts**: Update and run the existing three unittest modules and replacement compact fixture. Do not add a test module or dependency.
- **Data integration**: Validate a naturally completed real schema v8 run, build typed Parquet, and compare compact row counts and genealogy.
- **End-to-end/manual**: Human Strategy Tester verifies extremum/revision behavior, actual broker-session blocking, volume/margin/stops/freeze/OrderCheck failures, one-position send/reconciliation/close, and raw versus analysis timestamps.
- **Security/privacy**: Verify license/network/secrets code is absent, public research rows omit account identity and internal magic, and ML remains local-file-only.
- **Performance**: Compare export disabled versus schema v8 export enabled with logs disabled over the same 1-3 market days; record elapsed time, run bytes, attempt/check counts, and bounded-buffer behavior.
- **Accessibility**: Not applicable after removal of the interactive status UI. Retained chart lines must remain optional and cannot control execution.
- **Migration/compatibility**: Validate clean rejection of old schema/model IDs. Do not migrate or relabel artifacts.
- **Operational**: Verify no old-magic live positions exist before any future deployment, document the one-instance-per-account/symbol restriction, and verify the hedging-only execution requirement.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Removing license-derived magic orphans old positions | New EA cannot reconcile historical positions | Hard flat-position prerequisite; stable new internal magic; no live migration | Human confirms no old-version position before rollout |
| Stable symbol-derived magic collides with a second same-symbol instance | Two instances may claim the same positions | Document one instance per account/symbol; future instance ID requires a separate plan | Runtime docs and ticket/symbol/magic trace |
| Netting/exchange account merges or reverses attempt positions | Ticket-first per-attempt ownership becomes ambiguous and can alter an unrelated position | Keep collection enabled but fail all sends closed unless `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` is present | Margin-mode broker-check row and no-send tester/operator evidence |
| Protection/spread/session removal increases trading frequency/risk | More attempts reach broker checks | Preserve actual market/trade-mode, stops/freeze, volume, margin, OrderCheck, SL/TP, and reconciliation; demo/tester only in this plan | Tester attempt/check/send counts and blocked reasons |
| Analysis time accidentally controls execution | Orders could run before real broker open | Keep raw time in scheduler and market-session checks; normalization only inside export/ML/audit helpers | Winter US30 test shows no pre-open send |
| DST rule differs by instrument | Misaligned research timestamps | Implement official US rule plus documented UK exception prefixes; record mode/offset per row | Summer/winter fixture and real row review |
| Holiday or maintenance changes are mistaken for DST | Fabricated or shifted availability | Never synthesize bars/sessions; retain raw broker facts and market gaps | Broker/analysis pair and actual session-open field |
| Single-position rewrite corrupts broker ownership | Duplicate sends or wrong close/profit | Explicit state, source dedupe, pre-send gate, ticket-first reconciliation, broker-confirmed outcomes | One attempt/one ticket and close evidence |
| Percentage lot rounds above risk | Loss exceeds configured percentage | Normalize down; fail if broker minimum exceeds budget | Below-min and step truth-table/blocked reason |
| Broker-side SL/TP rejected after price movement | Unprotected or failed order | Recompute current entry/geometry immediately pre-send and require OrderCheck; never send without accepted SL/TP | Pre-send row plus send retcode |
| Schema v8 time pairs diverge | Research chronology or durations are wrong | Validate `analysis = broker + offset`; durations use broker time; features use analysis time | Python validator rejection and real-run audit |
| Old schema/model compatibility remains hidden | Context remains large and artifacts may mix | Delete active v4-v7 branches; exact v8 identity; historical revision message | Static schema search and fail-closed fixture |
| Aggressive deletion removes an indicator dependency | Initialization or signals fail | Prove reference/loader use before deletion; keep active custom indicator sources | Include/loader audit and final compile/tester |
| No intermediate compile delays compiler feedback | Integration errors accumulate to Sprint 6 | Keep sprints atomic, use exact static gates and one owner; reserve Sprint 6 for integration repairs | Final compile gate remains blocked until clean |

## Rollback Plan

- Use non-destructive `git revert <sprint-commit>` in reverse sprint order. Never use `git reset --hard` or broad checkout commands.
- **Sprint 6 rollback**: Revert closeout/integration corrections and restore the active plan. Keep external v8 artifacts for diagnosis.
- **Sprint 5 rollback**: Restore deleted dead source/frontend/docs. Runtime remains schema v8 from Sprint 4 and must not be presented with restored old documentation.
- **Sprint 4 rollback**: Restore v7 Python tooling. It cannot consume v8 runs; use the Sprint 4 code revision for v8 artifacts.
- **Sprint 3 rollback**: Restore pre-v8 MQL telemetry. Preserve v8 run folders separately and never relabel them.
- **Sprint 2 rollback**: Restore multi-leg execution on the simplified Sprint 1 shell for diagnosis only. Do not live-deploy this mixed architecture.
- **Sprint 1 rollback**: Restore license/account/protection/session behavior and license-derived magic. Ensure no positions opened under the new internal magic remain before running the old version.
- No database migration exists. Run/dataset/model directories are immutable by schema/run ID and can coexist.
- If any future live rollout must be rolled back while a new-magic position is open, keep the new executor attached until the position is broker-confirmed closed; do not switch binaries mid-position.

## Execution Order

1. Read planner execution-state instructions and initialize active-plan state.
2. Implement Sprint 1 only, run static gates, create exactly one Sprint 1 commit, and record its rollback hash.
3. Repeat the same gate for Sprints 2-5 without running MetaEditor syntax or compile commands.
4. Start Sprint 6 only after Sprint 5 is committed and all intermediate static/Python evidence is recorded.
5. Run final static/Python checks, the real MetaEditor compile, and human Strategy Tester acceptance in Sprint 6.
6. Create exactly one Sprint 6 commit and archive the plan only after every final check passes.
7. If a sprint fails, fix within that sprint. If product or safety direction changes, update this plan before continuing.

## Completion Checklist

- [ ] Final public input surface contains only the six groups and eleven fields listed in Scope.
- [ ] `EXTREMUM_V1` remains always-on M1 with structurally derived directions and no configurable concurrency gate.
- [ ] License, entitlement, network results, user session filters, protection, spread threshold, daily limits, lot sequence, multiplier, variable TP, partial TP, and multi-leg code are deleted.
- [ ] Stable internal magic, one-instance restriction, symbol scope, and ticket-first reconciliation are documented and verified.
- [ ] Hedging-only broker execution is enforced; non-hedging accounts remain collection-only and fail sends closed.
- [ ] Every attempt has observation broker checks; every send has pre-send and send-result checks.
- [ ] One accepted attempt can create at most one broker position with broker-side SL and fixed 1R TP.
- [ ] Fixed and account-balance-percentage lot modes fail closed at broker constraints.
- [ ] Schema v8 stores raw broker and normalized analysis time with auditable offset.
- [ ] Exness US30 summer/winter normalization is verified without changing actual execution time.
- [ ] Current Python/ML/audit tooling supports schema v8 only; historical artifacts remain immutable.
- [ ] No new MQL5 test/harness/CI or test module was added.
- [ ] Sprints 1-5 ran no MetaEditor command.
- [ ] Sprint 6 real compile passes with `0 errors, 0 warnings` and regenerated `.ex5`.
- [ ] Human Strategy Tester acceptance and compact schema v8 validation pass.
- [ ] Active docs and skill-stack guidance match the implemented project.
- [ ] Net MQL5 source/file reduction is recorded.
- [ ] Every sprint has exactly one sprint-specific commit and recorded rollback point.
- [ ] Final plan/evidence is archived and the working tree is clean.
