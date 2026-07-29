# Plan: Pivot Fractal Engine And Schema V9

**Generated**: 2026-07-29
**Status**: Implementation in progress; final validation and closeout remain
**Planning Review**: Complete; no blocking clarification remains
**Estimated Complexity**: High
**Risk Class**: Critical - this changes signal generation, broker entry geometry, position protection, trailing, active persistence, and the research schema
**Execution Baseline**: Branch `bot/pivot_points_fractal`, commit `9e317849322a5a74e029860300f185706042f531`, 41 tracked MQL5 files and 13,559 tracked MQL5 lines

## Overview

Replace the fixed M1 `EXTREMUM_V1` cycle/revision/breakout engine with a fixed, expandable `PIVOT_FRACTAL_V1` engine. The new source calculates classic `PP`, `S1..S3`, and `R1..R3` from the immediately previous completed broker candle for `M15`, `M30`, `H1`, `H4`, and `D1`. Each set is active only during that timeframe's current broker-native bar. `M1` supplies trigger context and research features but never creates pivot levels.

The strategy uses the previous completed M1 Bid close to establish which side of a level price came from, then uses live Bid to detect the first touch or cross. A prior M1 close above a level plus a downward Bid touch creates a buy; a prior M1 close below a level plus an upward Bid touch creates a sell. Buy orders execute at current Ask and sell orders at current Bid. This keeps candle context and touch detection on the same Bid-based price series while preserving broker-authoritative execution prices and spread telemetry.

Each `(symbol, pivot timeframe, active bar open, level)` is one immutable first-touch identity. It may produce at most one signal attempt and one broker send attempt, whichever direction touches first. Identities are independent across timeframes, including when several pivot levels resolve to the same price. Filled positions retain their captured pivot ladder after the source window expires and trail only by their own broker position ticket.

The engine is a stronger fit for the stated research goal than the current extremum engine because it creates explicit, repeatable, timeframe-owned hypotheses that can be joined across confluence windows. The principal tradeoffs are higher possible concurrent exposure, spread/slippage between a Bid trigger and Ask buy fill, and structural trailing levels that are not guaranteed monetary break-even or fixed 1R. Those facts must remain observable rather than being hidden by adjusted prices or synthetic labels.

Target runtime flow:

```text
broker-native M1 bar transition
-> refresh previous M1 Bid close
-> refresh only pivot timeframes whose active broker bar changed
-> cache previous completed candle and classic pivot ladder
-> every tick: discover unconsumed Bid touch identities
-> capture one six-timeframe context snapshot per first touch
-> build the immutable level route and observation broker facts
-> reject unsupported route or failed broker eligibility
-> refresh broker checks and OrderCheck immediately before send
-> one market order with broker-side structural SL and terminal pivot TP
-> ticket-first broker reconciliation
-> monotonic pivot-level SL progression
-> broker-confirmed outcome and schema V9 persistence
```

## Scope

- **In scope**:
  - Replace `EXTREMUM_V1` with fixed `PIVOT_FRACTAL_V1` source behavior.
  - Calculate classic pivots from the immediately previous completed `M15`, `M30`, `H1`, `H4`, and `D1` broker candle.
  - Keep `M1` as trigger and feature context only.
  - Cache pivot windows and refresh only at broker bar changes or controlled data-read retries.
  - Use the previous completed M1 Bid close for side context and live Bid for both touch directions.
  - Support one first-touch attempt and one send attempt per exact pivot identity.
  - Permit independent positions across levels and timeframes only under the existing hedging-account requirement.
  - Implement the approved symmetric entry, stop, terminal target, and trailing matrix.
  - Preserve fresh broker session, permission, tick, geometry, stops/freeze, volume, margin, `OrderCheck`, retcode, stable magic, comment, ticket, and reconciliation checks.
  - Preserve only the requested research context for `M1`, `M15`, `M30`, `H1`, `H4`, and `D1`: Stoch Structure classifications for slots `0..2` and raw Bollinger `%B` shifts `0..5`.
  - Replace the active schema V8 runtime/export/research contract with strict `schema_v9_pivot_fractal` files, validation, fixtures, DuckDB ingestion, audits, and XGBoost-ready training data.
  - Delete active tracked V8 exporter code, runtime ML/pattern code, V8-only adapters, V8 fixtures, and obsolete extremum/Fibonacci logic.
  - Update active architecture, workflow, environment, README, agent guidance, inputs, include topology, and bounded visual inspection.
- **Out of scope**:
  - Configurable pivot timeframes or formulas in this version. Expansion must occur through one internal ordered timeframe definition until a later plan authorizes public inputs.
  - `M1` pivot calculations, `R4/S4`, Camarilla, Woodie, Fibonacci pivots, central pivot ranges, or synthetic/incomplete candles.
  - Pending limit orders. Entries are market orders submitted after a live touch.
  - Retrying a denied or failed entry for the same identity.
  - Direction, concurrency, spread-threshold, session-hours, drawdown, daily-limit, partial-close, multi-leg, or virtual-protection inputs.
  - Simulated attempt outcomes, fixed 1R labels, cycle/revision genealogy, Fibonacci proximity, runtime ML scoring/filtering, or pattern-audit playback.
  - Runtime model approval, online learning, or live XGBoost inference.
  - Migrating, relabeling, or adapting schema V8 rows or models into V9.
  - Deleting archived plans/research or external/generated historical datasets. Active tracked V8 implementation/tooling/fixtures are removed; archives and generated evidence remain preserved under repository policy.
  - Adding MQL5 test harnesses, custom test modules, test EAs/scripts, agentic MQL5 CI, or new MQL5 test infrastructure.
  - Live rollout. Completion authorizes further human evaluation only.
- **Fixed decisions**:
  - `PIVOT_FRACTAL_V1` owns exactly `M15`, `M30`, `H1`, `H4`, and `D1`; `M1` is context-only.
  - Broker time owns bars, active-window identity, trigger order, order timing, trailing, and reconciliation. Existing analysis-time normalization remains export-only.
  - The previous candle is obtained by broker series shift `1`; no wall-clock aggregation or synthetic range is permitted.
  - A pivot window becomes valid only after all source H/L/C values and the ordered normalized level ladder are valid.
  - The exact identity is `(symbol, timeframe, active_bar_open, level)`. Direction is an outcome of the first touch and is not part of identity.
  - Previous M1 close and live touch both use Bid. Buy execution and fill use Ask; sell execution and fill use Bid. Both sides of the tick are captured.
  - Equality of the previous M1 close to a level is neutral. That M1 bar cannot establish direction for the level.
  - A gap through a level counts as its first touch. All newly crossed identities are recorded, then broker sends are attempted in deterministic nearest-crossed-price order with stable timeframe and level tie breakers.
  - A first touch consumes the identity even when it is denied, fails broker checks, fails `OrderCheck`, or fails `OrderSend`.
  - Untriggered identities expire when `iTime(symbol, timeframe, 0)` changes. Filled positions do not expire with the window.
  - No route modifies pivot prices to make broker geometry pass. Invalid geometry blocks the order and is exported.
  - Account-balance-percent lot sizing uses the actual planned entry-side price and captured structural initial SL distance. Final target distance is not assumed to equal risk.
  - Broker-side initial SL and terminal TP are mandatory. Local state never removes protection or substitutes a virtual-only terminal target.
  - Trailing is monotonic and ticket-owned. It can tighten only to the strongest reached captured level and can never widen or remove broker protection.
  - Existing stable magic remains internal and nonzero but changes to a new `PIVOT_FRACTAL_V1` namespace so old-engine positions cannot be mistaken for new positions.
  - Feature collection and file persistence never authorize or deny execution. Missing feature data marks the V9 run incomplete/invalid but does not alter an otherwise valid broker decision.
  - No schema V8 compatibility branch, model adapter, or dual writer remains active after cutover.
- **Assumptions**:
  - The current broker symbols use Bid-based chart candles for the strategy context. Supporting exchange/Last-price trigger semantics would require a separate explicit price-policy change.
  - The approved identity intentionally allows only the first direction seen at one level/window; a later opposite-side retest cannot create a second attempt until the next pivot window.
  - "Destroy V8 files" means deleting active tracked V8 implementation, compatibility tooling, tests, and fixtures. Repository archives and external/generated datasets remain protected by the project preservation policy.
  - V9 export is enabled when research rows are required. Trading remains operational with export disabled, and runtime ML/pattern decisions are removed rather than replaced.
  - The existing lot modes, broker-safety kernel, time normalization helper, and bounded frontend can be adapted without introducing a new dependency or MQL5 test harness.

## Engine Contract

### Pivot Window Semantics

For each configured timeframe, the active bar is the lifecycle and identity window; shift `1` is the completed source candle.

| Observation time | Pivot timeframe | Completed source candle | Active pivot window | Refresh behavior |
| --- | --- | --- | --- | --- |
| `09:30` | `M15` | `09:15` through the exclusive `09:30` boundary | `09:30` until the next M15 broker bar | Recalculate |
| `09:30` | `M30` | `09:00` through the exclusive `09:30` boundary | `09:30` until the next M30 broker bar | Recalculate |
| `09:30` | `H1` | Previous completed H1 candle ending at the `09:00` bar transition | Existing `09:00` H1 bar | Keep cached set |
| `09:30` | `H4` | Previous completed H4 candle | Existing H4 broker bar | Keep cached set |
| `09:30` | `D1` | Previous completed D1 candle | Existing D1 broker bar | Keep cached set |

