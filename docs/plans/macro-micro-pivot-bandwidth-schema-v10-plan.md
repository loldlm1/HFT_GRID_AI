# Plan: Macro-Micro Pivot Bands Engine And Schema V10

**Generated**: 2026-08-06
**Status**: Active implementation; Sprint 2 complete, Sprint 3 pending
**Planning Review**: Complete; no blocking clarification remains
**Estimated Complexity**: High
**Risk Class**: Critical - changes signal arming, trade direction, stop/target geometry, lot sizing, broker lifecycle state, persistence, and ML research inputs
**Execution Baseline**: Branch `bot/pivot_points_fractal`, commit `0a47ce2df99f804667f8110c2c8788f4fb89f297`

## Overview

Replace the current five-pivot-timeframe, six-context-timeframe `PIVOT_FRACTAL_V1` and schema V9 contract with a deliberately smaller `PIVOT_FRACTAL_V2` and strict schema V10 contract.

The new runtime owns one configurable Macro timeframe, default `H1`, and one configurable Micro timeframe, default `M3`. The immediately previous completed Macro broker candle, shift `1`, creates one classic seven-level pivot ladder for the current Macro active bar. Supports `S1..S3` are buy-only virtual limit triggers, resistances `R1..R3` are sell-only virtual limit triggers, and `PP` is armed once as support or resistance from the first causal Bid side observed for the Macro window.

The trigger price is the observed live Bid from `MqlTick`, equivalent to the current Bid-based chart close at that tick. The EA does not place pending orders. A first eligible condition consumes the immutable level identity and submits a market order only after fresh broker checks. Buy requests use fresh Ask; sell requests use fresh Bid.

Every allowed route uses one structural broker SL and a fresh quote-based 1:1 broker TP. Percentage sizing no longer uses changing account balance. It uses a fixed internal reference balance of `1,000,000` account-currency units; the default `0.01` percent therefore requests a `100` unit risk budget before broker volume normalization. No trailing or stop modification remains.

Research context is reduced to Bollinger Bands using fixed `21`, `2.0`, SMA, and `PRICE_WEIGHTED`. Micro features describe the observed market around the trigger. Macro `%B` features project the immutable pivot price through the Macro band envelopes. Stoch Structure, multi-timeframe retest/confluence, admission modeling, trailing analytics, and absolute raw prices as ML features are removed.

Target runtime flow:

```text
real broker tick
-> refresh one causal Macro window only when its broker bar changes or retry is due
-> calculate classic PP/S1..S3/R1..R3 from Macro shift 1
-> cache Macro shift-1 weighted bands and PP role for the active window
-> evaluate live Bid virtual-limit conditions for seven unconsumed identities
-> capture one Micro band snapshot and one Macro band-envelope snapshot per tick batch
-> derive level-specific Macro pivot %B values
-> build structural SL and fresh Bid/Ask 1R request geometry
-> calculate volume from the fixed reference risk budget
-> repeat broker safety checks and OrderCheck immediately before OrderSend
-> one market position with immutable broker SL and TP
-> ticket-first reconciliation without trailing
-> broker-confirmed TP/SL or excluded nonbinary outcome
-> optional strict six-file schema V10 persistence
-> leakage-safe one-row research matrix and offline XGBoost
```

## Scope

- **In scope**:
  - Add public `Macro_Timeframe` and `Micro_Timeframe` inputs with defaults `H1` and `M3`.
  - Validate that both timeframes are explicit, supported, distinct, and `Micro_Timeframe < Macro_Timeframe`.
  - Replace the fixed five-window engine with one Macro pivot window.
  - Preserve classic `PP`, `S1..S3`, and `R1..R3` formulas from the immediately previous completed Macro broker candle.
  - Replace previous-M1-close crossing logic with live Bid virtual-limit conditions.
  - Arm `PP` from the Macro window's first causal live Bid side and require a return touch.
  - Preserve one consumed first trigger per `(symbol, Macro timeframe, active Macro bar open, level)` even when routing or broker execution fails.
  - Replace all Stoch Structure and six-timeframe context code with two cached built-in `iBands` handles.
  - Use fixed Bands parameters: period `21`, deviation `2.0`, shift `0`, SMA, `PRICE_WEIGHTED`.
  - Capture Micro `%B 0..5`, Macro pivot `%B 0..5`, Micro shift-0 bandwidth, and Macro shift-1 bandwidth.
  - Record raw and normalized bandwidth while keeping model features scale-aware.
  - Replace pivot-terminal/trailing routes with one fresh quote-based 1:1 TP and one immutable structural SL.
  - Rename balance-percentage sizing to fixed reference-balance percentage sizing and default it to `0.01` of `1,000,000`.
  - Preserve fixed-lot mode as a separate configuration that cannot be mixed into a reference-risk dataset.
  - Remove all trailing state, modifications, events, reconciliation fields, and research analysis.
  - Add quote expectation, fill slippage, exit slippage, gross profit, commission, swap, fee, net profit, and R-normalized outcome facts.
  - Replace strict schema V9 with strict schema V10 under a new `PivotFractalV10` storage root containing exactly six TSV files.
  - Produce one wide trigger-time research matrix and one strict broker TP/SL binary cohort.
  - Remove active retest/confluence tooling and admission-target modeling.
  - Update active architecture, workflows, environment guidance, product copy, repository instructions, fixtures, tests, audits, and training reports.
  - Perform one final real MetaEditor compile and mandatory human real-tick Strategy Tester acceptance.
- **Out of scope**:
  - Pending broker limit orders. The strategy uses virtual conditions followed by market orders.
  - Multiple Macro pivot timeframes, multi-timeframe confluence, synthetic candles, or wall-clock aggregation.
  - Configurable Bands period, deviation, MA method, applied price, or shift.
  - Stochastic, structure classification, ATR, RSI, MACD, order-book, news-feed, or other new indicators.
  - Runtime model loading, model filtering, pattern playback, online learning, or model-based order authorization.
  - Trailing, break-even, partial closes, multi-target exits, variable R, or position resizing.
  - Reintroducing spread thresholds, direction inputs, concurrency selectors, daily limits, or compatibility aliases.
  - Converting, adapting, or relabeling V9 runs as V10.
  - Mixing fixed-lot and reference-risk runs, account currencies, or differing Macro/Micro configurations in one initial model dataset.
  - Treating manual closes, stop-outs, other broker closes, denied attempts, failed sends, or censored positions as binary losses.
  - New MQL5 test harnesses, scripts, test EAs, custom test modules, MQL5 CI, or agentic tester automation.
  - Live rollout.
- **Fixed decisions**:
  - New engine label: `PIVOT_FRACTAL_V2`.
  - New strict schema: `10` with feature set `schema_v10_macro_micro_pivot_bands`.
  - New Common Files root: `PivotFractalV10\runs\<run_id>\`.
  - Defaults: `Macro_Timeframe=PERIOD_H1`, `Micro_Timeframe=PERIOD_M3`.
  - Bands use `iBands(..., 21, 0, 2.0, PRICE_WEIGHTED)` with buffers `0=BASE_LINE`, `1=UPPER_BAND`, and `2=LOWER_BAND`.
  - `PRICE_WEIGHTED` means `(High + Low + Close + Close) / 4`.
  - Shift `0` always means the developing current bar observed at the trigger tick; shifts `1..5` are completed causal bars.
  - Live Bid from the observed `MqlTick` is the trigger price. The hot path does not call `iClose(..., 0)` per tick.
  - `S1`, `S2`, and `S3` are buy-only: trigger when live Bid is at or below the level.
  - `R1`, `R2`, and `R3` are sell-only: trigger when live Bid is at or above the level.
  - On the first causal tick of a Macro window, Bid above `PP` arms `PP` as a future support buy; Bid below `PP` arms it as a future resistance sell.
  - If the first causal Bid equals `PP`, PP remains neutral until Bid first leaves strictly above or below; it then arms the opposite return touch.
  - A support or resistance already marketable on the first causal window tick may trigger immediately, matching virtual-limit behavior.
  - A first trigger consumes the level identity even if the route, volume, broker check, `OrderCheck`, or `OrderSend` fails.
  - Same-tick downward batches process path order `PP` when buy-armed, then `S1`, `S2`, `S3`; upward batches process `PP` when sell-armed, then `R1`, `R2`, `R3`.
  - Buy triggers and features use Bid; buy request and volume geometry use fresh Ask. Sell trigger, request, and geometry use fresh Bid.
  - Initial SL matrix:
    - Buy `PP -> S1`, `S1 -> S2`, `S2 -> S3`, `S3 -> S3 - (S2 - S3)`.
    - Sell `PP -> R1`, `R1 -> R2`, `R2 -> R3`, `R3 -> R3 + (R3 - R2)`.
  - Fresh pre-send 1R matrix:
    - Buy risk distance is `fresh Ask - structural SL`; TP is `fresh Ask + risk distance`.
    - Sell risk distance is `structural SL - fresh Bid`; TP is `fresh Bid - risk distance`.
  - Only the fresh pre-send quote, geometry, volume, and `OrderCheck` may authorize `OrderSend`.
  - `EXECUTION_LOT_REFERENCE_BALANCE_PERCENT` uses fixed internal reference balance `1,000,000`, not `ACCOUNT_BALANCE`.
  - Default lot configuration is `EXECUTION_LOT_REFERENCE_BALANCE_PERCENT` and `Lot_Strategy_Size=0.01`.
  - The resulting `100` is in account-currency units; accepted datasets cannot mix currencies.
  - Volume is normalized downward. A broker minimum that would exceed the risk budget blocks the send.
  - The submitted price-distance reward/risk ratio is exactly `1.0`; quote-time monetary loss/profit mismatch is stored separately and is not called slippage.
  - Entry and exit slippage use one sign convention: positive is adverse, negative is favorable. Slippage begins only when broker fill or close differs from submitted or broker-confirmed price facts.
  - No broker-side SL/TP modification occurs after a fill.
  - Binary research contains only fully closed positions whose owned closing volume has one consistent broker-confirmed `DEAL_REASON_TP` or `DEAL_REASON_SL` outcome.
  - Nonbinary outcomes remain required integrity and operational facts but are excluded from pattern filters, performance groups, and XGBoost targets.
  - Feature availability never authorizes or denies execution. Missing band facts invalidate research completeness only.
  - V9 source compatibility and dual writing are not retained. Historical V9 runs, fixtures, artifacts, plans, and evidence remain preserved.
  - The stable internal magic changes to a `PIVOT_FRACTAL_V2` namespace so V1 positions cannot be adopted accidentally.
- **Assumptions**:
  - The broker's chart price is Bid-based for the supported OTC symbols, matching current project semantics.
  - `PERIOD_M3` series and weighted Bands history are available or become available through normal terminal synchronization.
  - The accepted research account uses USD if results are described with a dollar sign; otherwise `100` means 100 units of the recorded account currency.
  - One EA instance runs per account and symbol, and execution still requires `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
  - Existing session, permission, symbol mode, stops/freeze, margin, `OrderCheck`, magic, ticket, and reconciliation safeguards remain mandatory.
  - The current fixed Bands period/deviation are retained because changing them is not part of this request.