Actual broker bar transitions, not assumed wall-clock duration, expire windows. Weekend gaps and broker calendar gaps therefore do not create missing synthetic candles.

### Classic Pivot Formula

For source high `H`, low `L`, close `C`, and range `D = H - L`:

```text
PP = (H + L + C) / 3
R1 = 2 * PP - L
S1 = 2 * PP - H
R2 = PP + D
S2 = PP - D
R3 = H + 2 * (PP - L)
S3 = L - 2 * (H - PP)
```

The calculator retains raw formula values and produces one symbol-tick-normalized trade value for trigger and broker geometry. It must reject zero/invalid range, invalid numbers, unavailable source data, or a normalized ladder that is not strictly ordered `S3 < S2 < S1 < PP < R1 < R2 < R3`.

### Trigger Semantics

For each active, unconsumed level:

```text
previous completed M1 Bid close > level AND live Bid <= level -> BUY touch
previous completed M1 Bid close < level AND live Bid >= level -> SELL touch
previous completed M1 Bid close == level                         -> no side
```

The condition is inclusive at the live boundary so exact touches and gaps through are captured. The trigger records previous M1 bar open/close time, previous close, live Bid, live Ask, spread, intended pivot price, broker time, analysis time, and offset. The order remains a market deal; the intended pivot level and broker-authoritative request/fill prices stay separate.

### Entry And Trailing Matrix

`BE` below means the captured logical entry level, not guaranteed monetary break-even after spread, slippage, commission, or swap.

| Direction | Entry level | Initial broker SL | Milestone progression | Terminal broker TP | Admission |
| --- | --- | --- | --- | --- | --- |
| Buy | `PP` | `S1` | `R1 -> PP (structural BE)`, `R2 -> R1` | `R3` | Allowed |
| Sell | `PP` | `R1` | `S1 -> PP (structural BE)`, `S2 -> S1` | `S3` | Allowed |
| Buy | `S1` | `S2` | `PP -> no change`, `R1 -> PP`, `R2 -> R1` | `R3` | Allowed |
| Sell | `R1` | `R2` | `PP -> no change`, `S1 -> PP`, `S2 -> S1` | `S3` | Allowed |
| Buy | `S2` | `S3` | `S1 -> S2 (structural BE)`, `PP -> S1` | `R1` | Allowed |
| Sell | `R2` | `R3` | `R1 -> R2 (structural BE)`, `PP -> R1` | `S1` | Allowed |
| Buy | `S3` | `S3 - (S2 - S3)` | `S2 -> S3 (structural BE)`, `S1 -> S2` | `PP` | Allowed |
| Sell | `R3` | `R3 + (R3 - R2)` | `R2 -> R3 (structural BE)`, `R1 -> R2` | `PP` | Allowed |
| Buy | `R1` | `PP` | `R2 -> R1 (structural BE)` | `R3` | Allowed reversal |
| Sell | `S1` | `PP` | `S2 -> S1 (structural BE)` | `S3` | Allowed reversal |
| Buy | `R2` | `R1` | No intermediate SL change | `R3` | Allowed reversal |
| Sell | `S2` | `S1` | No intermediate SL change | `S3` | Allowed reversal |
| Buy | `R3` | None | None | None | Deny as `NO_FORWARD_LEVEL` |
| Sell | `S3` | None | None | None | Deny as `NO_FORWARD_LEVEL` |

Buy milestone reach uses live Bid because Bid is the executable close side of a buy. Sell milestone reach uses live Ask. When one tick crosses multiple milestones, the engine selects the strongest eligible new SL and submits at most one modification for that desired state. The initial terminal TP remains on the broker position; broker reconciliation, not a locally manufactured close, owns terminal completion.

### Feature Snapshot Contract

At each first trigger, capture exactly one row for each context timeframe `M1`, `M15`, `M30`, `H1`, `H4`, and `D1`:

- Stoch Structure classifications for source slots `0`, `1`, and `2`, stored as `HH`, `HL`, `LH`, `LL`, `EQ`, or an explicit unavailable token.
- Raw Bollinger `%B` shifts `0..5`, using period `21`, deviation `2.0`, `MODE_SMA`, and `PRICE_CLOSE`.
- Shift `0` uses trigger Bid against the developing shift-0 upper/lower bands for that context timeframe.
- Shifts `1..5` use each matching completed candle close and the upper/lower bands at the same shift.
- `%B = (price - lower_band) / (upper_band - lower_band) * 100`; values are not clamped to `0..100`.
- The snapshot is captured before broker denial or send so denied and filled attempts share the same point-in-time feature semantics.
- Indicator handles are initialized once, checked with `BarsCalculated`/`CopyBuffer`, and released on deinitialization. They are not created per tick.
- Feature unavailability is exported and invalidates research completeness; it does not change signal or broker execution.

### Schema V9 Contract

New runs write under a distinct Common Files root such as:

```text
Common\Files\PivotFractalV9\runs\<run_id>\
```

Every event table retains schema/run identity, symbol, broker time, analysis time, applied offset, and a stable sequence where relevant. The strict V9 resources are:

| File | Grain and purpose |
| --- | --- |
| `run_manifest.tsv` | One run/config identity with schema, engine, timeframe order, formula, trigger-price policy, indicator parameters, lot policy, time policy, and research approval state. |
| `pivot_windows.tsv` | One broker-native active window per pivot timeframe with source bar identity/H/L/C, range, validity, active open, and final expiration/censor status. |
| `pivot_levels.tsv` | Seven immutable level definitions per valid window with raw and normalized prices. |
| `signal_attempts.tsv` | One immutable first-touch row per consumed identity, including direction, M1 side context, tick facts, route, intended entry/SL/TP, admission status, and terminal attempt reason. |
| `signal_features.tsv` | Six context rows per signal attempt containing structure slots `0..2`, `%B` shifts `0..5`, and completeness facts. |
| `execution_checks.tsv` | Observation, pre-send, send-result, and broker lifecycle facts without simulated outcomes. |
| `trailing_events.tsv` | Reached milestones, desired/previous/requested/confirmed SL, modification retcode/comment, retry state, and ticket identity. |
| `signal_outcomes.tsv` | Broker-confirmed fill and close facts, realized profit, final SL/TP, highest route milestone, terminal reason, and duration. |
| `run_summary.tsv` | Counts, referential-integrity checks, feature completeness, duplicate identity counts, export status, and natural/censored completion. |

`signal_attempts.tsv` is intentionally separate from `signal_features.tsv` and `execution_checks.tsv`; this prevents six context rows or repeated broker checks from becoming the accidental canonical signal table. There is no cycle, revision, simulation, fixed-1R, runtime-model, or pattern-playback table in V9.

## Named Resources

- **Project instructions**:
  - `AGENTS.md`
  - `/home/loldlm/.codex/skills/planner/SKILL.md`
  - `/home/loldlm/.codex/skills/planner/references/execution-state.md` at later implementation handoff only
  - `/home/loldlm/.codex/skills/mql5-production-engineering/SKILL.md`
  - `/home/loldlm/.codex/skills/token-saver-orchestrator/SKILL.md`
- **Entrypoint and aggregators**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_tools.mqh`
  - `services/trading_management.mqh`
  - `services/trading_signals.mqh`
  - `services/frontend.mqh`
- **MQL5 files to create or replace**:
  - `services/trading_management/pivot_fractal_engine_config.mqh`
  - `services/indicators/pivot_points_calculator.mqh`
  - `services/trading_signals/pivot_fractal_engine_state.mqh`
  - `services/trading_signals/pivot_context_features.mqh`
  - `services/trading_signals/pivot_signal_struct.mqh`
  - `services/trading_signals/pivot_signal_state.mqh`
  - `services/trading_signals/pivot_fractal_signal_detection.mqh`
  - `services/trading_signals/pivot_signal_lifecycle.mqh`
  - `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **MQL5 files to refactor and retain**:
  - `services/core/enums.mqh`
  - `services/core/base_structures.mqh`
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/trading_management/market_conditions_functions.mqh`
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lot_math.mqh`
  - `services/trading_signals/execution_logging.mqh`
  - `services/trading_signals/market_status_controller.mqh`
  - `services/indicators/extrema_detector.mqh`
  - `services/indicators/structure_classifier.mqh`
  - `services/indicators/stochastic_market_indicator.mqh`
  - `services/utils/market_data_time.mqh`
  - `services/utils/broker_constraints_helper.mqh`
  - `services/frontend/execution_visual_lines.mqh`
  - `services/frontend/execution_visual_utils.mqh`
  - `services/frontend/execution_visualization.mqh`
- **Active MQL5 files expected to be deleted after replacement**:
  - `services/trading_management/extremum_engine_config.mqh`
  - `services/trading_signals/extremum_engine_state.mqh`
  - `services/trading_signals/market_signal_detection.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
  - `services/trading_signals/market_signal_state.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `services/trading_signals/deterministic_signal_pattern_audit_playback.mqh`
  - `services/indicators/fibonacci_calculator.mqh`
  - `services/indicators/extremum_statistics_calculator.mqh`
- **Reference indicator, read-only**:
  - `/home/loldlm/Downloads/Pivot_Range_Channel_v1.40.mq5`
  - Reuse its completed-range cache principles and classic formulas conceptually; do not copy its chart-object, range-session, R4-S10, or indicator-buffer implementation into the EA.
- **Research tooling**:
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/feature_encoder.py`
  - `tools/deterministic_signal_ml/model_config.py`
  - `tools/deterministic_signal_ml/validation_splits.py`
  - `tools/deterministic_signal_ml/train_model.py`
  - Existing comparison, diagnostics, reporting, and robustness modules that remain meaningful for offline V9 research
  - Replace `tools/deterministic_signal_ml/extremum_engine_audit.py` with `tools/deterministic_signal_ml/pivot_fractal_audit.py`
  - Replace the three existing extremum test modules with three renamed V9 pivot modules; do not increase the test-module count
  - Replace `tools/deterministic_signal_ml/tests/fixtures/schema_v8_extremum_engine/` with `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/`
- **V8-only Python resources expected to be deleted unless a file is proven generic and rewritten**:
  - `tools/deterministic_signal_ml/model_artifact_contract.py`
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
  - `tools/deterministic_signal_ml/export_model_artifact.py`
  - `tools/deterministic_signal_ml/deploy_model_export.py`
  - `tools/deterministic_signal_ml/compare_shadow_predictions.py`
  - `tools/deterministic_signal_ml/summarize_filter_run.py`
  - `tools/deterministic_signal_ml/pattern_audit.py`
  - `tools/deterministic_signal_ml/pattern_playback_compare.py`
  - `tools/deterministic_signal_ml/validate_phase1_run.py`
- **Active documentation to update**:
  - `AGENTS.md`
  - `README.md`
  - `docs/plans/README.md`
  - `docs/architecture/market-data-broker-executor.md`
  - `docs/workflows/extremum-engine-statistics-flow.md` renamed to `docs/workflows/pivot-fractal-statistics-flow.md`
  - `docs/workflows/deterministic-signal-ml-inference-flows.md` removed or replaced by an offline-only V9 research boundary document
  - `docs/environment/mt5-agentic-workflows.md`
- **Validation resources**:
  - `tools/mt5/compile_mt5.py`
  - Existing `.venv` and `tools/deterministic_signal_ml/requirements.txt`
  - Real MetaEditor compile log at `logs/compile/agentic-build.log` (ignored evidence)
  - Human MetaTrader 5 Strategy Tester and visual/nonvisual chart inspection
- **Official MQL5 documentation reviewed for this plan**:
  - `CopyRates`: https://www.mql5.com/en/docs/series/copyrates
  - `iTime`: https://www.mql5.com/en/docs/series/itime
  - `PeriodSeconds`: https://www.mql5.com/en/docs/common/periodseconds
  - `SymbolInfoTick`: https://www.mql5.com/en/docs/marketinformation/symbolinfotick
  - `iBands`: https://www.mql5.com/en/docs/indicators/ibands
  - `iCustom`: https://www.mql5.com/en/docs/indicators/icustom
  - `CopyBuffer`: https://www.mql5.com/en/docs/series/copybuffer
  - `BarsCalculated`: https://www.mql5.com/en/docs/series/barscalculated
  - `OrderSend`: https://www.mql5.com/en/docs/trading/ordersend
  - `MqlTradeRequest`: https://www.mql5.com/en/docs/constants/structures/mqltraderequest
  - Ticket-based `PositionModify`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify
  - Ticket-based `PositionClose`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclose

## Prerequisites

- Start implementation from a clean worktree at or intentionally rebased from baseline `9e31784`; record any changed baseline before Sprint 1.
- Read the planner execution-state instructions and initialize active-plan state before modifying Sprint 1 files.
- Confirm the runtime `Examples\Stochastic_Structure.ex5` exists and corresponds to tracked source `indicators/Stochastic_Structure.mq5`.
- Confirm the account used for order lifecycle acceptance is `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` and has no open old-engine position for the test symbol.
- Use a unique V9 run ID and the new V9 Common Files root. Never point V9 tooling at a V8 folder with overwrite enabled.
- Preserve external/generated V8 data and archived repository plans/research. Destructive cleanup targets only active tracked V8 implementation, adapters, tests, and fixtures.
- Do not run MetaEditor syntax or compile checks in Sprints 1-7. The only compile occurs in Sprint 8.
- Treat every intermediate sprint commit as implementation evidence, not live-deployment authorization.

## Dependencies And Parallel Work

- Sprint order is strict because engine identity, frozen V9 headers, broker lifecycle, Python ingestion, and final documentation depend on the preceding contracts.
- Within a sprint, read-only audits and documentation drafting may run in parallel with implementation only when they do not touch the same files or freeze a contract prematurely.
- Sprint 2 handle hydration and pure feature-row design may be developed in parallel after Task 2.1 fixes M1 side semantics, then reconciled before the single sprint commit.
- Sprint 6 generic reporting review and fixture construction may proceed in parallel after Task 6.1 freezes V9 keys/headers; schema, dataset, and leakage rules remain single-owner dependencies.
- No parallel worker may create a separate commit. All work for one sprint is integrated, validated, and committed exactly once at its gate.

## Sprint 1: Add The Cached Pivot Window Foundation

**Goal**: Introduce an inactive, independently inspectable pivot domain, calculator, and five-timeframe cache without changing the current runtime source yet.
**Dependencies**: Prerequisites complete; active-plan execution state initialized.
**Tracked scope**: `services/core/enums.mqh`, `services/trading_management/pivot_fractal_engine_config.mqh`, `services/indicators/pivot_points_calculator.mqh`, `services/trading_signals/pivot_fractal_engine_state.mqh`, and aggregator include preparation only.
**Commit**: `feat: add cached pivot fractal window foundation`
**Demo/Validation**:

- Static formula comparison against `/home/loldlm/Downloads/Pivot_Range_Channel_v1.40.mq5` for `PP/S1..S3/R1..R3`.
- Identifier and include sweep confirms the new modules are layered and do not create sibling re-includes or cycles.
- `git diff --check`
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Baseline `9e31784` or the recorded rebased baseline. Revert the single Sprint 1 commit to remove the dormant pivot foundation.

### Task 1.1: Define Fixed Pivot Domain Types

- **Location**: `services/core/enums.mqh`, `services/trading_management/pivot_fractal_engine_config.mqh`
- **Description**: Define `PIVOT_FRACTAL_V1`, the ordered five-timeframe array, seven level identifiers, direction/trigger status tokens, window state, route status, and helper labels in one ownership boundary. Do not expose timeframe or formula inputs.
- **Dependencies**: None.
- **Acceptance criteria**:
  - One ordered definition owns `M15`, `M30`, `H1`, `H4`, `D1` and supports a future internal extension without duplicating switch lists.
  - `M1` is absent from the pivot source array and explicitly present in the feature-context array.
  - Old `EXTREMUM_V1` remains untouched until the atomic runtime cutover.
- **Validation**:
  - `rg -n "PIVOT_FRACTAL|PERIOD_M15|PERIOD_M30|PERIOD_H1|PERIOD_H4|PERIOD_D1" services/core services/trading_management`
- **Rollback**: Remove the new enum/config additions through the Sprint 1 revert.

### Task 1.2: Implement Pure Classic Pivot Calculation

- **Location**: `services/indicators/pivot_points_calculator.mqh`
- **Description**: Calculate raw classic values from one valid completed `MqlRates`, normalize trade levels through existing symbol price helpers/tick size, validate strict ordering, and return an explicit error reason without chart objects or indicator buffers.
- **Dependencies**: Task 1.1 and existing broker/price helpers.
- **Acceptance criteria**:
  - Formulas exactly match the Engine Contract.
  - Invalid H/L/C, nonpositive range, nonfinite values, or collapsed normalized levels fail closed.
  - Both raw and normalized values remain available for export and broker geometry.
- **Validation**:
  - Manual numeric review with at least two source candles, including a fractional tick-size symbol case.
  - `rg -n "r4|s4|Camarilla|Woodie|Fibonacci" services/indicators/pivot_points_calculator.mqh` returns no strategy implementation.
- **Rollback**: Remove the calculator through the Sprint 1 revert.

### Task 1.3: Implement Broker-Bar Window Cache

- **Location**: `services/trading_signals/pivot_fractal_engine_state.mqh`
- **Description**: Store one state slot per configured timeframe. Initialize from `iTime(..., 0)` plus `CopyRates(..., 1, 1)`, refresh only when the actual active bar open changes, retain explicit pending/error state, and expire untriggered level flags on the next broker bar.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance criteria**:
  - No incomplete shift-0 candle contributes H/L/C.
  - Weekend/session gaps use the actual previous broker candle without synthetic continuity assumptions.
  - Failed history reads do not expose stale values under a new active-bar identity.
  - Controlled pending retries do not call `CopyRates` for all timeframes on every normal tick.
- **Validation**:
  - Static path review covers init, new M1 transition, changed timeframe, pending retry, invalid source, and deinit/reset.
  - `rg -n "CopyRates|iTime|PeriodSeconds" services/trading_signals/pivot_fractal_engine_state.mqh services/indicators/pivot_points_calculator.mqh`
- **Rollback**: Remove the cache through the Sprint 1 revert.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Static formula, cache, identifier, include, and whitespace checks pass and evidence is recorded.
- [ ] No runtime source, order behavior, V8 file, or public input changed.
- [ ] Residual risks are documented.
- [ ] Exactly one Sprint 1 commit is created with the proposed sprint message.
- [ ] The Sprint 1 commit hash is recorded as the rollback point.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Build M1 Trigger Context And Six-Timeframe Features

**Goal**: Add reusable, execution-neutral M1 side context and requested feature snapshots for `M1/M15/M30/H1/H4/D1` without creating per-tick indicator handles.
**Dependencies**: Sprint 1 gate complete.
**Tracked scope**: `services/trading_management/ea_inputs.mqh`, `services/trading_management/indicator_definitions_loader.mqh`, `services/indicators/extrema_detector.mqh`, `services/indicators/structure_classifier.mqh`, `services/indicators/stochastic_market_indicator.mqh`, `services/trading_signals/pivot_context_features.mqh`, and relevant shared structures.
**Commit**: `feat: capture multi timeframe pivot context features`
**Demo/Validation**:

- Static handle inventory proves one Stoch Structure handle and one `iBands` handle per context timeframe only when V9 export needs them.
- Snapshot review proves slot `0..2` and `%B 0..5` semantics, with shift 0 using trigger Bid.
- `git diff --check`
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Sprint 1 commit. Revert Sprint 2 to remove feature hydration while retaining the dormant pivot calculator/cache.

### Task 2.1: Cache Previous Completed M1 Bid Close

- **Location**: `services/trading_signals/pivot_context_features.mqh` or the owning pivot state module
- **Description**: On each actual M1 bar transition, load shift `1` once and retain its bar identity and close for touch-side decisions. Pause new touches when a fresh completed M1 close is unavailable rather than using stale context.
- **Dependencies**: Sprint 1 window scheduling.
- **Acceptance criteria**:
  - The side close is always from the immediately previous completed broker M1 candle.
  - Equality stays neutral and no Ask/Last value is substituted.
  - Trigger scanning can distinguish unavailable, above, below, and equal states.
- **Validation**:
  - Static transition review for normal bars, gap opens, missing history, and duplicate ticks.
- **Rollback**: Revert Sprint 2.

### Task 2.2: Hydrate Six Context Timeframes Once

- **Location**: `services/trading_management/indicator_definitions_loader.mqh`, `services/indicators/stochastic_market_indicator.mqh`
- **Description**: Replace the single-timeframe structure handle and partial bands set with ordered handles for `M1`, `M15`, `M30`, `H1`, `H4`, and `D1`. Keep the Stoch parameters `5,3,3`/`STO_CLOSECLOSE` and bands `21,2.0,MODE_SMA,PRICE_CLOSE` fixed.
- **Dependencies**: Task 2.1 and existing runtime indicator placement.
- **Acceptance criteria**:
  - Handles are created only during initialization/explicit reload and released once on deinit.
  - `BarsCalculated`, handle validity, and buffer reads are checked.
  - Export-disabled execution does not pay repeated feature-copy cost.
  - Indicator failure affects export completeness, not broker authorization.
- **Validation**:
  - `rg -n "iCustom|iBands|IndicatorRelease|BarsCalculated|CopyBuffer" services/trading_management/indicator_definitions_loader.mqh services/trading_signals/pivot_context_features.mqh`
- **Rollback**: Revert Sprint 2.

### Task 2.3: Build Immutable Trigger-Time Feature Snapshots

- **Location**: `services/trading_signals/pivot_context_features.mqh`, retained structure classifier modules
- **Description**: Read structure slots `0..2`, compute raw `%B` shifts `0..5`, attach completeness/error facts, and return a six-row snapshot owned by a signal attempt. Remove all dependence on cycle/revision/Fibonacci statistics from this feature path.
- **Dependencies**: Task 2.2.
- **Acceptance criteria**:
  - Shift 0 uses trigger Bid with shift-0 bands; shifts 1-5 use matching candle/band shifts.
  - Values outside `0..100` are retained.
  - No future candle or post-trigger update can mutate a captured snapshot.
  - The feature function has no order, lot, admission, or frontend side effect.
- **Validation**:
  - Exact shift/index review and reference sweep for clamping or future-shift mistakes.
  - `rg -n "MathMin|MathMax|clamp|Fibonacci|extremum_stats" services/trading_signals/pivot_context_features.mqh services/indicators/stochastic_market_indicator.mqh`
- **Rollback**: Revert Sprint 2.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] M1 side and six-timeframe feature semantics pass static review.
- [ ] Handle lifecycle and hot-path review pass.
- [ ] `git diff --check` passes.
- [ ] No MetaEditor syntax check or compile was run.
- [ ] Exactly one Sprint 2 commit is created and its hash recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Define The MQL5 Schema V9 Export Contract

**Goal**: Implement a strict, inactive-capable V9 writer and row contract that has no V8 compatibility or simulation genealogy.
**Dependencies**: Sprint 2 gate complete.
**Tracked scope**: `services/trading_signals/pivot_fractal_statistics_export.mqh`, common time/file helpers, V9 row structs, and aggregator preparation.
**Commit**: `feat: add pivot fractal schema v9 export contract`
**Demo/Validation**:

- Header/row field-count review for all nine V9 files.
- Referential-key review proves one canonical signal attempt and six feature rows.
- Export-disabled path remains a no-op for files but does not change runtime state or broker checks.
- `git diff --check`
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Sprint 2 commit. Revert Sprint 3 to remove the dormant V9 exporter without changing current V8 runtime behavior.

### Task 3.1: Define Strict V9 Identity And Headers

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **Description**: Define schema version `9`, engine label, feature set `schema_v9_pivot_fractal_xgb`, Common Files root, stable IDs, exact TSV headers, token format, and one manifest policy. Do not accept schema aliases or older headers.
- **Dependencies**: Pivot domain and feature structs.
- **Acceptance criteria**:
  - The nine Schema V9 Contract files have explicit headers and key relationships.
  - Signal identity is derived from symbol/timeframe/active open/level and cannot collide across timeframes.
  - Broker and analysis timestamps plus offset remain distinct.
  - No cycle, revision, simulation, 1R, ML runtime, or pattern field remains.
- **Validation**:
  - Header field-count and identifier sweep performed through small local inspection commands during implementation.
- **Rollback**: Revert Sprint 3.

### Task 3.2: Implement Append-Only Writers And Run Integrity

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh`, `services/utils/file_logger.mqh` only if a proven generic helper change is required
- **Description**: Open/validate files, write static definitions and event rows once, track counts/duplicates/completeness, close handles safely, and write natural/censored `run_summary.tsv`. Never overwrite an existing incompatible run.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Partial file open or header mismatch fails export closed and marks the run invalid without changing trading.
  - Duplicate pivot identity or duplicate signal-attempt writes are counted as integrity failures.
  - Deinit closes all handles and records a censored summary when natural completion is unavailable.