## Runtime And Research Contracts

### Public Input Contract

| Group | Inputs and defaults |
| --- | --- |
| `+= Market Data Time =+` | `Broker_Session`, `Macro_Timeframe=PERIOD_H1`, `Micro_Timeframe=PERIOD_M3` |
| `+= Broker Execution =+` | `Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`, `Lot_Strategy_Size=0.01` |
| `+= Signal Statistics Export =+` | `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id` |
| `+= Developer Debug Settings =+` | `Enable_Logs`, `Enable_File_Logs` |

No reference-balance input is added. The fixed `1,000,000` reference and account currency are explicit manifest facts.

### Trigger And Route Matrix

| Level | Role | Live Bid trigger | Structural SL | Fresh quote TP |
| --- | --- | --- | --- | --- |
| `PP` | Buy when PP was armed from initial Bid above | `Bid <= PP` after arming | `S1` | `fresh Ask + (fresh Ask - S1)` |
| `PP` | Sell when PP was armed from initial Bid below | `Bid >= PP` after arming | `R1` | `fresh Bid - (R1 - fresh Bid)` |
| `S1` | Buy support | `Bid <= S1` | `S2` | `fresh Ask + (fresh Ask - S2)` |
| `S2` | Buy support | `Bid <= S2` | `S3` | `fresh Ask + (fresh Ask - S3)` |
| `S3` | Buy support | `Bid <= S3` | `S3 - (S2 - S3)` | `fresh Ask + (fresh Ask - SL)` |
| `R1` | Sell resistance | `Bid >= R1` | `R2` | `fresh Bid - (R2 - fresh Bid)` |
| `R2` | Sell resistance | `Bid >= R2` | `R3` | `fresh Bid - (R3 - fresh Bid)` |
| `R3` | Sell resistance | `Bid >= R3` | `R3 + (R3 - R2)` | `fresh Bid - (SL - fresh Bid)` |

The target is exactly one price-distance R from the fresh request-side quote after price normalization. Broker volume steps, instrument profit conversion, price movement between request and fill, commissions, swap, fees, and close execution may make expected or realized money differ from the fixed risk budget.

### Band Feature Contract

| Feature | Price numerator | Band timeframe and shifts | Capture time | Model use |
| --- | --- | --- | --- | --- |
| `micro_b_percent_0` | Trigger Bid | Micro shift `0` | Trigger tick | Yes |
| `micro_b_percent_1..5` | Matching completed bar `PRICE_WEIGHTED` value | Micro shifts `1..5` | Trigger tick batch | Yes |
| `macro_pivot_b_percent_0..5` | Immutable touched pivot trade price | Macro shifts `0..5` | Level-specific derivation at trigger | Yes |
| `micro_band_width_0` | `upper_0 - lower_0` | Micro shift `0` | Trigger tick batch | Raw audit only |
| `micro_band_width_percent_0` | `100 * width_0 / base_0` | Micro shift `0` | Trigger tick batch | Yes |
| `macro_band_width_1` | `upper_1 - lower_1` | Macro shift `1` | Macro window creation | Raw audit only |
| `macro_band_width_percent_1` | `100 * width_1 / base_1` | Macro shift `1` | Macro window creation | Yes |

`%B = 100 * (price - lower_band) / (upper_band - lower_band)`. Values are not clipped to `[0,100]`. Invalid, zero-width, unavailable, future-visible, or nonfinite bands mark the feature snapshot incomplete.

### Outcome And Slippage Contract

- `risk_budget_amount`: fixed reference balance times configured percent in
  reference-risk mode; null in fixed-lot mode.
- `request_risk_distance_points`: normalized fresh request price to structural SL distance.
- `request_reward_distance_points`: normalized fresh request price to submitted TP distance; it must equal `request_risk_distance_points`.
- `request_price_reward_risk_ratio`: submitted reward distance divided by risk distance; it must equal `1.0` within price tolerance.
- `quote_expected_stop_loss`: `OrderCalcProfit` magnitude from fresh request quote to structural SL after normalized volume.
- `quote_expected_take_profit`: `OrderCalcProfit` magnitude from fresh request quote to submitted 1R TP after normalized volume.
- `quote_expected_reward_risk_ratio`: expected TP magnitude divided by expected SL magnitude.
- `risk_budget_utilization_ratio`: quote expected stop-loss magnitude divided by
  `risk_budget_amount` in reference-risk mode; null in fixed-lot mode.
- `entry_slippage_points`: buy `fill - request`, sell `request - fill`; positive means adverse and negative means favorable.
- `exit_slippage_points`: buy `terminal - close`, sell `close - terminal`, using the broker-confirmed immutable TP or SL; positive means adverse and negative means favorable.
- `gross_profit`: sum of broker `DEAL_PROFIT` for the owned position history.
- `commission`: sum of broker `DEAL_COMMISSION`.
- `swap`: sum of broker `DEAL_SWAP`.
- `fee`: sum of broker `DEAL_FEE` when available.
- `net_profit`: gross profit plus commission, swap, and fee.
- `gross_budget_r` and `net_budget_r`: gross or net profit divided by
  `risk_budget_amount` in reference-risk mode; null in fixed-lot mode.
- `gross_execution_r` and `net_execution_r`: gross or net profit divided by `quote_expected_stop_loss` when it is valid and positive.
- `binary_target`: `1` only when all owned closing volume is broker TP, `0` only when all owned closing volume is broker SL, and null for mixed or excluded terminal reasons.

### Strict Schema V10 Files

| File | Grain | Required content |
| --- | --- | --- |
| `run_manifest.tsv` | One key/value manifest | Engine/schema IDs, symbol, timeframes, Bands policy, trigger/PP policy, route policy, lot mode/reference/currency, time policy, feature set, binary cohort policy |
| `pivot_windows.tsv` | One row per Macro active bar | Window/source times, source OHLC/range, seven wide raw and trade pivot prices, PP arming facts, cached Macro shift-1 band base/upper/lower/raw width/normalized width, validity and terminal state |
| `signal_attempts.tsv` | One row per consumed level identity | Trigger/analysis time, level/direction, trigger Bid/Ask/spread, pivot price, structural SL, final request geometry when available, Micro `%B 0..5`, Macro pivot `%B 0..5`, Micro shift-0 band/width facts, completeness, route/admission/send facts |
| `execution_checks.tsv` | Ordered check rows per attempt | Observation, pre-send, send, ownership, and terminal broker facts including quote expected loss/profit and normalized volume; no trailing phases |
| `signal_outcomes.tsv` | One row per broker-confirmed closed position | Request/fill/close facts, immutable SL/TP, cost components, slippage, gross/net P&L, R values, close reason, binary eligibility, duration, ticket ownership |
| `run_summary.tsv` | One terminal row | Six-table counts, TP/SL cohort counts, exclusion counts by reason, feature completeness, duplicates, integrity errors, export and completion status |

The offline builder may create typed Parquet copies plus a wide `research_matrix.parquet` and `binary_outcomes.parquet`; those are generated artifacts, not additional runtime TSV contracts.

### Model Feature Contract

- **Categorical trigger-time features**: `symbol`, `level_id`, `direction`, analysis weekday, and session/calendar categories already supported by the time policy.
- **Continuous trigger-time features**:
  - `micro_band_width_percent_0`;
  - `macro_band_width_percent_1`;
  - `micro_b_percent_0..5`;
  - `macro_pivot_b_percent_0..5`;
  - trigger gap to pivot normalized by structural risk distance;
  - spread normalized by structural risk distance;
  - Macro source range normalized by Macro band width where both are valid;
  - cyclical analysis time values.
- **Identity/audit only, not model features**: raw Bid/Ask, raw pivot prices, source OHLC, raw SL/TP, run/config/signal/window IDs, tickets, absolute account balance, and raw volume.
- **Future/execution only, not model features**: route decision, admission block, broker checks, send result, fill, close, costs, slippage, duration, terminal reason, and realized P&L.
- **Primary target**: strict broker TP/SL binary target.
- **Split policy**: purged chronological holdout and expanding walk-forward folds group the same `(symbol, Macro timeframe, active Macro bar open)` together across run IDs. The validation boundary is the minimum broker trigger time in the fold; a training row is eligible only when its broker close time is strictly earlier than that boundary, so an outcome unavailable at prediction time cannot enter training. Analysis time never orders causal splits. The builder fails closed on mixed configuration IDs, lot modes, reference balances, or account currencies unless a future plan explicitly defines a cross-config study.
- **Ablation order**: base level/direction/time -> add normalized widths -> add Micro `%B` -> add Macro pivot `%B`. XGBoost receives continuous values; human reports may display quantile/range bins without replacing the underlying values.

## Named Resources

- **Project instructions and planning**:
  - `AGENTS.md`
  - `README.md`
  - `docs/plans/README.md`
  - `/home/loldlm/.codex/skills/planner/references/execution-state.md` for the later implementation handoff
- **Entrypoint and include aggregators**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_tools.mqh`
  - `services/trading_management.mqh`
  - `services/trading_signals.mqh`
  - `services/frontend.mqh`
- **MQL5 configuration and market data**:
  - `services/core/enums.mqh`
  - `services/core/base_structures.mqh`
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_management/pivot_fractal_engine_config.mqh`
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/indicators/pivot_points_calculator.mqh`
  - `services/trading_signals/pivot_context_features.mqh`
  - `services/trading_signals/pivot_fractal_engine_state.mqh`
  - `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **MQL5 execution, lifecycle, and persistence**:
  - `services/trading_signals/pivot_signal_struct.mqh`
  - `services/trading_signals/pivot_signal_state.mqh`
  - `services/trading_signals/execution_lot_math.mqh`
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
  - `services/trading_signals/pivot_signal_lifecycle.mqh`
  - `services/trading_signals/pivot_fractal_statistics_export.mqh`
  - `services/trading_signals/execution_logging.mqh`
  - `services/trading_signals/market_status_controller.mqh`
  - `services/frontend/execution_visualization.mqh`