- **Validation**:
  - Static file-operation review covers open, header, append, flush policy, error throttling, summary, and deinit.
- **Rollback**: Revert Sprint 3.

### Task 3.3: Define Broker, Trailing, And Outcome Payload Boundaries

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh`, shared structs only as required
- **Description**: Add row builders for observation/pre-send/send-result checks, intended versus broker prices, milestone/modification facts, and broker-confirmed outcomes. Simulated path tracking must not be ported.
- **Dependencies**: Tasks 3.1-3.2 and existing execution fact structs.
- **Acceptance criteria**:
  - A signal can be recorded when denied before send.
  - An outcome cannot be written without a broker-confirmed fill and close.
  - Trailing requests and broker-confirmed SL remain distinguishable.
- **Validation**:
  - Static ownership review against `execution_broker_context.mqh` and `execution_broker_reconciliation.mqh`.
- **Rollback**: Revert Sprint 3.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] Every V9 header, key, event owner, and failure path is statically reviewed.
- [ ] No V8 writer or runtime source has been removed yet.
- [ ] `git diff --check` passes.
- [ ] No MetaEditor syntax check or compile was run.
- [ ] Exactly one Sprint 3 commit is created and its hash recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Atomically Cut Runtime Signals And Entries To Pivot Fractals

**Goal**: Make `PIVOT_FRACTAL_V1` the only active source, emit one V9 first-touch attempt per identity, and submit broker-safe market entries using the complete route matrix.
**Dependencies**: Sprint 3 gate complete.
**Tracked scope**: `HFT_Grid_AI.mq5`, inputs/enums, management/signals aggregators, pivot signal/state/detection structs, execution context/controller/lot/logging/reconciliation, V9 exporter integration, stable magic, and deletion of replaced active extremum/V8/runtime-ML/pattern files.
**Commit**: `feat: cut broker entries over to pivot fractal signals`
**Demo/Validation**:

- Exact runtime-flow tracing from cached level through first touch, feature snapshot, broker checks, one send, ticket capture, and V9 rows.
- Full 14-route static table comparison, including `NO_FORWARD_LEVEL` for Buy `R3` and Sell `S3`.
- Removed-identifier and include-topology sweeps.
- `git diff --check`
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Sprint 3 commit. Revert Sprint 4 as one unit to restore the V8/extremum runtime; do not run a mixed old/new `.ex5` live and do not relabel any V9 output as V8.

### Task 4.1: Replace Signal State With Exact Pivot Identity

- **Location**: `services/trading_signals/pivot_signal_struct.mqh`, `services/trading_signals/pivot_signal_state.mqh`, `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **Description**: Replace bullish/bearish extremum arrays and cycle/revision keys with one pivot signal collection keyed by exact identity. Store immutable source H/L/C, seven levels, direction, previous M1 context, feature snapshot, route, attempt/send flags, and execution state.
- **Dependencies**: Sprints 1-3.
- **Acceptance criteria**:
  - One identity has one first-touch state and at most one send attempt.
  - Same physical level across timeframes remains independent.
  - Window expiration removes only untriggered state; filled state retains captured levels.
  - A denied first direction consumes identity as explicitly decided.
- **Validation**:
  - Identifier collision review and array lifecycle/bounds review.
- **Rollback**: Revert Sprint 4.

### Task 4.2: Implement Bid First-Touch Discovery And Deterministic Gap Ordering

- **Location**: `services/trading_signals/pivot_fractal_signal_detection.mqh`, `HFT_Grid_AI.mq5`
- **Description**: Refresh windows/context at broker M1 transitions and pending-data retries, scan cached levels every tick, collect all newly crossed identities, order them by distance from previous M1 close with stable timeframe/level tie breakers, then record each first touch before broker admission.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Above/downward Bid touch yields buy; below/upward Bid touch yields sell.
  - Equality is neutral; gaps count; repeated ticks do not duplicate.
  - Feature capture occurs once before denial/send.
  - Multiple crossed identities are all observed even if later sends fail due to margin or another broker fact.
- **Validation**:
  - Static examples cover exact touch, gap up, gap down, same-tick confluence, equal close, unavailable M1 close, and window boundary.
- **Rollback**: Revert Sprint 4.

### Task 4.3: Build The Complete Immutable Route Matrix

- **Location**: `services/trading_signals/pivot_signal_struct.mqh` or a small route builder owned by the signal domain
- **Description**: Encode the matrix exactly once as captured initial SL, ordered milestones with desired SL, terminal TP, and admission reason. Calculate synthetic extreme stops only for Buy `S3` and Sell `R3`.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Every allowed direction/level combination matches the plan table.
  - Buy `R3` and Sell `S3` have no synthetic R4/S4 substitute and are denied before `OrderCheck`.
  - Route values cannot change after trigger even when the next pivot window starts.
  - Structural BE is not labeled as monetary 1R or guaranteed no-loss.
- **Validation**:
  - Manual 14-row route audit with exact expected levels.
- **Rollback**: Revert Sprint 4.

### Task 4.4: Preserve Broker Safety And Submit One Market Order

- **Location**: `services/trading_signals/execution_broker_context.mqh`, `execution_controller.mqh`, `execution_lot_math.mqh`, `execution_logging.mqh`, `market_status_controller.mqh`
- **Description**: Adapt the existing observation and fresh pre-send safety kernel to pivot signals. Use Ask for buy request geometry and Bid for sell request geometry, exact captured SL/TP, normalized volume, margin checks, `OrderCheck`, one `OrderSend`, compact identity comment, and the new stable magic namespace.
- **Dependencies**: Tasks 4.1-4.3.
- **Acceptance criteria**:
  - Non-hedging accounts still collect V9 attempts/checks and never send.
  - Invalid stops/freeze/price ordering, volume, margin, permission, session, or `OrderCheck` blocks rather than adjusting the route.
  - Buy trigger Bid, intended pivot, request Ask, and broker fill are stored separately.
  - One send result and retcode/comment are recorded per consumed identity.
- **Validation**:
  - Static pre-send authority review and exact `OrderSend`/retcode path tracing.
- **Rollback**: Revert Sprint 4.

### Task 4.5: Remove Active Extremum V8 And Runtime Research Behavior

- **Location**: Active MQL5 deletion list, `services/trading_signals.mqh`, `services/trading_management.mqh`, `services/trading_management/ea_inputs.mqh`, `HFT_Grid_AI.mq5`
- **Description**: Remove old cycle/revision/attempt/simulation exporter, extremum state/config, Fibonacci statistics, runtime ML shadow/filter, pattern playback, and their public inputs/callbacks. Activate only the V9 exporter.
- **Dependencies**: Tasks 4.1-4.4 provide complete replacements.
- **Acceptance criteria**:
  - Active include graph has no old exporter, ML shadow, pattern playback, cycle, revision, Fibonacci, or fixed-1R runtime path.
  - Public inputs retain market-data time, broker lot sizing, V9 export/run ID, and developer logs only.
  - Archives and generated historical datasets are untouched.
- **Validation**:
  - `rg -n "EXTREMUM_V1|engine_cycle|engine_revision|schema_v8|ML_INFERENCE_|Pattern_Audit|Fibonacci|SIMULATED_|broker_1r" HFT_Grid_AI.mq5 services indicators`
  - Expected result: no active behavior references; any intentional transition comment is reviewed and removed before the gate.
- **Rollback**: Revert Sprint 4 as one atomic cutover.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Runtime include tracing reaches only `PIVOT_FRACTAL_V1` signal creation.
- [ ] The complete route matrix and all broker checks pass static review.
- [ ] Active MQL5 V8/runtime ML/pattern/extremum files are deleted, not retained as compatibility code.
- [ ] `git diff --check` passes.
- [ ] No MetaEditor syntax check or compile was run.
- [ ] Exactly one Sprint 4 commit is created and its hash recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Add Ticket-First Pivot Trailing And Outcomes

**Goal**: Complete the broker-owned position lifecycle with monotonic captured-level trailing, reliable modification retries, and broker-confirmed V9 outcomes.
**Dependencies**: Sprint 4 gate complete.
**Tracked scope**: `services/trading_signals/pivot_signal_lifecycle.mqh`, execution controller/reconciliation/logging, signal structs/state, V9 trailing/outcome writers, entrypoint trade transaction/tick flow, and bounded visualization.
**Commit**: `feat: trail pivot positions by captured levels`
**Demo/Validation**:

- Static lifecycle traces for each route family, multi-milestone gaps, rejected modification, broker TP, broker SL, manual close, and deinit/restart reconciliation boundary.
- Ticket/magic/symbol/comment ownership and monotonic-SL review.
- `git diff --check`
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Sprint 4 commit. Revert Sprint 5 to return to entry-only pivot positions with their initial broker SL/TP; do not deploy that intermediate state live.