- **Expected active source deletions after references are removed**:
  - `indicators/Stochastic_Structure.mq5`
  - `services/indicators/extrema_detector.mqh`
  - `services/indicators/stochastic_market_indicator.mqh`
  - `services/indicators/structure_classifier.mqh`
  - `tools/deterministic_signal_ml/retest_confluence.py`
  - `tools/deterministic_signal_ml/query_confluence.py`
- **Historical tracked fixture retained but inactive for V10 acceptance**:
  - `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/`
- **Python schema, dataset, audit, and model tooling**:
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/pivot_fractal_audit.py`
  - `tools/deterministic_signal_ml/report_writer.py`
  - `tools/deterministic_signal_ml/feature_encoder.py`
  - `tools/deterministic_signal_ml/model_config.py`
  - `tools/deterministic_signal_ml/validation_splits.py`
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/README.md`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_audit.py`
  - New fixture directory `tools/deterministic_signal_ml/tests/fixtures/schema_v10_macro_micro_pivot/`
- **Active documentation**:
  - `AGENTS.md`
  - `README.md`
  - `docs/architecture/market-data-broker-executor.md`
  - `docs/workflows/pivot-fractal-statistics-flow.md`
  - `docs/workflows/pivot-fractal-offline-research-boundaries.md`
  - `docs/environment/mt5-agentic-workflows.md`
  - `docs/addons/README.md`
  - `docs/addons/base.md`
  - `docs/product_copy/en/README.md`
  - `docs/product_copy/en/base-ea.md`
  - `docs/product_copy/es/README.md`
  - `docs/product_copy/es/base-ea.md`
  - `docs/research/README.md`
  - `docs/plans/README.md`
  - Preserve or archive, but do not rewrite as current evidence: `docs/research/pivot-fractal-v9-vps-run-audit-2026-07-29.md`
- **Validation and operational resources**:
  - `tools/mt5/compile_mt5.py`
  - `HFT_Grid_AI.ex5`
  - `logs/compile/agentic-build.log`
  - MT5 Common Files V10 run directory
  - Demo/Strategy Tester account using retail hedging and USD, with actual deposit recorded separately from the internal `1,000,000` reference balance
  - Real-tick Strategy Tester data for the selected symbol and period
- **Current official documentation**:
  - MQL5 timeframe constants, including `PERIOD_M3`: https://www.mql5.com/en/docs/constants/chartconstants/enum_timeframes
  - MQL5 applied prices and `PRICE_WEIGHTED`: https://www.mql5.com/en/docs/constants/indicatorconstants/prices
  - MQL5 `iBands` signature and buffer numbers: https://www.mql5.com/en/docs/indicators/ibands
  - MQL5 `CopyBuffer` shift semantics: https://www.mql5.com/en/docs/series/copybuffer
  - MQL5 `SymbolInfoTick`: https://www.mql5.com/en/docs/marketinformation/symbolinfotick
  - MQL5 `OrderCalcProfit`: https://www.mql5.com/en/docs/trading/ordercalcprofit
  - MQL5 `OrderCheck`: https://www.mql5.com/en/docs/trading/ordercheck
  - MQL5 account properties and margin modes: https://www.mql5.com/en/docs/constants/environment_state/accountinformation
  - MQL5 deal profit, commission, swap, fee, entry, and reason properties: https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties
  - MetaTrader 5 Strategy Tester and tick modes: https://www.metatrader5.com/en/terminal/help/algotrading/testing

## Prerequisites

- Start implementation with no unrelated worktree changes. If this plan is still untracked, it is the only permitted handoff file and Sprint 1 must add it; if it was committed separately, record that commit as the replacement execution baseline.
- Before editing implementation files, read `/home/loldlm/.codex/skills/planner/references/execution-state.md`, initialize active-plan state, and update it after every validation, commit, blocker, sprint advance, and completion transition.
- Record baseline tracked `.mq5`/`.mqh` file count, total MQL5 lines, current `.ex5` timestamp/size, active Python test count, and current V9 external artifact location without copying full data into the repository.
- Confirm no open V1 position exists for the target symbol before any executable handoff. Do not adopt, close, or modify an old-magic position with V2.
- Use demo or Strategy Tester only. This plan does not authorize live execution.
- Confirm the final acceptance account is `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`, uses USD for dollar-denominated evidence, and records the tester initial deposit separately from the internal fixed reference balance.
- Confirm enough Macro and Micro history exists for Bands period `21` plus shifts `0..5` before accepting a feature-complete run.
- Preserve the tracked V9 fixture, external V9 run folders, generated DuckDB/Parquet datasets, audits, models, and archived plans/research. V10 uses new paths and IDs.
- Keep the pinned Python dependencies. Do not add packages for feature importance, plotting, or schema handling.
- Intermediate MQL5 sprints use static review only. Sprint 7 owns the first and final real MetaEditor compile unless the human explicitly changes this plan.

## Sprint 1: Freeze Strict Schema V10 And Fixture

**Goal**: Establish a testable six-file schema V10 contract before the MQL5 writer is changed.
**Dependencies**: Clean baseline and prerequisites.
**Tracked scope**: This plan file if still untracked, `tools/deterministic_signal_ml/schema_contract.py`, `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`, fixture directories, and `docs/plans/README.md` to register the active plan.
**Commit**: `feat: define strict macro micro pivot schema v10`
**Demo/Validation**:

- `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_pivot_fractal_schema.py'`
- `rtk grep "SUPPORTED_SCHEMA_VERSION|SUPPORTED_ENGINE_LABEL|RUN_FILES|CONTEXT_TIMEFRAMES|TRAILING_EVENTS_FILE" tools/deterministic_signal_ml`
- `rtk git diff --check`
- Expected: strict V10 fixture passes; the preserved V9 fixture is rejected as V10 and is not adapted; trailing tables, six-context rules, and V9 compatibility paths have no active schema-contract ownership.

**Rollback point**: Record the pre-sprint commit. Reverting the single Sprint 1 commit restores the strict V9 Python schema without changing external V9 runs.

### Task 1.1: Define Exact Six-File Headers And Manifest

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Replace active schema/engine/feature constants and exact table columns with the six-file V10 contract. Freeze manifest values for Macro/Micro timeframes, weighted Bands, virtual-limit triggers, PP arming, quote-based 1R, fixed reference balance, binary cohort, and offline-only approval.
- **Dependencies**: None.
- **Acceptance criteria**:
  - Active tooling accepts only schema `10`, `PIVOT_FRACTAL_V2`, and `schema_v10_macro_micro_pivot_bands`.
  - `RUN_FILES` contains exactly six names.
  - No trailing or context-row table remains.
  - Window and attempt headers contain the fixed fields needed by the runtime and research contracts.
- **Validation**:
  - `rg -n "SUPPORTED_SCHEMA_VERSION|SUPPORTED_ENGINE_LABEL|SUPPORTED_FEATURE_SET_ID|RUN_FILES|TABLE_COLUMNS" tools/deterministic_signal_ml/schema_contract.py`
  - `rg -n "trailing_events|structure_[0-2]|context_timeframe|schema_version = 9|PIVOT_FRACTAL_V1" tools/deterministic_signal_ml/schema_contract.py`
- **Rollback**: Revert Task 1.1 changes before creating the sprint commit if header review finds an unresolved semantic.

### Task 1.2: Implement V10 Referential And Semantic Validation

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Validate wide ordered pivot levels, one Macro window, unique consumed identities, PP role/arming coherence, support-buy/resistance-sell direction, structural SL matrix, exact price-distance 1R geometry where a request exists, risk-budget utilization, execution-chain ownership, uniform adverse-positive slippage, cost arithmetic, binary eligibility, exclusion reasons, row counts, and natural/censored completion.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - Orphan, duplicate, mixed-direction, malformed PP, invalid route, invalid cost sum, invalid binary label, and count mismatch fixtures fail closed with focused errors.
  - Mixed-reason or nonbinary outcomes are valid raw facts but cannot carry a binary target.
  - A valid run may contain censored or nonbinary attempts while reporting their exclusion counts.
- **Validation**:
  - `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_pivot_fractal_schema.py'`
- **Rollback**: Restore the prior validator functions and fixture expectations together; never leave columns and validation on different versions.

### Task 1.3: Add The V10 Fixture And Retire V9 From Active Acceptance

- **Location**: `tools/deterministic_signal_ml/tests/fixtures/schema_v10_macro_micro_pivot/`, `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/`, `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`
- **Description**: Add one compact V10 fixture containing at least one support buy TP, one resistance sell SL, one PP role, one excluded nonbinary or mixed-reason close, one denied attempt, exact price-distance 1R, quote expectations, budget utilization, and decomposed costs. Preserve the V9 fixture unchanged as historical/negative evidence; do not adapt or relabel it.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance criteria**:
  - The V10 fixture contains exactly six TSV files with exact headers.
  - The V9 fixture remains byte-for-byte historical and is never accepted as V10.
  - Positive counts and arithmetic are deterministic.
  - Targeted mutations cover every new fail-closed boundary without adding another Python test module.
- **Validation**:
  - `find tools/deterministic_signal_ml/tests/fixtures/schema_v10_macro_micro_pivot -maxdepth 1 -type f -printf '%f\n' | sort`
  - `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_pivot_fractal_schema.py'`
- **Rollback**: Revert the V10 fixture and test changes with the schema contract; the preserved V9 fixture is not rewritten.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Targeted schema tests pass and evidence is recorded.
- [ ] Exact six-file headers and fixed manifest values are reviewed.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] The Sprint 1 rollback point is recorded.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Simplify Dataset, Audit, And XGBoost Research

**Goal**: Produce a one-row trigger-time matrix and strict TP/SL binary cohort without Stoch, confluence, trailing, admission targets, or scale-dependent ML prices.
**Dependencies**: Sprint 1 gate.
**Tracked scope**: `tools/deterministic_signal_ml/` Python modules, tests, and README.
**Commit**: `feat: simplify pivot band research pipeline`
**Demo/Validation**:

- `rtk test .venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Build the V10 fixture with `--validate-only`, then a temporary ignored dataset and audit.
- `rtk grep "retest|confluence|admission|trailing|structure_" tools/deterministic_signal_ml --glob '*.py' --glob '*.md'`
- `rtk git diff --check`
- Expected: full Python suite passes; active research output contains only V10 tables, the wide research matrix, binary cohort, compact audit, and offline model artifacts.

**Rollback point**: Record the Sprint 1 commit. Reverting Sprint 2 restores the older research pipeline while the V10 contract remains available for diagnosis.

### Task 2.1: Build Typed V10 Tables And Wide Research Matrix

- **Location**: `tools/deterministic_signal_ml/build_dataset.py`, `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Load exactly six V10 files, type them, join window context to attempts, derive normalized trigger gap/spread/range features, and emit `research_matrix.parquet` plus `binary_outcomes.parquet`.
- **Dependencies**: Sprint 1.
- **Acceptance criteria**:
  - One research row exists per complete consumed attempt.
  - The binary table contains only feature-complete, fully closed rows with one consistent confirmed TP or SL reason across all owned closing volume.
  - Mixed config ID, Macro/Micro timeframes, lot mode, reference balance, or account currency fails closed.
  - Absolute price and future-only columns are absent from the model feature list but retained in typed audit tables.
- **Validation**:
  - `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root tools/deterministic_signal_ml/tests/fixtures --run-id schema_v10_macro_micro_pivot --validate-only`
  - A temporary ignored dataset build followed by compact DuckDB row/column inspection.
- **Rollback**: Revert builder and schema feature-column changes together.

### Task 2.2: Remove Active Retest, Confluence, Admission, And Trailing Research

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`, `tools/deterministic_signal_ml/query_confluence.py`, `tools/deterministic_signal_ml/pivot_fractal_audit.py`, `tools/deterministic_signal_ml/report_writer.py`, `tools/deterministic_signal_ml/model_config.py`, tests.
- **Description**: Delete active confluence modules and remove their imports, derived tables, CLI options, reports, grouping, tests, and model feature sets. Remove admission as a model target while retaining denied/unfilled counts in integrity reporting.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - No active code imports deleted modules.
  - Audit reports separate data integrity/operations from strict binary performance.
  - No trailing, milestone, structure, retest, pair, or confluence section remains in current reports.
- **Validation**:
  - `rg -n "retest_confluence|query_confluence|CONFLUENCE|target-family admission|trailing_events|highest_milestone|structure_" tools/deterministic_signal_ml --glob '*.py' --glob '*.md'`
  - Full Python unit suite.
- **Rollback**: Restore both deleted modules and every import/caller in one revert.

### Task 2.3: Freeze Minimal Continuous Model Features And Splits

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`, `tools/deterministic_signal_ml/feature_encoder.py`, `tools/deterministic_signal_ml/validation_splits.py`, `tools/deterministic_signal_ml/model_config.py`, `tools/deterministic_signal_ml/train_model.py`
- **Description**: Encode only the approved categorical and normalized continuous trigger-time features. Group duplicate Macro windows across run IDs, purge training outcomes that close on or after each validation boundary, and add deterministic base/width/Micro-%B/Macro-%B ablation reporting using existing dependencies and fixed seeds.
- **Dependencies**: Tasks 2.1-2.2.
- **Acceptance criteria**:
  - Random row splitting is impossible.
  - Every row from the same symbol/Macro window stays in one partition across duplicate runs.
  - No training row has a broker close time on or after the minimum broker trigger time in its validation fold.
  - Human bins are report-only; XGBoost receives continuous values.
  - Training artifacts remain `OFFLINE_RESEARCH_ONLY` and emit no runtime model.
- **Validation**:
  - `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_pivot_fractal_research_contract.py'`
  - A fixture training smoke may intentionally stop at the documented minimum-row guard; the guard result must be deterministic.
- **Rollback**: Revert feature columns, split group IDs, and model config as one unit.

### Task 2.4: Rewrite The Current Tooling README And Tests

- **Location**: `tools/deterministic_signal_ml/README.md`, all three existing Python test modules.
- **Description**: Document V10 validate/build/audit/train commands, six files, binary cohort, feature semantics, ablations, exclusions, and no-runtime boundary. Update existing tests rather than adding modules.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance criteria**:
  - Commands match actual CLI arguments and output names.
  - Tests cover future-column exclusion, duplicate-window grouping, close-time purging, cost arithmetic, continuous features, and deterministic reports.
- **Validation**:
  - Full Python compile and unit suite.
  - `rg -n "V9|PIVOT_FRACTAL_V1|Stoch|confluence|trailing" tools/deterministic_signal_ml/README.md tools/deterministic_signal_ml/tests --glob '*.{py,md}' --glob '!**/fixtures/**'`; any retained match must be an explicit negative compatibility or historical statement, never current V10 guidance.
- **Rollback**: Revert README and tests with the code they describe.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] Full Python compile and unit suite pass.
- [ ] Fixture validate/build/audit evidence is recorded outside tracked artifacts.
- [ ] Feature and future-only column lists receive explicit leakage review.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 2 commit is created with the proposed message.
- [ ] The Sprint 2 rollback point is recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Reduce MQL5 Inputs, Handles, And Window State

**Goal**: Replace the multi-timeframe/Stoch runtime foundation with one Macro window, one Micro Bands context, V2 identity, and fixed weighted Bands resources.
**Dependencies**: Sprint 2 gate and frozen V10 field semantics.
**Tracked scope**: Entrypoint, core enums/structs, management/config/loader, include aggregators, pivot state, and obsolete indicator source deletions.
**Commit**: `refactor: reduce pivot runtime to macro and micro contexts`
**Demo/Validation**:

- Static include trace and exact identifier/reference sweeps only; no MetaEditor compile in this sprint.
- `rg -n "#include|Macro_Timeframe|Micro_Timeframe|PRICE_WEIGHTED|PIVOT_FRACTAL_V2|REFERENCE_BALANCE" HFT_Grid_AI.mq5 services --glob '*.{mq5,mqh}'`
- `rg -n "Stochastic_Structure|ExtStructStoch|PIVOT_CONTEXT_TIMEFRAME_COUNT|PIVOT_FRACTAL_TIMEFRAMES|PIVOT_CONTEXT_TIMEFRAMES" HFT_Grid_AI.mq5 services indicators --glob '*.{mq5,mqh}'`
- `rtk git diff --check`
- Expected: no active Stoch include/handle/source references; one Macro state and exactly two Bands handles are owned and released deterministically.

**Rollback point**: Record the Sprint 2 commit. Reverting Sprint 3 restores the V1 multi-timeframe runtime foundation without affecting V10 Python work.

### Task 3.1: Replace Public Inputs And Validate Timeframes

- **Location**: `services/trading_management/ea_inputs.mqh`, `services/core/enums.mqh`, `HFT_Grid_AI.mq5`
- **Description**: Add Macro/Micro inputs, rename the lot enum, set recommended defaults, add the fixed reference constant, and fail initialization with `INIT_PARAMETERS_INCORRECT` for invalid, equal, current, unavailable, or nonascending timeframes.
- **Dependencies**: Sprint 2 contract.
- **Acceptance criteria**:
  - Public groups contain only the approved inputs.
  - No compatibility enum alias for live-balance percentage remains.
  - Validation logs one actionable reason and performs no runtime setup after failure.
- **Validation**:
  - `rg -n "^input |enum ExecutionLotTypes|PIVOT_EXECUTION_REFERENCE_BALANCE|PeriodSeconds" services/trading_management/ea_inputs.mqh services/core/enums.mqh HFT_Grid_AI.mq5`
- **Rollback**: Restore input and enum declarations together.

### Task 3.2: Collapse The Engine Configuration And State

- **Location**: `services/trading_management/pivot_fractal_engine_config.mqh`, `services/trading_signals/pivot_fractal_engine_state.mqh`, `services/trading_signals/pivot_signal_state.mqh`
- **Description**: Remove fixed timeframe arrays and make one Macro window the sole pivot owner. Keep seven trigger states plus explicit PP arming state, first causal Bid side, and Macro band cache.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - No loop or array assumes five pivot windows.
  - Reset, retry, expiration, export tracking, and source identity are singleton and deterministic.
  - Macro timeframe remains part of IDs/config even though only one is active.
- **Validation**:
  - `rg -n "PIVOT_FRACTAL_TIMEFRAME_COUNT|g_pivot_fractal_windows|window_index|PivotFractalTimeframeAt" services --glob '*.mqh'`
  - Manual constructor/copy/reset review for every changed struct.
- **Rollback**: Revert state and config files together.

### Task 3.3: Replace Indicator Loading With Two Weighted Bands Handles

- **Location**: `services/trading_management/indicator_definitions_loader.mqh`, `services/core/base_structures.mqh`
- **Description**: Own one Macro and one Micro `iBands` handle, created only when export is enabled, with fixed weighted parameters. Check handle readiness and release both on deinit.
- **Dependencies**: Tasks 3.1-3.2.
- **Acceptance criteria**:
  - No per-tick handle creation.
  - Macro and Micro equality is already rejected, so handle identity is unambiguous.
  - Missing handles make features incomplete without changing execution permission.
- **Validation**:
  - `rg -n "iBands|PRICE_WEIGHTED|IndicatorRelease|INVALID_HANDLE|BarsCalculated" services/trading_management/indicator_definitions_loader.mqh services/trading_signals/pivot_context_features.mqh`
- **Rollback**: Restore loader and feature handle lookup together.

### Task 3.4: Remove The Stoch Structure Source Closure

- **Location**: `services/trading_signals.mqh`, `services/indicators/`, `indicators/Stochastic_Structure.mq5`, related structs/enums.
- **Description**: Remove the standalone custom indicator and the active extrema/structure include closure only after all references are gone.
- **Dependencies**: Task 3.3.
- **Acceptance criteria**:
  - The tracked Stoch source and three supporting service files are deleted.
  - No structure enum, slot count, field, handle, log, or include remains active unless another verified owner exists.
- **Validation**:
  - `rg -n "Stoch|STRUCTURE_|OscillatorStructure|extrema_detector|structure_classifier|stochastic_market_indicator" HFT_Grid_AI.mq5 services indicators --glob '*.{mq5,mqh}'`
  - `rg -n '^#include' HFT_Grid_AI.mq5 services --glob '*.{mq5,mqh}'`