### Task 5.1: Reconcile Owned Pivot Positions By Ticket First

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/pivot_signal_lifecycle.mqh`
- **Description**: Select the stored position ticket first, then verify symbol, new magic, direction, and identity comment. Copy broker volume, entry, SL/TP, position identifier, close facts, and realized profit without local overwrite.
- **Dependencies**: Sprint 4 filled state.
- **Acceptance criteria**:
  - Multiple same-symbol/timeframe/level positions cannot cross-own tickets.
  - A missing/mismatched ticket fails closed and is recorded rather than selecting a convenient symbol position.
  - Broker facts remain authoritative after fill.
- **Validation**:
  - Exact selection and mismatch path review.
- **Rollback**: Revert Sprint 5.

### Task 5.2: Advance To The Strongest Reached Milestone

- **Location**: `services/trading_signals/pivot_signal_lifecycle.mqh`
- **Description**: Use Bid for buy profit milestones and Ask for sell profit milestones. Determine the strongest reached desired SL from immutable route milestones, skip no-change milestones, and submit at most one tighter desired state for a price jump.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - Buy SL never decreases; sell SL never increases.
  - No modification can remove SL or move TP away from the captured terminal level.
  - A tick crossing multiple milestones jumps directly to the strongest captured SL.
  - Window expiration or a newly calculated ladder cannot change the route.
- **Validation**:
  - Manual trace for PP, inner-level, extreme-level, and reversal route families in both directions.
- **Rollback**: Revert Sprint 5.

### Task 5.3: Handle Broker Modification Results And Retries

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/pivot_signal_lifecycle.mqh`, `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **Description**: Perform fresh ticket/price/stops/freeze validation, submit ticket-specific modification, inspect retcode/comment, reconcile confirmed SL, and retain a pending desired SL after transient rejection. Retry only while still needed and throttle identical failures.
- **Dependencies**: Task 5.2.
- **Acceptance criteria**:
  - Local state never claims an SL change until broker reconciliation confirms it.
  - Retry cannot widen protection or spam one request repeatedly on the same unchanged tick state.
  - Permanent invalid geometry is visible in trailing events and leaves the prior broker SL intact.
- **Validation**:
  - Static retcode, pending desired state, throttle, and close-race review.
- **Rollback**: Revert Sprint 5.

### Task 5.4: Finalize Broker Outcomes And Inspection Lines

- **Location**: `services/trading_signals/pivot_signal_lifecycle.mqh`, `pivot_fractal_statistics_export.mqh`, frontend execution visualization files
- **Description**: Record broker-confirmed terminal reason, realized result, final levels, and highest milestone. Show bounded intended entry/current broker SL/terminal TP lines labeled by timeframe/level without drawing the full reference-indicator channel or affecting execution.
- **Dependencies**: Tasks 5.1-5.3.
- **Acceptance criteria**:
  - Broker TP, broker SL, manual/other close, send failure, and canceled states are distinct.
  - Nonvisual tester runs perform no chart-object work.
  - Frontend state cannot enable, deny, resize, trail, or close positions.
- **Validation**:
  - Static outcome ownership and frontend isolation review.
- **Rollback**: Revert Sprint 5.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] Ticket-first reconciliation and monotonic trailing pass static review.
- [ ] Every trade operation and retcode path is checked.
- [ ] Frontend remains bounded and execution-neutral.
- [ ] `git diff --check` passes.
- [ ] No MetaEditor syntax check or compile was run.
- [ ] Exactly one Sprint 5 commit is created and its hash recorded.
- [ ] Sprint 6 has not started before this gate completes.

## Sprint 6: Replace V8 Python Research With Strict V9 Tooling

**Goal**: Make current DuckDB/audit/XGBoost tooling consume only schema V9 pivot data and delete active V8 adapters, runtime artifact tooling, tests, and fixtures.
**Dependencies**: Sprint 5 gate complete and final MQL5 V9 headers frozen.
**Tracked scope**: `tools/deterministic_signal_ml/`, its existing three test modules, replacement V9 fixture, requirements/README, and no new dependency or test-module count.
**Commit**: `refactor: replace schema v8 research tooling with v9`
**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Strict fixture validate-only and dataset-build commands defined in the updated tooling README.
- `git diff --check`
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Sprint 5 commit. Revert Sprint 6 to restore V8 Python tooling for historical code use only; it must remain incompatible with active V9 exports.

### Task 6.1: Replace The Active Schema And Dataset Contract

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`, `build_dataset.py`, `feature_encoder.py`, `model_config.py`
- **Description**: Require version `9`, engine `PIVOT_FRACTAL_V1`, feature set `schema_v9_pivot_fractal_xgb`, all nine V9 tables, strict keys, exact context rows, no duplicates, and no V8 fallback. Build normalized Parquet tables plus one leakage-safe training matrix.
- **Dependencies**: Frozen Sprint 5 V9 headers.
- **Acceptance criteria**:
  - V8 manifests/headers fail with a clear unsupported-schema error.
  - Each signal has one attempt, exactly six feature contexts when complete, and at most one broker outcome.
  - Training features contain only trigger-time facts; trailing/close/future-window facts are labels or audit data.
  - Denied/unfilled attempts remain analyzable but are excluded from broker-outcome targets unless a research command explicitly selects admission analysis.
- **Validation**:
  - Existing unit-test count retained through renamed/replaced modules and strict fixture checks.
- **Rollback**: Revert Sprint 6.

### Task 6.2: Define Pivot Outcome And Audit Semantics

- **Location**: Replace `extremum_engine_audit.py` with `pivot_fractal_audit.py`; update reporting/diagnostics modules that remain generic
- **Description**: Replace cycle/Fibonacci/1R audits with window validity, level/timeframe frequency, direction/reversal matrix, confluence, admission denial, milestone progression, terminal-target-before-stop, realized profit, duration, spread/slippage, and feature completeness analysis.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - No simulated path label is manufactured.
  - Broker-confirmed target/stop/other outcomes remain separate.
  - Structural BE and monetary profit/loss are reported separately.
  - Chronological splitting groups related symbol/window identities without using future fields.
- **Validation**:
  - V9 fixture audit produces deterministic compact outputs and rejects malformed joins.
- **Rollback**: Revert Sprint 6.

### Task 6.3: Preserve Offline XGBoost And Remove Runtime Artifact Paths

- **Location**: `train_model.py`, validation/comparison/reporting modules, and V8-only deletion list
- **Description**: Keep offline DuckDB/XGBoost training and robustness checks using V9 trigger-time features. Delete model export/deploy/shadow/filter/pattern playback code that existed only for MT5 runtime or schema V8 compatibility.
- **Dependencies**: Tasks 6.1-6.2.
- **Acceptance criteria**:
  - Training remains research-only and writes ignored artifacts.
  - No command claims runtime approval or emits an MT5 runtime model artifact.
  - Generic diagnostics are retained only after their schema assumptions are rewritten and tested.
  - Requirements stay pinned and no new dependency is added without evidence.
- **Validation**:
  - Python compile and existing test suite pass.
  - `rg -n "schema_v8|EXTREMUM_V1|broker_1r|engine_simulated_1r|APPROVED_FOR_MT5_RUNTIME|pattern playback|shadow inference" tools/deterministic_signal_ml`
  - Expected result: no active contract references outside an intentional unsupported-input error fixture, if retained and documented.
- **Rollback**: Revert Sprint 6.

### Task 6.4: Replace Existing Tests And Fixtures Without Growing Infrastructure

- **Location**: Existing three test modules and `tools/deterministic_signal_ml/tests/fixtures/`
- **Description**: Rename/replace the three extremum tests with V9 pivot schema, research contract, and audit tests. Delete the tracked `schema_v8_extremum_engine` fixture and add one compact `schema_v9_pivot_fractal` fixture covering all keys, six contexts, an allowed route, a denial, trailing, and a broker outcome.
- **Dependencies**: Tasks 6.1-6.3.
- **Acceptance criteria**:
  - Test-module count does not increase.
  - Fixture has no V8 compatibility rows and exercises referential integrity and leakage denial.
  - Malformed duplicate, missing-context, future-feature, and outcome-without-fill cases fail closed.
- **Validation**:
  - Full existing unittest discovery command passes.
- **Rollback**: Revert Sprint 6.

### Sprint 6 Gate

- [ ] All Sprint 6 tasks complete.
- [ ] Python compile, all existing/replaced tests, fixture validation, and a compact V9 dataset build pass.
- [ ] Active tracked V8 Python adapters, runtime artifact/pattern tooling, and V8 fixture are deleted.
- [ ] Offline DuckDB/XGBoost research remains functional and research-only.
- [ ] `git diff --check` passes.
- [ ] No MetaEditor syntax check or compile was run.
- [ ] Exactly one Sprint 6 commit is created and its hash recorded.
- [ ] Sprint 7 has not started before this gate completes.

## Sprint 7: Remove Dead Context And Align Active Documentation

**Goal**: Finish context reduction, remove all obsolete active files/references, and make current docs/inputs/frontend describe only the pivot collector/executor and V9 research boundary.
**Dependencies**: Sprint 6 gate complete.
**Tracked scope**: Remaining MQL5 deletion/refactor candidates, aggregators, public inputs, `AGENTS.md`, `README.md`, active architecture/workflow/environment docs, plan index, and bounded frontend copy.
**Commit**: `docs: align the pivot fractal broker executor foundation`
**Demo/Validation**:

- Exact public-input inventory.
- Active source/doc identifier sweeps exclude archives.
- Include tracing, file/line-count comparison, dead-reference review, and `git diff --check`.
- No MetaEditor syntax check or compile in this sprint.

**Rollback point**: Sprint 6 commit. Revert Sprint 7 to restore docs and final dead-file cleanup without changing the already implemented pivot runtime/research semantics.

### Task 7.1: Prune Residual Extremum And Indicator Context

- **Location**: `services/indicators/`, `services/trading_signals/`, `services/trading_management/`, aggregators
- **Description**: Remove unused extrema statistics and Fibonacci structures/functions, obsolete signal enums/fields/helpers, duplicate includes, and any dead V8 callbacks. Retain only the minimum Stoch Structure reader/classifier required for slots `0..2`.
- **Dependencies**: Runtime and Python cutovers complete.
- **Acceptance criteria**:
  - Every remaining tracked MQL5 module is reachable or intentionally standalone runtime indicator source.
  - No old cycle/revision/simulation/runtime model/pattern behavior remains hidden behind an unused include.
  - Include order remains the four-entrypoint aggregator chain.
- **Validation**:
  - `rg -n '#include' HFT_Grid_AI.mq5 services -g '*.mq5' -g '*.mqh'`
  - Exact removed-identifier sweep and tracked MQL5 file/line count.
- **Rollback**: Revert Sprint 7.

### Task 7.2: Finalize The Public Input Contract

- **Location**: `services/trading_management/ea_inputs.mqh`, `services/core/enums.mqh`, `AGENTS.md`, `README.md`
- **Description**: Remove runtime ML and pattern groups. Retain only market-data time, broker lot sizing, V9 statistics export/run ID, and developer logs. Keep pivot timeframes/formula internal and fixed.
- **Dependencies**: Task 7.1.
- **Acceptance criteria**:
  - No compatibility aliases for removed inputs.
  - Existing lot modes retain their semantics with structural pivot SL distance.
  - Public docs exactly match the compiled input declarations.
- **Validation**:
  - `rg -n '^input group|^input ' services/trading_management/ea_inputs.mqh`
  - Compare exact groups/fields against `AGENTS.md` and `README.md`.
- **Rollback**: Revert Sprint 7.