- **Rollback**: Restore deleted files and aggregator includes in the same revert.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] Input, include, handle, constructor/copy/reset, and deinit static reviews pass.
- [ ] Exact Stoch and multi-timeframe identifier sweeps are clean.
- [ ] No MetaEditor syntax or compile command was run.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] The Sprint 3 rollback point is recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Implement Virtual Pivot Triggers And Band Snapshots

**Goal**: Implement the exact live Bid trigger, PP arming, causal weighted feature, batching, and identity semantics.
**Dependencies**: Sprint 3 gate.
**Tracked scope**: Pivot window refresh, context features, signal structs, signal detection, export payload interfaces, and relevant logging.
**Commit**: `feat: implement virtual pivot touch band snapshots`
**Demo/Validation**:

- Static examples and exact logic review only; no MetaEditor compile.
- Review a written truth table for first window tick above/below/equal PP, direct S/R conditions, equality, gaps, and same-tick multi-level batches.
- `rg -n "CopyRates|CopyBuffer|tick.bid|trigger_states|PP|b_percent|band_width" services/trading_signals services/trading_management --glob '*.mqh'`
- `rtk git diff --check`
- Expected: no M1 side context remains; trigger semantics depend on live Bid and PP arming only; same-tick Micro snapshots are shared and Macro `%B` is pivot-specific.

**Rollback point**: Record the Sprint 3 commit. Reverting Sprint 4 restores the reduced runtime foundation without enabling the new trigger path.

### Task 4.1: Cache The Causal Macro Window And Source Bands

- **Location**: `services/trading_signals/pivot_fractal_engine_state.mqh`, `services/indicators/pivot_points_calculator.mqh`, `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **Description**: Retain broker-native active-bar lifecycle and shift-1 source loading for the configured Macro timeframe. Cache the valid pivot ladder and Macro shift-1 base/upper/lower/raw width/normalized width at window birth or bounded retry.
- **Dependencies**: Sprint 3.
- **Acceptance criteria**:
  - A future-visible active bar cannot replace the current causal window.
  - Macro source and band shift `1` refer to the same completed candle boundary.
  - Invalid source, collapsed ladder, unavailable bands, and zero band width have explicit independent reasons.
- **Validation**:
  - Static trace from `iTime(..., 0)` through `CopyRates(..., 1, 1)` and Macro `CopyBuffer(..., 1, ...)`.
  - Verify no synthetic time arithmetic creates candles.
- **Rollback**: Revert window cache and exporter payload changes together.

### Task 4.2: Arm PP From The First Causal Window Bid

- **Location**: `services/trading_signals/pivot_fractal_engine_state.mqh`, `services/trading_signals/pivot_fractal_signal_detection.mqh`, `services/trading_signals/pivot_signal_struct.mqh`
- **Description**: Record PP as unarmed, buy-armed, or sell-armed. Above arms a return buy, below arms a return sell, and equality waits for a strict departure before arming the return side.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - PP never triggers merely because every price is mathematically `<=` or `>=` it.
  - PP role never flips after arming within the same window.
  - PP arming time/side/direction are exportable and causal.
- **Validation**:
  - Static truth table covering first Bid `>`, `<`, and `== PP`, departure, return, gap, and expiration.
- **Rollback**: Revert PP enum/state/detection/export fields together.

### Task 4.3: Implement Direct Support And Resistance Virtual Limits

- **Location**: `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **Description**: Remove previous-close side logic. Trigger support buys on live Bid `<=` level and resistance sells on live Bid `>=` level. Consume identities before route or broker evaluation and order same-tick batches along the approved central-to-extreme path.
- **Dependencies**: Tasks 4.1-4.2.
- **Acceptance criteria**:
  - Ask never authorizes a buy trigger.
  - Exact touches and gap-throughs count.
  - Already marketable S/R levels may trigger on the first causal window tick.
  - Each identity is consumed once, including denial/failure paths.
- **Validation**:
  - `rg -n "previous_m1|PERIOD_M1|ResolvePivotTouchDirection|PivotM1Side" services --glob '*.mqh'`
  - Manual candidate ordering examples for single touch and gaps through 2-4 levels.
- **Rollback**: Revert detection and removed M1 context together.

### Task 4.4: Capture Micro Market And Macro Pivot Band Features

- **Location**: `services/trading_signals/pivot_context_features.mqh`, `services/trading_signals/pivot_signal_struct.mqh`, `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **Description**: Capture Micro bands `0..5` and Macro bands `0..5` once per observed tick batch. Compute Micro shift-0 `%B` from trigger Bid, Micro completed shifts from matching weighted H/L/C, and each candidate's Macro `%B` from its immutable pivot price. Record raw/normalized widths and explicit completeness reasons.
- **Dependencies**: Tasks 4.1-4.3.
- **Acceptance criteria**:
  - Same-tick candidates share byte-equivalent Micro facts and Macro envelopes.
  - Macro pivot `%B` differs only because the candidate pivot price differs.
  - No `%B` value is clipped.
  - Shift-0 facts use only data visible at the observed real tick.
- **Validation**:
  - Formula review against the official applied-price and `CopyBuffer` contracts.
  - `rg -n "CopyClose|PRICE_CLOSE|structure_|PIVOT_B_PERCENT_SHIFT_COUNT" services --glob '*.mqh'`
- **Rollback**: Revert feature structs/capture/export interfaces as a unit.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Trigger and PP truth tables are reviewed and recorded.
- [ ] Causality, batching, array bounds, handle readiness, and formula static reviews pass.
- [ ] Exact M1, Stoch, and old direction-helper sweeps are clean.
- [ ] No MetaEditor syntax or compile command was run.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 4 commit is created with the proposed message.
- [ ] The Sprint 4 rollback point is recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Implement Fresh Quote 1R And Reference-Risk Sizing

**Goal**: Replace pivot-terminal routes and live-balance sizing with one structural SL, one fresh quote-based 1R TP, and a fixed reference risk budget.
**Dependencies**: Sprint 4 gate.
**Tracked scope**: Route/execution structs, lot math, broker checks, controller, logging, and manifest payload fields.
**Commit**: `feat: add quote based one r pivot execution`
**Demo/Validation**:

- Static review of all eight route rows and both lot modes; no MetaEditor compile.
- `rg -n "BuildPivotSignalRoute|initial_stop_loss|terminal_take_profit|OrderCalcProfit|REFERENCE_BALANCE|ACCOUNT_BALANCE|milestone" services/trading_signals services/trading_management --glob '*.mqh'`
- `rtk git diff --check`
- Expected: all allowed routes have directionally valid fresh quote SL/TP geometry; percentage mode never reads live balance for its risk target.

**Rollback point**: Record the Sprint 4 commit. Reverting Sprint 5 restores trigger/data collection work while removing the new execution behavior.

### Task 5.1: Replace The Route Matrix With Structural SL Only

- **Location**: `services/trading_signals/pivot_signal_struct.mqh`
- **Description**: Delete milestones and terminal pivot targets. Map PP/S/R entries to the approved adjacent or synthetic structural SL, retaining the immutable touched pivot as research intent rather than the broker request price.
- **Dependencies**: Sprint 4.
- **Acceptance criteria**:
  - Exactly eight direction/level route rows are allowed.
  - No `NO_FORWARD_LEVEL` path remains.
  - Buy stops are strictly below fresh Ask and sell stops strictly above fresh Bid before send.
- **Validation**:
  - Static route table comparison against this plan.
  - `rg -n "PivotRouteMilestone|milestone_count|NO_FORWARD_LEVEL" services --glob '*.mqh'`
- **Rollback**: Restore route structs and builder together.

### Task 5.2: Calculate Fresh 1R Geometry At Observation And Pre-Send

- **Location**: `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/pivot_signal_struct.mqh`
- **Description**: Compute provisional observation geometry from the trigger tick, then recompute authoritative entry, SL, risk distance, and TP from a fresh pre-send tick. Re-run all geometry, stops, freeze, and `OrderCheck` safeguards on the final values.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - Buy TP equals fresh Ask plus fresh Ask-to-SL distance.
  - Sell TP equals fresh Bid minus SL-to-fresh Bid distance.
  - The sent request uses exactly the authoritative pre-send geometry.
  - Pivot prices are never moved to force broker acceptance.
- **Validation**:
  - Static examples for normal touch, spread, favorable gap, adverse gap, invalid stop side, and stops/freeze denial.
- **Rollback**: Revert controller and check payload changes together.

### Task 5.3: Implement Fixed Reference-Balance Percentage Sizing

- **Location**: `services/trading_signals/execution_lot_math.mqh`, `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/pivot_signal_struct.mqh`
- **Description**: Replace `ACCOUNT_BALANCE` risk targeting with `1,000,000 * Lot_Strategy_Size / 100`. Calculate exact normalized price-distance 1R, per-lot stop loss from the fresh entry/SL, normalize volume down, calculate quote expected SL and TP money, budget utilization, and both budget-relative and executed-risk-relative R bases. Preserve fixed-lot behavior as a separate config.
- **Dependencies**: Task 5.2.
- **Acceptance criteria**:
  - Default percentage risk budget is `100` account-currency units.
  - Live balance never changes that budget.
  - Submitted reward and risk price distances are equal after normalization.
  - Normalized volume cannot silently exceed the budget.
  - Quote expected profit/loss, monetary ratio, and budget utilization are exported even when expected money is not exactly symmetric or does not consume the full budget.
- **Validation**:
  - `rg -n "AccountInfoDouble\(ACCOUNT_BALANCE\)|risk_target_amount_out|OrderCalcProfit|NormalizeExecutionVolumeDown" services/trading_signals/execution_lot_math.mqh`
  - Manual calculations for at least two stop distances and one below-minimum volume.
- **Rollback**: Restore enum, input default, lot math, and manifest semantics together if the mode is reverted.

### Task 5.4: Preserve Broker Safety And Stable V2 Ownership

- **Location**: `HFT_Grid_AI.mq5`, `services/trading_signals/execution_controller.mqh`, `services/trading_signals/execution_broker_context.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/market_status_controller.mqh`
- **Description**: Change the stable magic namespace to V2 and preserve session, symbol mode, hedging, permissions, Bid/Ask, point, stops/freeze, volume, margin, `OrderCheck`, retcode, comment, symbol/magic/ticket, and startup-ownership fail-closed behavior.
- **Dependencies**: Tasks 5.1-5.3.
- **Acceptance criteria**:
  - V1 and V2 magic scopes cannot collide.
  - Observation facts remain telemetry; only fresh pre-send facts authorize.
  - Non-hedging accounts collect attempts but never send.
- **Validation**:
  - Static safety-boundary trace from candidate to `OrderSend` and reconciliation.
  - Exact `OrderSend` call count and request-field review.
- **Rollback**: Revert the complete V2 execution ownership slice; do not reuse V1 magic with V2 positions.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] All eight routes and fresh Bid/Ask formulas pass static review.
- [ ] Reference-risk, fixed-lot, volume-floor, and quote expectation calculations are reviewed.
- [ ] Broker safety and ownership checks remain fail closed.
- [ ] No MetaEditor syntax or compile command was run.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 5 commit is created with the proposed message.
- [ ] The Sprint 5 rollback point is recorded.
- [ ] Sprint 6 has not started before this gate completes.

## Sprint 6: Remove Trailing And Write Broker Outcomes To V10

**Goal**: Finish the MQL5 cutover by removing all trailing behavior, simplifying lifecycle reconciliation, decomposing outcomes, and writing exactly six V10 files.
**Dependencies**: Sprint 5 gate and Sprint 1 headers.
**Tracked scope**: Lifecycle, reconciliation, signal structs/state, exporter, controller/logging, frontend, and any remaining MQL5 references.
**Commit**: `refactor: remove pivot trailing and export v10 outcomes`
**Demo/Validation**:

- Static lifecycle, exporter-column, buffer/flush, and deinit review only; no MetaEditor compile.
- Compare every MQL5 header string column count with the Sprint 1 Python tuple.
- `rg -n "trailing|milestone|TRADE_ACTION_SLTP|PIVOT_V9|PivotFractalV9|schema_version.*9|structure_" HFT_Grid_AI.mq5 services --glob '*.{mq5,mqh}'`
- `rtk git diff --check`
- Expected: no SL/TP modification path remains; exactly six V10 files are created/flushed/summarized; broker outcome money reconciles to cost components.

**Rollback point**: Record the Sprint 5 commit. Reverting Sprint 6 restores the pre-export integration state; never run it against V10 evidence until Sprint 6 is complete.

### Task 6.1: Delete Trailing State And Modification Logic

- **Location**: `services/trading_signals/pivot_signal_struct.mqh`, `services/trading_signals/pivot_signal_lifecycle.mqh`, `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/pivot_signal_state.mqh`
- **Description**: Remove pending stops, milestones, retries, SLTP requests, trailing ownership events, highest-milestone inference, and all related constructors/copy/reset fields. Retain startup ownership, entry reconciliation, close reconciliation, terminal export, and cleanup.
- **Dependencies**: Sprint 5.
- **Acceptance criteria**:
  - Active positions are only reconciled; they are never modified.
  - The lifecycle performs bounded ticket-first reconciliation and terminal removal.
  - No dead trailing enum, constant, log token, or field remains.
- **Validation**:
  - `rg -n "trailing|milestone|pending_stop|TRADE_ACTION_SLTP|highest_milestone" HFT_Grid_AI.mq5 services --glob '*.{mq5,mqh}'`
  - Constructor/copy/reset and deinit review.
- **Rollback**: Restore all removed trailing state/functions together; partial restoration is unsafe.

### Task 6.2: Decompose Broker Outcome Costs And Slippage

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`, `services/trading_signals/pivot_signal_struct.mqh`, `services/trading_signals/pivot_signal_lifecycle.mqh`
- **Description**: Sum owned deal profit, commission, swap, and fee separately; calculate net profit; derive adverse-positive direction-aware entry/exit slippage; classify consistent whole-position broker TP/SL versus mixed/excluded reasons; and calculate gross/net R against both the fixed budget and executable quote risk.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - `net_profit == gross_profit + commission + swap + fee` within tolerance.
  - Entry slippage is positive when the fill is worse than the submitted request.
  - Exit slippage is positive when the close is worse than the broker-confirmed terminal price.
  - Only fully closed positions with one consistent TP or SL reason across all owned closing volume receive binary values.
  - Partial/multiple close deals remain volume-weighted and ticket/identifier scoped.
  - Budget-relative and executable-risk-relative R values remain distinct and arithmetically reproducible.
- **Validation**:
  - Static examples for buy/sell TP, buy/sell SL, commission, swap, fee, manual close, stop-out, and multiple close deals.
  - Exact deal-property reference review against official documentation.
- **Rollback**: Revert outcome fields, calculations, exporter columns, and Python fixture semantics together.

### Task 6.3: Replace The V9 Writer With Exact V10 Six-File Persistence

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh`, `services/trading_signals/execution_controller.mqh`, `services/trading_signals/pivot_fractal_signal_detection.mqh`, `services/trading_signals/pivot_signal_lifecycle.mqh`
- **Description**: Replace constants, payloads, headers, IDs, manifest, paths, buffers, file creation, row builders, summary counters, integrity checks, and deinit behavior with the frozen Sprint 1 contract.
- **Dependencies**: Tasks 6.1-6.2 and Sprint 1.
- **Acceptance criteria**:
  - Runtime owns exactly six TSV filenames.
  - Existing run folders fail closed and are never appended.
  - Header and row column counts match Python exactly.
  - Feature incompleteness cannot authorize/deny execution.
  - Summary reports binary eligible, excluded, censored, duplicate, referential, and row integrity counts.
- **Validation**:
  - Scripted or manual side-by-side header token count with Python `TABLE_COLUMNS`.
  - `rg -n "PIVOT_V9|PivotFractalV9|trailing_events.tsv|signal_features.tsv|pivot_levels.tsv" services --glob '*.mqh'`
  - File handle, flush, error, and deinit static review.
- **Rollback**: Revert the complete writer and all callers; never dual-write V9/V10.

### Task 6.4: Simplify Logs And Frontend To Immutable SL/TP

- **Location**: `services/trading_signals/execution_logging.mqh`, `services/frontend/execution_visualization.mqh`, related frontend helpers.
- **Description**: Remove trailing/milestone labels and display only intended pivot/request entry context, immutable broker SL, immutable broker TP, direction, Macro timeframe, and level. Keep nonvisual tester work disabled and chart objects bounded.
- **Dependencies**: Tasks 6.1-6.3.
- **Acceptance criteria**:
  - No frontend or log field influences execution.
  - At most 16 active positions are drawn.
  - Deinit removes V2-owned chart objects.
- **Validation**:
  - Static object naming, bounds, cleanup, and nonvisual guard review.
- **Rollback**: Revert frontend/logging only if the retained lifecycle fields still match.

### Sprint 6 Gate

- [ ] All Sprint 6 tasks complete.
- [ ] Trailing and V9 active-source sweeps are clean.
- [ ] V10 MQL5/Python headers and row counts match exactly.
- [ ] Cost, slippage, binary eligibility, file lifecycle, and deinit reviews pass.
- [ ] No MetaEditor syntax or compile command was run.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 6 commit is created with the proposed message.
- [ ] The Sprint 6 rollback point is recorded.
- [ ] Sprint 7 has not started before this gate completes.

## Sprint 7: Integrate Active Documentation And Perform The Final Compile

**Goal**: Make every active source/document describe V2/V10, complete all static gates, run the full Python suite, and produce the sole final real MetaEditor compile with `0 errors, 0 warnings`.
**Dependencies**: Sprint 6 gate.
**Tracked scope**: Active docs/product copy/repository instructions, `HFT_Grid_AI.ex5`, compile evidence path, and any focused compile fixes.
**Commit**: `build: validate macro micro pivot executor v2`
**Demo/Validation**:

- Full active identifier/reference and include sweeps.
- Full Python compile and unit suite.
- Final real MetaEditor compile with parsed `0 errors, 0 warnings` and regenerated `.ex5`.
- `rtk git diff --check`.

**Rollback point**: Record the Sprint 6 commit. Reverting Sprint 7 restores the complete source implementation before documentation/compiled-artifact integration.

### Task 7.1: Rewrite Active Architecture And Operator Documentation

- **Location**: `AGENTS.md`, `README.md`, active architecture/workflow/environment/addon/research docs listed under Named Resources.
- **Description**: Replace V1/V9, five/six timeframe, M1 crossing, Stoch, trailing, confluence, and live-balance language with the exact V2/V10 contract, commands, six files, risk semantics, binary cohort, exclusions, and real-tick tester matrix.
- **Dependencies**: Sprint 6.
- **Acceptance criteria**:
  - Active docs agree on inputs, trigger inequalities, PP arming, route matrix, feature formulas, file names, model boundaries, and rollout restrictions.
  - Environment docs remove the external Stoch `.ex5` requirement.
  - Product copy does not promise exact net `$100` outcomes or call all deviations slippage.
  - Historical V9 evidence, archived plans/research, and the tracked V9 fixture remain unchanged and are clearly indexed as historical rather than current guidance.
- **Validation**:
  - Search only current-contract documents for old positive contract identifiers: `rg -n "PIVOT_FRACTAL_V1|schema V9|Schema V9|PivotFractalV9|Stochastic_Structure|M15,M30,H1,H4,D1|previous M1|EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT|trailing_events.tsv|retest_confluence|query_confluence" AGENTS.md README.md docs/architecture/market-data-broker-executor.md docs/workflows/pivot-fractal-statistics-flow.md docs/workflows/pivot-fractal-offline-research-boundaries.md docs/environment/mt5-agentic-workflows.md docs/addons/README.md docs/addons/base.md docs/product_copy/en/README.md docs/product_copy/en/base-ea.md docs/product_copy/es/README.md docs/product_copy/es/base-ea.md`; any match must describe an explicitly removed behavior, not the active contract.
  - Review index wording separately: `rg -n "Active|Archived|Historical|V9|PIVOT_FRACTAL_V1" docs/plans/README.md docs/research/README.md`.
  - Confirm historical material is untouched from the recorded baseline: `git diff --exit-code 0a47ce2df99f804667f8110c2c8788f4fb89f297 -- docs/plans/archive docs/research/archive docs/research/pivot-fractal-v9-vps-run-audit-2026-07-29.md tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal`; replace the hash if the prerequisite records a newer execution baseline.
- **Rollback**: Revert active docs as one coherent set; do not leave mixed version guidance.

### Task 7.2: Run Final Static Integration Gates

- **Location**: Entire tracked active source and tooling.
- **Description**: Trace include order, identifiers, array bounds, constructors/copy/reset, handle/file cleanup, broker safety, magic/ticket ownership, exporter headers, Python feature leakage, and deleted-source references.
- **Dependencies**: Task 7.1.
- **Acceptance criteria**:
  - Aggregator order remains `trading_tools`, `trading_management`, `trading_signals`, `frontend`.
  - No sibling re-includes or cycles are introduced.
  - No old engine/schema/feature/trailing identifier remains active.
  - `git diff --check` passes.
- **Validation**:
  - `rg -n '^#include' HFT_Grid_AI.mq5 services --glob '*.{mq5,mqh}'`
  - `rg -n "PIVOT_FRACTAL_V1|PIVOT_V9|PivotFractalV9|Stoch|structure_|trailing|milestone|PERIOD_M1|ACCOUNT_BALANCE_PERCENT|retest|confluence" HFT_Grid_AI.mq5 services tools/deterministic_signal_ml --glob '*.{mq5,mqh,py}'`
  - `rtk git diff --check`
- **Rollback**: Fix focused integration defects before compile; if the design contract changes, return to the owning sprint instead of patching around it.

### Task 7.3: Run Full Python Validation

- **Location**: `tools/deterministic_signal_ml/` and ignored temporary artifacts.
- **Description**: Run compileall, all unit tests, strict V10 fixture validation, dataset build, audit, and a deterministic training guard/smoke.
- **Dependencies**: Task 7.2.
- **Acceptance criteria**:
  - All existing Python test modules pass.
  - V10 fixture validate/build/audit outputs have expected counts and no integrity errors.
  - No generated artifact is accidentally tracked.
- **Validation**:
  - `rtk test .venv/bin/python -m compileall -q tools/deterministic_signal_ml`
  - `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
  - V10 validate/build/audit commands documented in the updated README.