### Task 7.3: Rewrite Active Architecture, Workflow, And Environment Guidance

- **Location**: Active documentation list
- **Description**: Document pivot windows, Bid/Ask semantics, identity, route matrix, broker safety, V9 files, research commands, destructive active V8 cutover, compile policy, Strategy Tester matrix, and no-live-rollout restriction. Rename/remove obsolete workflow files without editing archives.
- **Dependencies**: Tasks 7.1-7.2.
- **Acceptance criteria**:
  - Active docs contain no statement that V8 or `EXTREMUM_V1` is current.
  - V9 paths/commands are consistent across architecture, workflow, environment, README, tooling README, and agent instructions.
  - `docs/plans/README.md` identifies this plan as active until Sprint 8 closeout.
- **Validation**:
  - `rg -n "schema v8|schema_v8|EXTREMUM_V1|fixed 1R|ML_INFERENCE_|Pattern_Audit" AGENTS.md README.md docs/architecture docs/workflows docs/environment docs/plans/README.md`
  - Expected result: no active-contract references, apart from an explicit historical incompatibility statement if needed.
- **Rollback**: Revert Sprint 7.

### Task 7.4: Confirm Bounded Frontend And Rollout Boundary

- **Location**: Frontend modules, `README.md`, architecture/runbook docs
- **Description**: Keep only bounded entry/current SL/terminal TP inspection lines and optional pivot identity labels. Record that chart objects never affect execution and that new magic plus old positions require a flat-symbol handoff.
- **Dependencies**: Tasks 7.1-7.3.
- **Acceptance criteria**:
  - Nonvisual tests skip chart work.
  - No buttons, editable levels, full pivot channel, or execution controls are added.
  - Rollout restriction requires old-engine positions flat, hedging mode, and one EA instance per account/symbol.
- **Validation**:
  - Static frontend call graph and docs review.
- **Rollback**: Revert Sprint 7.

### Sprint 7 Gate

- [ ] All Sprint 7 tasks complete.
- [ ] Active code/docs/tooling contain no current V8/extremum/runtime ML/pattern contract.
- [ ] Public inputs, include topology, file inventory, and frontend boundary pass review.
- [ ] Archived plans/research and external/generated datasets remain untouched.
- [ ] `git diff --check` passes.
- [ ] No MetaEditor syntax check or compile was run.
- [ ] Exactly one Sprint 7 commit is created and its hash recorded.
- [ ] Sprint 8 has not started before this gate completes.

## Sprint 8: Final Compile, Strategy Tester Acceptance, And Closeout

**Goal**: Run the only real compile, strict Python/V9 integration, human broker lifecycle matrix, performance comparison, and plan closeout.
**Dependencies**: Sprint 7 gate complete; MetaEditor/Wine and human Strategy Tester access available.
**Tracked scope**: Integration fixes only, compact validation evidence, active/archived plan indexes, and final documentation corrections. Do not add features during closeout.
**Commit**: `chore: validate pivot fractal engine and schema v9`
**Demo/Validation**:

- Final static/reference sweeps and Python tests.
- Real MetaEditor compile with `0 errors, 0 warnings` and regenerated `HFT_Grid_AI.ex5`.
- Human Strategy Tester/chart acceptance for pivot timing, first-touch directions, route/trailing behavior, broker denials, V9 exports, DST, and performance.

**Rollback point**: Sprint 7 commit before integration fixes. If compile or Strategy Tester reveals unsafe behavior, leave Sprint 8 uncommitted, fix within Sprint 8, and rerun every final gate. Do not live-roll out a partially accepted build.

### Task 8.1: Run Final Static And Python Integration Checks

- **Location**: Entire active repository excluding archives/generated artifacts
- **Description**: Run exact identifier/reference sweeps, include tracing, file/line inventory, whitespace checks, Python compile/tests, strict V9 fixture validation, and one compact dataset/audit build.
- **Dependencies**: Sprint 7.
- **Acceptance criteria**:
  - No broken references, duplicate includes, active V8 identifiers, fixture mismatch, or Python failure.
  - V9 tables satisfy identity, six-context, execution, trailing, and outcome integrity.
  - Any historical V8 reference is confined to archives or an explicit unsupported-schema error message.
- **Validation**:
  - `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
  - `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
  - Updated V9 `build_dataset.py --validate-only` and audit commands from the runbook.
  - `git diff --check`
- **Rollback**: Fix within uncommitted Sprint 8 or revert to Sprint 7.

### Task 8.2: Run The Only MetaEditor Compile Sprint

- **Location**: `HFT_Grid_AI.mq5`, `tools/mt5/compile_mt5.py`, `logs/compile/agentic-build.log`
- **Description**: Run the real compile, parse the compact result, verify `0 errors, 0 warnings`, and confirm `.ex5` regeneration. `/s` syntax-only mode is not accepted as final evidence.
- **Dependencies**: Task 8.1 passes.
- **Acceptance criteria**:
  - Compile reports exactly `0 errors, 0 warnings`.
  - `HFT_Grid_AI.ex5` timestamp/size changes consistently with regeneration.
  - Any Wine return-code discrepancy is recorded alongside parsed compiler status.
- **Validation**:
  - `python3 tools/mt5/compile_mt5.py --wine --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" --log "logs/compile/agentic-build.log" --mode compile`
- **Rollback**: Fix within Sprint 8; do not commit a failing compile.

### Task 8.3: Run Human Pivot Window And Trigger Acceptance

- **Location**: MetaTrader 5 Strategy Tester, real-tick mode where available, V9 Common Files output
- **Description**: Verify broker-native window calculation and exact first-touch behavior over representative history.
- **Dependencies**: Task 8.2 passes.
- **Acceptance criteria**:
  - At an `M30` transition such as `09:30`, `M15` and `M30` refresh from their just-completed candles while the existing `H1/H4/D1` sets remain unchanged until their own transitions.
  - No incomplete/synthetic source candle is used; weekend and session gaps retain broker-native series identity.
  - Prior M1 Bid close above plus downward Bid touch creates buy; below plus upward Bid touch creates sell; buy fill records Ask.
  - Exact touches, gap-through events, equality-neutral context, identity deduplication, window expiry, and same-tick confluence match the contract.
  - Same price across timeframes creates separate attempts; non-hedging mode records denial and sends none.
- **Validation**:
  - Human inspection of compact logs/V9 rows with exact broker timestamps and identities.
- **Rollback**: Stop acceptance and fix within Sprint 8.

### Task 8.4: Run Human Route, Trailing, And Broker Safety Acceptance

- **Location**: Strategy Tester and visual chart inspection
- **Description**: Exercise all route families and broker lifecycle boundaries without a custom MQL5 harness.
- **Dependencies**: Task 8.3 passes.
- **Acceptance criteria**:
  - Static plus observed coverage confirms all 14 matrix rows; Buy `R3` and Sell `S3` are recorded/denied without sends.
  - At least one PP route, one inner natural route, one extreme natural route, and one reversal route are observed in each direction, or the sprint remains open until equivalent human evidence is supplied.
  - Milestone gaps choose the strongest SL, no-change milestones stay unchanged, failed modifications retain prior protection and retry safely, and broker TP/SL outcomes reconcile by ticket.
  - Closed session, trade mode, permissions, invalid tick, stops/freeze, invalid volume, insufficient margin, `OrderCheck`, and send failures remain fail-closed and observable.
  - Visual mode shows bounded entry/current SL/terminal TP lines; nonvisual mode creates no chart objects.
- **Validation**:
  - Human Strategy Tester/chart evidence with compact route, ticket, retcode, and outcome records.
- **Rollback**: Stop acceptance and fix within Sprint 8.

### Task 8.5: Validate V9 Features, Time, And Performance

- **Location**: V9 run folders, updated Python validator/audit, Strategy Tester
- **Description**: Compare export-disabled and V9-export-enabled runs over the same symbol/model/date/input range with file logs off, while verifying feature/time semantics.
- **Dependencies**: Tasks 8.3-8.4.
- **Acceptance criteria**:
  - Every complete attempt has exactly six feature rows with structure `0..2` and raw `%B 0..5`; shift 0 matches trigger Bid semantics.
  - Broker time remains causal; `FIXED_TIME_SESSIONS` equality and documented Exness winter/summer/US/UK DST normalization remain export-only.
  - Run summary is natural/`OK`, duplicate identities are zero, referential checks pass, and Python strict validation succeeds.
  - Export overhead and output growth are measured over the same 1-3 market days and show no per-tick handle creation, full-history scans, or unbounded logs.
- **Validation**:
  - Updated runbook validate/build/audit commands and compact elapsed-time/count/size comparison.
- **Rollback**: Fix within Sprint 8; never relabel an invalid run as accepted.

### Task 8.6: Record Closeout And Archive The Plan

- **Location**: This plan, `docs/plans/README.md`, archive directory/index, active docs if final evidence changes them
- **Description**: Record all eight commit hashes/rollback points and compact final evidence, mark the plan complete, move it into a dated archive folder according to local practice, and restore `docs/plans/README.md` to no active plan.
- **Dependencies**: Tasks 8.1-8.5 all pass.
- **Acceptance criteria**:
  - Evidence distinguishes static, Python, compile, and human checks without claiming unrun validation.
  - Every sprint has exactly one commit and recorded rollback point.
  - No live rollout approval is implied.