- **Rollback**: Return failures to Sprint 1 or Sprint 2 ownership before compiling MQL5.

### Task 7.4: Perform The Sole Final MetaEditor Compile

- **Location**: `HFT_Grid_AI.mq5`, `HFT_Grid_AI.ex5`, `tools/mt5/compile_mt5.py`, `logs/compile/agentic-build.log`
- **Description**: Record the precompile `.ex5` metadata, run one real compile, parse the final compiler result, and record regenerated artifact metadata. `/s` syntax mode is not accepted.
- **Dependencies**: Tasks 7.1-7.3.
- **Acceptance criteria**:
  - Compiler reports exactly `0 errors, 0 warnings`.
  - `HFT_Grid_AI.ex5` is regenerated and its timestamp/size/change are recorded.
  - Any compile fix receives focused static and Python reruns before the final result is accepted.
- **Validation**:
  - `python3 tools/mt5/compile_mt5.py --wine --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" --log "logs/compile/agentic-build.log" --mode compile`
- **Rollback**: If compile cannot pass without a design change, do not commit Sprint 7; return to the owning sprint. Never hide warnings or restore a stale `.ex5` as evidence.

### Sprint 7 Gate

- [ ] All Sprint 7 tasks complete.
- [ ] Active docs and product copy agree with V2/V10.
- [ ] Full static and Python gates pass.
- [ ] Final real compile reports `0 errors, 0 warnings` and regenerates `.ex5`.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 7 commit is created with the proposed message.
- [ ] The Sprint 7 rollback point is recorded.
- [ ] Sprint 8 has not started before this gate completes.

## Sprint 8: Human Real-Tick Acceptance And Closeout

**Goal**: Validate causal runtime behavior, broker lifecycle, V10 evidence, research usability, and performance in human Strategy Tester/chart workflows, then archive the completed plan and evidence.
**Dependencies**: Sprint 7 gate and no source changes after the accepted compile.
**Tracked scope**: Acceptance evidence, plan/archive indexes, and closeout documentation only.
**Commit**: `docs: close out macro micro pivot v2 acceptance`
**Demo/Validation**:

- Human Strategy Tester using `Every tick based on real ticks`.
- Natural V10 run validation, dataset build, audit, and offline training smoke.
- Paired export-disabled/export-enabled cost measurement.
- Visual and nonvisual chart inspection.

**Rollback point**: Record the Sprint 7 commit. Reverting Sprint 8 removes only closeout documentation; it does not modify runtime code or external evidence.

### Task 8.1: Validate Timeframes, Windows, And Causality

- **Location**: Human Strategy Tester and V10 run files.
- **Description**: Verify H1/M3 defaults, invalid input rejection, actual Macro bar transitions, shift-1 source ownership, weekend/session gaps, handle warmup/retry, and no future-visible shift-0 feature values.
- **Dependencies**: Sprint 7.
- **Acceptance criteria**:
  - Macro window changes only on causal broker H1 transitions in the default case.
  - M3 features are developing only through the observed real tick.
  - No synthetic or incomplete source candle creates pivots.
- **Validation**:
  - Compare selected chart/Data Window values and compact exported rows at known broker timestamps.
- **Rollback**: Any source defect returns execution to the owning sprint and invalidates the Sprint 7 compile gate.

### Task 8.2: Validate Trigger, PP, Identity, And Batch Semantics

- **Location**: Human real-tick Strategy Tester, optional visual chart, V10 attempts.
- **Description**: Exercise exact support/resistance touches, already-marketable window-start levels, PP start above/below/equal, return touch, gap-through multiple levels, one identity, denial consumption, and stable candidate ordering.
- **Dependencies**: Task 8.1.
- **Acceptance criteria**:
  - S levels trigger buys from live Bid only; R levels trigger sells from live Bid only.
  - Buy fill uses Ask; sell fill uses Bid.
  - PP does not fire immediately unless its armed return condition is actually met.
  - Same-tick gap batches follow the approved path order and consume each identity once.
- **Validation**:
  - Cross-check attempt IDs, times, directions, trigger prices, and send sequence against chart/tick evidence.
- **Rollback**: Return trigger defects to Sprint 4.

### Task 8.3: Validate Bands And Research Features

- **Location**: Tester/Data Window, V10 window/attempt files, Python validator.
- **Description**: Verify weighted Bands formula, buffer mapping, Macro shift-1 cached width, Micro shift-0 current width, Micro `%B 0..5`, Macro pivot `%B 0..5`, unclipped values, same-tick shared context, and feature-incomplete behavior.
- **Dependencies**: Task 8.2.
- **Acceptance criteria**:
  - Sample formulas reproduce within numeric tolerance.
  - Same-tick Micro facts match across candidates; Macro pivot `%B` changes with pivot price only.
  - Missing features invalidate research completeness without changing an otherwise valid broker decision.
- **Validation**:
  - Strict V10 validator and focused manual formula spreadsheet/calculation for selected rows.
- **Rollback**: Return feature defects to Sprint 3 or Sprint 4.

### Task 8.4: Validate All Routes, Risk, And Broker Safety

- **Location**: Human Strategy Tester and execution checks.
- **Description**: Observe or statically/visually confirm PP buy/sell, S1/S2/S3 buys, R1/R2/R3 sells, synthetic extreme stops, fresh 1R TP, fixed reference risk, fixed lots, volume floor, margin, stops/freeze, `OrderCheck`, unsupported margin mode, session, permission, and send failures.
- **Dependencies**: Task 8.3.
- **Acceptance criteria**:
  - Every sent order has immutable broker SL/TP and no later SLTP request.
  - Default reference mode requests a `100` account-currency risk budget independent of current balance.
  - Exact normalized price-distance 1R, quote expected loss/profit, budget utilization, and volume normalization are auditable.
  - Every broker safety denial fails closed and remains exported.
- **Validation**:
  - Route/check matrix with at least one observed PP, inner support, inner resistance, and extreme route; remaining rows receive exact static geometry review if market coverage is unavailable.
- **Rollback**: Return route/lot defects to Sprint 5 and lifecycle defects to Sprint 6.

### Task 8.5: Validate Outcomes, Slippage, Binary Cohort, And Research Flow

- **Location**: V10 run, built datasets, audit, model smoke, acceptance evidence.
- **Description**: Reconcile TP, SL, manual/mixed/other/censored examples; verify cost sums, adverse-positive direction-aware slippage, budget and executable R, strict binary inclusion, excluded-reason counts, chronological grouping, human filters, and XGBoost continuous features/ablations.
- **Dependencies**: Task 8.4.
- **Acceptance criteria**:
  - Only feature-complete, fully closed, consistent TP/SL rows enter `binary_outcomes.parquet` and performance/model reports.
  - Raw integrity tables still count every attempt and terminal/exclusion state.
  - The primary binary cohort is not filtered using realized P&L or slippage; those are outcome diagnostics and filtering them would introduce selection bias.
  - `$130` or `-$150` examples can be decomposed into quote expectation, budget utilization, fill/close slippage, and cost components rather than assigned a generic volatility label.
  - The audit can group by trigger time, level, direction, normalized Micro volatility, Micro `%B`, and Macro pivot `%B` without combinatorial pattern generation.
- **Validation**:
  - V10 validate/build/audit/train commands complete or stop only at documented minimum-support guards.
  - Inspect compact counts and selected rows, not full TSV/Parquet dumps.
- **Rollback**: Return schema/research defects to Sprint 1 or Sprint 2; return outcome defects to Sprint 6.

### Task 8.6: Measure Performance, Visuals, And Close Out

- **Location**: Human tester/chart, ignored evidence artifacts, `docs/research/archive/`, `docs/plans/archive/`, `docs/plans/README.md`, `docs/research/README.md`.
- **Description**: Compare export disabled/enabled over the same 1-3 market days with logs off, inspect nonvisual/visual behavior, record elapsed time/rows/folder bytes, write acceptance evidence, record all sprint commit hashes/rollback points, and archive the completed plan without rewriting historical V9 evidence.
- **Dependencies**: Tasks 8.1-8.5.
- **Acceptance criteria**:
  - Nonvisual tester runs create no chart work.
  - Visual mode shows bounded immutable entry/SL/TP lines.
  - Accepted run has `completion_status=NATURAL`, strict V10 integrity success, and documented binary/excluded/censored counts.
  - The plan archive README records all eight sprint commits and rollback points.
  - Live rollout remains explicitly unauthorized.
- **Validation**:
  - Compact artifact inventory, validation status, performance comparison, and final `git diff --check`.
- **Rollback**: Revert only the Sprint 8 closeout commit; external tester evidence remains preserved outside tracked source unless intentionally archived.

### Sprint 8 Gate

- [ ] All Sprint 8 tasks complete.
- [ ] Human real-tick tester and chart acceptance is recorded.
- [ ] Strict V10 natural-run validation and research flow pass.
- [ ] Performance and visual/nonvisual evidence is recorded.
- [ ] No source changed after the accepted Sprint 7 compile; otherwise Sprint 7 was repeated before closeout.
- [ ] Exactly one Sprint 8 commit is created with the proposed message.
- [ ] The Sprint 8 rollback point and every prior sprint rollback point are recorded.
- [ ] Plan and evidence are archived and indexed.

## Testing Strategy

- **Python unit/contract**:
  - Maintain the existing three test modules.
  - Cover exact headers, fixed manifest values, six files, wide levels, PP arming, direction/route rules, feature completeness, cost arithmetic, binary eligibility, exclusions, mixed-config rejection, leakage exclusion, chronological grouped splits, deterministic audit output, and model guards.
- **MQL5 static integration**:
  - Per sprint: exact identifier/reference sweeps, include tracing, constructor/copy/reset review, array/buffer bounds, market-data failure handling, broker safety trace, file/handle cleanup, and `git diff --check`.
  - Do not add MQL5 test infrastructure.
- **MQL5 compile**:
  - One final real MetaEditor compile in Sprint 7.
  - Required result: `0 errors, 0 warnings` with regenerated `HFT_Grid_AI.ex5`.
- **End-to-end/manual**:
  - Human `Every tick based on real ticks` Strategy Tester validation is mandatory.
  - Cover causal windows, direct Bid virtual limits, PP arming, exact/gap touches, all route families, broker checks, immutable SL/TP, outcomes, DST/time export, chart bounds, and export overhead.
- **Security and trading safety**:
  - Preserve hedging requirement, stable V2 magic, symbol/ticket scoping, permissions, actual session/mode, stops/freeze, normalized volume, free margin, `OrderCheck`, fail-closed send handling, and startup old-position block.
- **Performance**:
  - Two cached handles only when export is enabled.
  - No per-tick handle creation, full-history scans, unbounded arrays/logging, repeated close reads, or chart work in nonvisual tests.
  - Compare paired export-off/on runs and record runtime, row count, and bytes.
- **Data migration**:
  - No migration. V10 writes to a new root and strict active tooling rejects V9.
  - Historical V9 runs require their historical repository revision.
- **Operational**:
  - Record account currency, margin mode, broker/session mode, symbol, config ID, reference balance, tester model, dates, and completion status for accepted evidence.
  - Do not call a run accepted if feature or referential integrity fails.

## Safe Parallel Work

- Cross-sprint implementation is not parallel: each sprint must validate, commit once, and record its rollback point before the next starts.
- Within Sprint 1, fixture mutation cases may be drafted after exact headers are frozen, but validator and fixture ownership must be integrated before the sprint gate.
- Within Sprint 2, audit/report and model feature work may proceed after `research_matrix.parquet` columns are frozen; no worker may independently change schema columns.
- MQL5 Sprints 3-6 should have one integration owner because shared structs, include order, exporter payloads, and broker state create high merge-conflict and safety risk.
- Documentation review may be prepared while Sprint 7 static checks run, but no document is finalized before source identifiers and commands are stable.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| PP inequality would otherwise trigger every window immediately | Systematic unwanted PP trades | Explicit one-time PP arming and return-touch state | Above/below/equal PP tester matrix |
| Direct S/R inequalities trigger already-marketable levels at window start | Gap/window-open batches may send several positions | Treat as explicit virtual-limit behavior, consume once, stable path order, preserve broker checks | First-tick and gap-through acceptance rows |
| Shift-0 Bands can be noncausal in reduced tester modes | Leaked volatility features | Require real-tick acceptance and observed-tick timestamp checks | Manual Data Window/export comparison |
| Weighted Bands and trigger Bid use different numerators at shift 0 | Misinterpreted `%B` | Name Micro trigger `%B` explicitly; document weighted history and pivot projection semantics | Formula tests and manifest values |
| Macro pivot `%B` values can be outside 0-100 | Incorrect clipping destroys signal | Never clamp; validate finite only | Fixture values below 0 and above 100 |
| Fresh quote moves far beyond the pivot | Wider risk, smaller volume, or invalid geometry | Recompute SL/TP/volume on fresh quote and fail closed | Gap and stops/freeze tester cases |
| Expected `+100/-100` differs before fill | Misclassified as slippage | Store exact price 1R, quote expected money, and budget utilization separately | Execution-check fields and audit wording |
| Realized money differs due volume, fill, commission, swap, fee | Ambiguous news/cost research | Decompose adverse-positive slippage and costs; retain budget and executable R | Outcome arithmetic validation |
| Slippage is assumed to be caused by news without external event data | False causal conclusion | Treat slippage as measured execution outcome; study correlation with trigger time and pre-trigger Micro volatility only | Audit labels never claim an unobserved news cause |
| Fixed reference percent name is confused with live balance | Operator assumes compounding | Rename enum, fixed constant, manifest and docs | Input/manifest/reference sweeps |
| Account currency is not USD | `$100` claim becomes false | Record currency, say account-currency units, reject mixed-currency datasets | Manifest and builder validation |
| Broker minimum volume exceeds risk budget | Silent risk increase | Normalize down and block below minimum | Lot math fixture/manual case |
| Multiple same-tick sends compete for free margin | Later candidates differ by order | Fixed path ordering and fresh checks before every send | Gap batch execution sequence |
| No trailing means full initial risk remains until TP/SL | Larger giveback than V1 | Explicit binary strategy decision; mandatory broker protection | No SLTP requests and immutable broker fields |
| Nonbinary outcomes are deleted rather than excluded | Survivorship and operational blindness | Keep all raw integrity facts; exclude only from binary cohort | Summary exclusion counts reconcile |
| Simplified features overfit small subgroups | Misleading XGBoost patterns | Continuous features, minimum support, grouped chronology, ablations | Holdout/walk-forward and support reports |
| Duplicate historical runs leak across folds | Inflated validation metrics | Group symbol/Macro window across run IDs | Split contract tests |
| A training position closes after validation begins | Outcome information was unavailable at prediction time | Purge rows by broker close time at every holdout/walk-forward boundary | Split tests assert every retained training close precedes validation |
| V9 and V10 are mixed | Corrupt schema/research semantics | New root, strict version, no adapter/dual writer | Validator fails mixed/old runs |
| Old V1 position remains open | V2 cannot safely own it | New magic and flat-before-handoff restriction | Startup ownership and deployment checklist |
| Intermediate sprints are not compiled | Integration defect found late | Strong static gates and one planned final compile; return defects to owner sprint | Sprint 7 compile result |

## Rollback Plan

- Record the exact pre-sprint commit before every sprint and the single sprint commit after its gate.
- Revert only whole sprint commits in reverse order. Do not partially restore schema, structs, exporter columns, route logic, or magic ownership.
- Sprint 1 rollback restores active V9 Python schema/fixture; external V9 runs remain untouched throughout.
- Sprint 2 rollback restores the old research tooling while keeping the strict V10 contract available for diagnosis.
- Sprint 3 rollback restores multi-timeframe/Stoch runtime resources; any external compiled Stoch indicator is not deleted by this plan.
- Sprint 4 rollback removes the direct trigger and new band feature behavior while retaining the reduced foundation.
- Sprint 5 rollback removes V2 execution behavior; do not attach a partially reverted build to positions created by another magic namespace.
- Sprint 6 rollback removes V10 writer/lifecycle completion. Delete no external V10 evidence automatically; quarantine incomplete run folders instead.
- Sprint 7 rollback restores precompile docs/artifact state. A prior `.ex5` may be redeployed only under the old version's flat-position and compatibility rules.
- Sprint 8 rollback removes closeout documentation only.
- No data backfill or destructive migration is required because V10 uses a new Common Files root.
- If a human tester defect requires source changes after Sprint 7, stop Sprint 8, return to the owning sprint, repeat all later gates, and produce a new final compile before acceptance.

## Execution Order

1. Read the planner execution-state reference and initialize active-plan state.
2. Implement Sprint 1 only.
3. Run and record all Sprint 1 validation.
4. Create exactly one Sprint 1 commit and record its rollback point.
5. Start Sprint 2 only after the Sprint 1 gate passes.
6. Repeat the validate-one-commit-record-rollback gate for every sprint.
7. Do not compile MQL5 during Sprints 1-6.
8. Run the first and final real MetaEditor compile only in Sprint 7.
9. Begin human Sprint 8 only from the accepted Sprint 7 compile with no later source changes.
10. Do not authorize live rollout from plan completion or tester acceptance.

## Completion Checklist

- [ ] Public inputs expose only the approved Macro/Micro, execution, export, and debug settings.
- [ ] One Macro shift-1 pivot window and two weighted Bands handles replace the old multi-timeframe/Stoch system.
- [ ] Live Bid S/R triggers, PP arming, gap ordering, and consumed identity semantics match this plan.
- [ ] Micro and Macro pivot `%B` plus normalized bandwidth features are causal, complete, and unclipped.
- [ ] All eight structural SL routes and fresh quote 1R targets match the matrix.
- [ ] Reference percentage sizing uses fixed `1,000,000`, and default risk budget is 100 account-currency units.
- [ ] Trailing and SLTP modification behavior are absent.
- [ ] V10 writes exactly six strict files under a new root.
- [ ] Outcomes decompose exact price 1R, quote expectations, budget utilization, adverse-positive slippage, costs, net P&L, and both R bases.
- [ ] Only broker TP/SL rows enter binary performance/model cohorts; every exclusion remains auditable.
- [ ] Active retest/confluence/admission/trailing research code is removed.
- [ ] XGBoost uses continuous normalized trigger-time features and purged, leakage-safe grouped chronology.
- [ ] Existing Python tests pass without adding new test modules or dependencies.
- [ ] Final MetaEditor compile reports `0 errors, 0 warnings` and regenerates `.ex5`.
- [ ] Human real-tick Strategy Tester/chart acceptance passes.
- [ ] Every sprint has exactly one sprint-specific commit and a recorded rollback point.
- [ ] Active docs, product copy, environment commands, plan index, and research index describe V2/V10 only.
- [ ] Historical V9 plans, evidence, runs, datasets, audits, and models remain preserved.
- [ ] Live rollout remains unauthorized.