- **Validation**:
  - Final `rtk git status`, `rtk git log`, archive link review, and `git diff --check` before the Sprint 8 commit.
- **Rollback**: Revert the Sprint 8 closeout commit to the validated Sprint 7 state if documentation/evidence is wrong; do not discard external test evidence.

### Sprint 8 Gate

- [ ] All Sprint 8 tasks complete.
- [ ] Final static and Python checks pass.
- [ ] Real MetaEditor compile reports `0 errors, 0 warnings` and regenerates `.ex5`.
- [ ] Human Strategy Tester/chart acceptance passes the pivot, broker, route, trailing, V9, DST, and performance matrix.
- [ ] All eight sprint rollback points and residual risks are recorded.
- [ ] Exactly one Sprint 8 commit is created with the proposed message.
- [ ] The plan is archived and no active plan remains.
- [ ] Live rollout remains separately unauthorized.

## Testing Strategy

- **MQL5 unit**: Do not add a unit harness. Use pure-function/static numeric review for formulas and the complete route table, exact identifier/reference sweeps, bounds checks, include tracing, and final real compilation.
- **Python unit/contract**: Replace, do not increase, the existing three test modules. Cover strict headers, keys, duplicates, six-context completeness, no-future-feature rules, route/audit semantics, and outcome ownership.
- **Integration**: Validate one strict V9 fixture and one real V9 Strategy Tester run through TSV validation, Parquet assembly, audit output, and an XGBoost-ready matrix.
- **End-to-end/manual**: Human Strategy Tester/chart verification is mandatory for broker bar transitions, touches, gaps, confluence, broker checks, sends, ticket reconciliation, trailing, TP/SL, DST, and frontend behavior.
- **Trading safety**: Reinspect hedging mode, actual broker session/trade mode, permissions, bid/ask, spread facts, stops/freeze, exact geometry, volume normalization, margin, `OrderCheck`, retcodes, magic/comment/ticket ownership, and old-position rollout isolation.
- **Data migration**: This is a destructive active-contract cutover with no row migration. V8 active code/fixtures are deleted; V8 generated data remains historical and cannot be passed to V9 commands.
- **Performance**: Confirm window reads occur only at init/bar change/pending retry, indicator handles are reused, trigger scans are bounded to 35 active identities, position lifecycle scans are bounded by owned attempts, logs are throttled, and export-off/on measurements are recorded.
- **Security/privacy**: No account IDs, credentials, tokens, proprietary full logs, or generated datasets are added to Git or external research calls. Existing Common Files/artifacts remain local and ignored.
- **Accessibility/UI**: No interactive UI is introduced. Visual acceptance covers legible bounded labels/lines and confirms nonvisual runs do no chart work.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Bid trigger versus Ask buy fill | Buy entry may fill above the touched pivot by spread/slippage | Keep side and touch consistently Bid-based, run fresh Ask geometry checks, and export intended/Bid/Ask/fill separately | V9 attempt/check/outcome rows reconcile all four prices |
| Structural BE is not monetary BE | A stop at the logical entry level may still lose spread, commission, swap, or slippage | Label it structural BE only and retain broker costs/realized profit | Audit compares structural stop level with actual net result |
| Many independent identities | Up to 35 level identities per window set can increase margin/exposure quickly | Preserve hedging, margin, volume, and `OrderCheck` denials; do not add hidden concurrency policy | Confluence run shows every attempt and broker denial/send order |
| Gap crosses several levels | Send ordering can change which attempts receive available margin | Record all first touches, sort by distance from prior M1 close, then stable timeframe/level tie breaks | Repeated tester run produces identical attempt/send ordering |
| First unsupported extreme consumes identity | A later valid opposite touch in the same window cannot trade that level | Preserve user-approved identity without direction and record `NO_FORWARD_LEVEL` clearly | One attempt only for Buy R3/Sell S3 identities |
| Missing/delayed series data | New windows could accidentally reuse stale levels or stale M1 context | Invalidate the new identity until shift-1 data is available; controlled retries only | No row combines a new active open with an old source candle |
| Broker D1/weekend boundaries | Fixed seconds can misidentify lifecycle across gaps | Use actual `iTime` transitions and shift-1 `CopyRates`; use `PeriodSeconds` only for metadata/scheduling hints | Weekend tester evidence shows no synthetic bar |
| Tick-size normalization collapses levels | Tiny source range may make route geometry ambiguous | Retain raw values, require strictly ordered normalized ladder, mark window invalid | Invalid-window reason and zero attempts for collapsed ladder |
| Stops/freeze reject trailing | Desired protection may lag after a milestone | Keep prior broker SL, retain strongest pending desired SL, retry safely with retcode telemetry | Trailing events distinguish requested, rejected, retried, confirmed |
| Window expires while position remains open | Recalculation could corrupt an active route | Copy all seven levels and route into immutable position-owned state | Position keeps original window ID/levels after next bar |
| V8 destructive cutover | Historical scripts/models no longer run on current checkout | Delete active compatibility deliberately, preserve Git history/archives/generated data, use separate V9 root | V8 inputs fail clearly; archives/data remain untouched |
| Feature handle readiness | Missing structure/bands data can create incomplete ML rows | Validate handles/buffers, mark run incomplete, never alter execution | `run_summary` feature completeness and strict validator failure |
| New magic namespace | Old positions cannot be safely reconciled by new engine | Require old-engine positions flat before any future rollout | Human preflight confirms no old symbol positions |
| Local/broker close race | Local milestone code could act after broker TP/SL | Reconcile ticket state before modifications and let broker terminal protection own close | No modification after confirmed close; one broker outcome |
| Hot-path export/logging cost | Always-on M1 collector can slow tester/live processing | Bound scans, reuse handles/cache, append compact rows, throttle errors, compare export off/on | Measured elapsed time, row counts, and folder bytes |

## Rollback Plan

- Every sprint starts from the recorded prior sprint commit and ends in exactly one new commit. Prefer `git revert <sprint_commit>` for a shared/history-preserving rollback; never use destructive reset commands as an implementation shortcut.
- Sprints 1-3 are dormant foundations. Reverting them removes pivot types/features/export without affecting the V8 runtime baseline.
- Sprint 4 is the atomic source/schema/runtime cutover. Revert the whole Sprint 4 commit to restore V8/extremum runtime behavior; never combine old signal state with V9 execution/export files.
- Sprint 5 can be reverted to the Sprint 4 entry-only pivot state for diagnosis, but that intermediate state is not approved for deployment.
- Sprint 6 can be reverted independently to restore historical V8 Python tooling. That tooling must not be pointed at V9 output.
- Sprint 7 can be reverted for documentation/dead-context corrections without rolling back implemented pivot behavior.
- Sprint 8 remains uncommitted until all final checks pass. Revert its single closeout commit only if final fixes/evidence/archiving are wrong.
- Schema files are append-only evidence. Never overwrite or relabel V8 runs as V9 or failed/censored V9 runs as accepted. Use a new run ID after any schema/header-affecting fix.
- Generated/external V8 datasets and archived plans/research are not deleted by this plan and therefore require no data restoration step.
- Any future runtime rollback requires all new-engine positions flat before loading an older `.ex5`; magic namespaces intentionally do not cross-reconcile.

## Execution Order

1. Read the planner execution-state instructions and initialize active-plan state.
2. Implement Sprint 1 only.
3. Run and record all Sprint 1 validation without MetaEditor.
4. Create exactly one Sprint 1 commit and record its hash as the rollback point.
5. Start Sprint 2 only after the Sprint 1 gate passes.
6. Repeat the complete/validate/one-commit/record-rollback gate for Sprints 2-7; do not run MetaEditor in those sprints.
7. Start Sprint 8 only after Sprint 7 is committed and clean.
8. Run final static/Python checks, the only real MetaEditor compile, and human Strategy Tester/chart acceptance.
9. Create exactly one Sprint 8 commit only after every final gate passes, then archive the plan.

## Completion Checklist

- [ ] `PIVOT_FRACTAL_V1` is the only active signal source.
- [ ] `M15/M30/H1/H4/D1` use only their immediately previous completed broker candles.
- [ ] `M1` supplies only side/trigger context and requested research features.
- [ ] First-touch identity, Bid/Ask semantics, gap ordering, expiry, and confluence match the fixed contract.
- [ ] All allowed routes and the two `NO_FORWARD_LEVEL` denials match the matrix.
- [ ] Broker entry, SL/TP, trailing, ticket reconciliation, and outcomes remain fail-closed and broker-authoritative.
- [ ] Schema V9 strict export, DuckDB ingestion, audit, and offline XGBoost-ready data pass validation.
- [ ] Active V8/extremum/runtime ML/pattern code, adapters, tests, and fixtures are removed.
- [ ] Archived plans/research and external/generated historical datasets remain preserved.
- [ ] Public inputs and active documentation describe only the final pivot runtime.
- [ ] Every sprint has exactly one commit and recorded rollback point.
- [ ] Final compile reports `0 errors, 0 warnings` and human Strategy Tester/chart acceptance passes.
- [ ] No live rollout is authorized by plan completion.
