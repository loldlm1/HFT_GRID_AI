# Plan: Pivot SL/TP Re-entry Trial Matrix And Schema V11

**Generated**: 2026-08-07
**Status**: Active implementation; ordered sprint state is hook-managed
**Estimated Complexity**: High
**Risk Class**: Critical - adds a tick-driven counterfactual trade lifecycle, changes the active export schema and research grain, and touches the broker execution boundary even though the real order policy must remain unchanged
**Execution Baseline**: Branch `bot/pivot_points_fractal`, commit `d39839c18d6a51af12ad47705193d92458c19a80`

## Overview

Expand each consumed Macro pivot trigger into a deterministic virtual research
matrix while preserving the current single real broker order. The existing
structural 1R route remains the only FOK market order. When feature export is
enabled, the same trigger also creates sixteen virtual policy chains from four
stop-loss policies and four take-profit multiples:

```text
SL policies: STRUCTURAL, MICRO_BW_13, MICRO_BW_21, MICRO_BW_34
TP multiples: 1R, 2R, 3R, 5R
initial trials per pivot origin: 4 x 4 = 16
```

The three Micro-bandwidth policies may create at most three policy-specific
re-entries after SL-first outcomes. Structural policies never re-enter. A TP
ends only its own `(SL policy, TP multiple)` chain; other TP chains remain
active until they independently reach TP or SL. Therefore one pivot origin can
produce at most `4 + (12 x 4) = 52` virtual trial rows: four one-shot structural
trials plus twelve volatility chains with indices `0..3`.

Virtual trials use the actual causal Bid/Ask tick stream and broker symbol
properties, but they are not broker positions. They provide deterministic
first-touch labels, nominal R, and counterfactual quote-calculated gross P&L.
Only the real structural 1R position owns broker-confirmed fills, costs,
slippage, gross profit, and net profit. A separate broker-parity shadow uses the
real submitted geometry to measure virtual-vs-broker agreement rather than
assuming that virtual money equals broker money.

The active exporter and Python tooling move to strict schema V11 under a new
`PivotFractalV11` root. Active code accepts V11 only; it does not dual-write or
convert V9/V10. Historical plans, research, fixtures, datasets, and generated
artifacts remain preserved as required by the repository. Existing V9/V10
fixtures remain useful as explicit fail-closed rejection evidence.

Target runtime flow:

```text
broker tick
-> reconcile the one real structural 1R broker position lane
-> resolve active virtual trial TP/SL first-touch events from executable quote sides
-> create at most one next re-entry generation per losing chain on that tick
-> refresh the causal Macro pivot window when changed or retry-due
-> discover and consume new PP/S1..S3/R1..R3 pivot origins
-> capture one shared origin feature snapshot for the tick batch
-> execute the unchanged real structural 1R broker route
-> declare the fixed 16-cell virtual origin matrix independently of broker admission
-> append strict V11 origin, trial, outcome, broker, and summary facts
-> build long, wide, chain, calibration, audit, and offline ML artifacts
```

## Scope

- **In scope**:
  - Keep `PIVOT_FRACTAL_V2`, its stable execution magic, current pivot trigger
    identity, and the single real structural 1R FOK broker order unchanged.
  - Apply the virtual matrix to all seven pivot levels, including PP after its
    existing deterministic buy/sell arming.
  - Add fixed internal SL policies `STRUCTURAL`, `MICRO_BW_13`,
    `MICRO_BW_21`, and `MICRO_BW_34`.
  - Add fixed internal TP multiples `1`, `2`, `3`, and `5`.
  - Define Micro volatility as the full raw shift-0 Micro Bands width,
    `upper_0 - lower_0`, frozen at the origin pivot trigger.
  - Measure virtual buy entry at Ask and sell entry at Bid; resolve virtual buy
    exits on Bid and sell exits on Ask.
  - Normalize volatility SL outward to the symbol trade-tick grid, then build
    TP from the normalized risk ticks so every requested integer R multiple is
    exact after normalization.
  - Require every virtual risk distance to exceed origin/re-entry spread plus
    `max(stops level, freeze level)` plus one trade tick.
  - Record invalid matrix cells explicitly without stretching their stops,
    silently omitting them, or allowing them to affect real execution.
  - Give each `(origin, SL policy, TP multiple)` an independent chain. Only an
    SL-first outcome can create that chain's next re-entry.
  - Allow re-entry indices `0..3`; index `0` is the initial entry and indices
    `1..3` are retries.
  - Require inner-level re-entry entry and proposed SL geometry to remain
    strictly inside the next outward pivot boundary by at least one trade tick.
  - Suppress stale or gap-through re-entries when the observed quote has reached
    the next pivot context; let the next pivot origin own the new context.
  - Permit an already-active virtual trial to resolve after its Macro window
    expires, but prohibit new re-entry generations after origin-window expiry.
  - Censor active trials at run termination; never relabel censored or invalid
    rows as losses.
  - Calculate hypothetical per-trial normalized volume, quote expected SL/TP
    money, and virtual exit gross profit with `OrderCalcProfit` when available.
  - Add a broker-parity virtual shadow for accepted real structural 1R requests
    using the exact submitted request geometry and normalized volume.
  - Export paired calibration facts that quantify TP/SL agreement, price/time
    differences, gross P&L differences, and actual broker costs.
  - Replace active schema V10 with strict V11 and build new normalized and
    human-readable offline artifacts.
  - Update strict validation, DuckDB/Parquet assembly, audits, reports,
    leakage-safe splits, and offline XGBoost training for policy-aware trials.
  - Update active architecture, runbooks, product copy, project instructions,
    fixtures, and acceptance evidence.
  - Complete one final real MetaEditor compile and human real-tick Strategy
    Tester acceptance.
- **Out of scope**:
  - Sending the 16-cell matrix or re-entry trials as broker orders.
  - More than one real broker order per consumed pivot identity.
  - Dividing or multiplying real account risk across matrix cells.
  - Martingale sizing, progressive lot sizing, recovery sizing, or compounding
    re-entry risk.
  - Public inputs for SL percentages, TP multiples, re-entry count, state cap,
    Bands parameters, or trial mode.
  - Re-entry for the structural next-pivot SL policy.
  - Synthetic fills at skipped SL/TP prices, synthetic bars, or assumed
    intra-tick paths not present in the observed Bid/Ask stream.
  - Calling virtual commission, swap, fees, slippage, or net profit
    broker-confirmed facts.
  - Using estimated costs or realized virtual/broker outcomes as trigger-time
    model features.
  - Runtime model inference, trial filtering, online learning, or automatic
    policy selection inside MT5.
  - V9/V10 conversion, dual writing, compatibility aliases, or mixing V11 with
    historical runs in one active dataset.
  - Deleting archived plans, research, fixtures, old datasets, or generated
    artifacts.
  - New MQL5 test harnesses, test EAs, scripts, modules, CI, or automated
    Strategy Tester orchestration.
  - Live rollout authorization.
- **Fixed decisions**:
  - Real execution remains `PIVOT_FRACTAL_V2` structural SL plus fresh quote 1R.
  - The stable V2 magic remains unchanged because broker behavior and broker
    ownership remain unchanged.
  - Matrix tracking exists only when `Enable_Signal_Feature_Export=true`.
  - Export disabled means no virtual matrix state, no V11 files, and no Bands
    work beyond the existing real broker path.
  - The public input contract remains exactly the current eight inputs.
  - Matrix SL percentages are fixed decimal ratios `0.13`, `0.21`, and `0.34`.
  - Matrix TP multiples are fixed integers `1`, `2`, `3`, and `5`.
  - Origin Micro bandwidth is the full raw `upper_0 - lower_0`, not half-width,
    deviation, normalized bandwidth, ATR, or a configurable period.
  - Origin bandwidth remains frozen for every retry in the chain. Fresh retry
    features describe the retry market but never resize the chain.
  - Each TP multiple owns its own retry chain. A TP-consumed chain never
    reopens merely because another TP chain later reaches the common SL area.
  - Re-entry cap is three for every volatility policy at every pivot level.
  - At most one re-entry generation may be created per policy chain per tick.
  - Re-entry uses the actual observed executable quote, never the prior stop
    threshold as a synthetic fill.
  - The strict minimum risk rule is:

    ```text
    risk_distance_points >=
      spread_points + max(stops_level_points, freeze_level_points)
      + trade_tick_points
    ```

    This implements the requested strict `>` boundary without double-counting
    stops and freeze.
  - A matrix cell that fails feature, price, tick-size, distance, volume, or
    `OrderCalcProfit` requirements is retained as an explicit ineligible fact.
  - Virtual path outcome values are `TP_FIRST`, `SL_FIRST`, or `CENSORED`.
  - Virtual nominal trial R is `+tp_r_multiple` for TP-first and `-1` for
    SL-first. Censored and ineligible rows have no binary label.
  - Chain nominal R is the sum of closed trial R values. For example,
    `reentry_index=3` with three preceding SLs and a final TP3 has nominal chain
    R `-1 -1 -1 +3 = 0` before costs.
  - Virtual quote gross P&L is counterfactual and clearly prefixed `virtual_`.
    Commission, swap, fee, and net profit remain null for virtual trials.
  - Only broker reconciliation may populate `broker_*` P&L and cost fields.
  - Broker-parity shadows are excluded from the 16-cell matrix, policy support,
    and ML targets.
  - Active schema version is `11`; active feature set is
    `schema_v11_pivot_trial_matrix`.
  - Active Common Files root is `PivotFractalV11\runs\<run_id>\`.
  - Active Python tooling accepts schema V11 only.
  - The fixed internal active virtual-state cap is `2048` current trial or
    parity states per EA instance and is recorded in the manifest.
  - V9/V10 fixtures remain unchanged and are tested as unsupported historical
    inputs.
  - Virtual and broker outcomes never share one ambiguous target column or one
    combined performance cohort.
- **Assumptions**:
  - Strategy Tester and live collection receive causal Bid/Ask ticks adequate
    to establish first-touch order at the granularity the EA observes.
  - The accepted research environment uses `Every tick based on real ticks`.
  - `OrderCalcProfit` is suitable for counterfactual quote gross P&L but cannot
    predict actual future commission, swap, fee, latency, or broker slippage.
  - The single real structural 1R lane provides enough paired samples over time
    to audit virtual-vs-broker differences.
  - One policy chain stores only its current active generation; completed
    generations are exported and removed from hot state.
  - The fixed `2048` active-state cap protects the per-tick path. Capacity
    exhaustion invalidates the research run and stops new virtual declarations
    without changing real broker execution or evicting existing trials.
  - One EA instance continues to run per account and symbol on a hedging
    account, with older-engine positions flat before future runtime handoff.

## Virtual Versus Broker Money Contract

Virtual trials can be trustworthy for price-path questions when they use the
same causal Bid/Ask stream and correct executable sides. They cannot by
themselves reproduce all broker economics. V11 therefore keeps four distinct
lanes:

| Lane | Source | Meaning | Permitted research use |
| --- | --- | --- | --- |
| `virtual_nominal_r` | Exact designed SL/TP thresholds and first-touch result | Policy geometry outcome before broker costs | Primary policy comparison target |
| `virtual_quote_gross_profit` | `OrderCalcProfit` using hypothetical normalized volume, observed entry, and observed virtual exit | Counterfactual gross account-currency result | Gross path audit, never called broker P&L |
| `broker_gross_profit` / costs / net | Owned broker deal history | Actual execution and account result | Broker execution cohort and calibration |
| broker-parity comparison | Exact submitted broker geometry tracked virtually and joined to broker outcome | Empirical simulation error | Trust and drift monitoring only |

The broker-parity shadow starts only after the real request is accepted. It
copies submitted entry, immutable SL, immutable TP, and normalized volume. It
uses the virtual exit-side rules on subsequent ticks and is paired with the
owned broker ticket after close. The calibration report must include:

- eligible paired count and exclusion reasons;
- TP/SL terminal-reason agreement;
- virtual first-crossing versus broker close time;
- submitted, virtual exit, and broker fill/close price differences;
- virtual quote gross versus broker gross difference in money and execution R;
- actual commission, swap, fee, and broker net distributions;
- gap/slippage and manual/mixed/other reason exclusions.

No fixed gross/net equivalence threshold is assumed during planning. Human
acceptance must review the measured distribution. Any unexplained terminal
reason mismatch for a fully closed consistent broker TP/SL pair blocks research
approval until corrected or explicitly excluded by a documented causal rule.

## Matrix And Re-entry Contract

### Initial Matrix

| SL policy | Stop construction | TP policies | Re-entry |
| --- | --- | --- | --- |
| `STRUCTURAL` | Existing next-pivot or extreme synthetic structural stop | `1R`, `2R`, `3R`, `5R` | Never |
| `MICRO_BW_13` | Origin entry plus/minus `origin_micro_band_width_0 * 0.13` | `1R`, `2R`, `3R`, `5R` | Up to 3 |
| `MICRO_BW_21` | Origin entry plus/minus `origin_micro_band_width_0 * 0.21` | `1R`, `2R`, `3R`, `5R` | Up to 3 |
| `MICRO_BW_34` | Origin entry plus/minus `origin_micro_band_width_0 * 0.34` | `1R`, `2R`, `3R`, `5R` | Up to 3 |

For buy trials, entry is Ask, SL is below entry, TP is above entry, and Bid
owns TP/SL first touch. For sell trials, entry is Bid, SL is above entry, TP is
below entry, and Ask owns TP/SL first touch. Each outcome records both the
threshold price and first observed executable exit quote so gaps remain visible.

### Independent TP Chains

Example for `R1 / MICRO_BW_13`:

```text
origin tick opens TP1, TP2, TP3, TP5 chains at reentry=0
-> TP1 threshold touches: TP1 chain completes and never reopens
-> market reverses to common SL area:
   TP2, TP3, TP5 each record SL_FIRST
   only TP2, TP3, TP5 may create their own reentry=1
-> each surviving chain continues independently until TP, cap, boundary,
   origin-window expiry after a loss, state failure, or run-end censoring
```

### Boundary Mapping

| Direction and origin | Next outward pivot boundary |
| --- | --- |
| Buy PP | S1 |
| Buy S1 | S2 |
| Buy S2 | S3 |
| Buy S3 | None; three-retry cap only |
| Sell PP | R1 |
| Sell R1 | R2 |
| Sell R2 | R3 |
| Sell R3 | None; three-retry cap only |

For inner pivots, both the actual re-entry quote and proposed normalized SL
must remain on the origin side of the next pivot with at least one trade tick
of separation. Equality is not allowed. If a gap crosses both the prior SL and
the next pivot context, the losing trial closes at the observed exit quote, no
old-context retry is created, and normal pivot detection owns the next origin.

### Trial State Machine

```text
DECLARED
|-> INELIGIBLE_FEATURE
|-> INELIGIBLE_GEOMETRY
|-> INELIGIBLE_DISTANCE
|-> INELIGIBLE_MONEY_PLAN
`-> ACTIVE
    |-> TP_FIRST -> CHAIN_COMPLETE
    `-> SL_FIRST
        |-> STRUCTURAL -> CHAIN_COMPLETE
        |-> REENTRY_CAP_REACHED -> CHAIN_COMPLETE
        |-> NEXT_PIVOT_BOUNDARY -> CHAIN_COMPLETE
        |-> ORIGIN_WINDOW_EXPIRED -> CHAIN_COMPLETE
        `-> REENTRY_ALLOWED -> next ACTIVE generation on the same tick

ACTIVE at run end -> CENSORED_RUN_END
```

## Identity And Grain

- `window_id`: unchanged `(symbol, Macro timeframe, active bar open)` window
  identity.
- `origin_id`: one consumed pivot identity `(symbol, Macro timeframe, active
  bar open, level)`; direction remains an outcome of PP arming or level role.
- `broker_signal_id`: the real structural 1R attempt linked one-to-one with the
  origin when the current broker path evaluates it.
- `policy_id`: `(origin_id, sl_policy, tp_r_multiple)`.
- `trial_id`: `(policy_id, reentry_index)`.
- `parity_trial_id`: `(broker_signal_id, BROKER_PARITY_SHADOW)`; not a matrix
  policy.
- `research_group_id`: `(symbol, Macro timeframe, active Macro bar open)` across
  runs, preserving the current leakage-safe window grouping.

Identifiers are stable hashes of explicit canonical payloads. No broker ticket,
direction-only alias, result, or future outcome is part of matrix identity.

## Strict Schema V11 Contract

V11 contains exactly eight runtime TSV files:

| File | Grain | Required content |
| --- | --- | --- |
| `run_manifest.tsv` | One key/value manifest | Engine/schema IDs, symbol/timeframes, Bands settings, matrix constants, quote sides, normalization, minimum-distance, re-entry, boundary, capacity, lot, time, outcome-source, calibration, feature, and approval policies |
| `pivot_windows.tsv` | One row per Macro active bar | Existing source candle, seven raw/trade levels, PP arming, cached Macro bands, validity, and terminal facts |
| `signal_origins.tsv` | One row per consumed pivot identity | Trigger Bid/Ask, pivot ladder, origin feature snapshot, frozen Micro width, structural route, real broker-attempt link/status, and origin expiry facts |
| `virtual_trials.tsv` | One row per declared trial generation | Policy/trial IDs, role, retry index, entry Bid/Ask and features, frozen width, requested/normalized geometry, broker-distance facts, hypothetical volume/money plan, eligibility, and chain continuation facts |
| `virtual_outcomes.tsv` | One row per active virtual trial terminal event | TP/SL/censor time, threshold and observed exit quote, gap points, nominal R, quote gross P&L/R, first-touch reason, duration, and terminal consistency |
| `execution_checks.tsv` | Ordered rows for the one real broker lane | Existing observation, pre-send, send, ownership, and terminal broker checks linked to `origin_id` and `broker_signal_id` |
| `broker_outcomes.tsv` | One row per broker-confirmed closed real position | Existing request/fill/close, immutable protection, slippage, costs, gross/net P&L, R, close classification, and parity-trial link |
| `run_summary.tsv` | One terminal row | Window/origin/trial/outcome/broker/calibration counts, ineligibility/censoring/chain terminal counts, state peak/cap status, integrity, export, and completion status |

Raw runtime files remain normalized and append-only. The offline builder creates
simple research artifacts:

- `origin_matrix_long.parquet`: one joined row per declared matrix trial,
  including ineligible and censored facts.
- `initial_matrix_wide.parquet`: one row per origin with the initial sixteen
  policy cells presented for human and agent comparison; outcome columns are
  clearly namespaced and this table is never used directly as model input.
- `eligible_virtual_trials.parquet`: feature-complete, geometry-valid TP/SL
  virtual rows with an explicit virtual target.
- `policy_chains.parquet`: one row per policy chain with attempts, losses before
  success, final status, closed nominal R, virtual gross R, and censoring.
- `broker_outcomes.parquet`: strict real broker facts only.
- `broker_virtual_calibration.parquet`: paired parity-shadow and broker facts.
- typed Parquet copies of all eight TSV files.

The builder rejects mixed schema, feature set, matrix constants, distance
policy, re-entry cap, capacity policy, timeframe, lot mode/size, reference
balance, account currency, or quote-side policy.

## Research And ML Contract

- **Primary virtual target**: `1` for feature-complete eligible `TP_FIRST`, `0`
  for feature-complete eligible `SL_FIRST`; ineligible and censored rows remain
  null and auditable.
- **Broker target**: remains the separate strict broker TP/SL cohort and is not
  merged with the virtual target.
- **Policy features known at entry**: `sl_policy`, `tp_r_multiple`,
  `reentry_index`, origin level/direction/time, frozen width, current entry
  Micro/Macro features, normalized trigger/retry gap, and normalized spread.
- **Origin versus retry features**: origin features remain immutable. Each retry
  captures a fresh entry-time feature snapshot, while stop distance continues
  to use the frozen origin bandwidth.
- **Future-only facts**: outcome, retry continuation, terminal reason, duration,
  virtual gross result, parity result, broker checks, fills, costs, and P&L.
- **Grouping**: all rows from the same Macro window remain in one chronological
  partition across duplicate runs. Analysis time never orders causal splits.
- **Origin balancing**: within each training fold, total sample weight per
  `origin_id` is normalized so origins with more retries do not manufacture
  disproportionate statistical support.
- **Support reporting**: audits report both unique-origin support and trial-row
  support. A 52-row chain family is never described as 52 independent market
  origins.
- **Policy evaluation**: report TP rate, expected nominal R
  `p(TP) * tp_r_multiple - (1 - p(TP))`, virtual gross R, chain R, censoring,
  and calibration separately. Win rate alone is insufficient.
- **Multiple comparisons**: policy leaderboards require holdout support and
  uncertainty reporting; exploratory best-cell selection is not deployment
  approval.
- **Training boundary**: the initial trainer remains offline classification of
  trial TP-first probability. Chain-level regression or runtime policy
  selection requires a future explicit plan.

## Named Resources

- **Project instructions and planning**:
  - `AGENTS.md`
  - `README.md`
  - `docs/plans/README.md`
  - `pivot-sl-tp-reentry-matrix-plan.md`
  - `/home/loldlm/.codex/skills/planner/references/execution-state.md` for the
    later implementation handoff only
- **Active architecture and workflows**:
  - `docs/architecture/market-data-broker-executor.md`
  - `docs/workflows/pivot-fractal-statistics-flow.md`
  - `docs/workflows/pivot-fractal-offline-research-boundaries.md`
  - `docs/environment/mt5-agentic-workflows.md`
  - `docs/product_copy/en/base-ea.md`
  - `docs/product_copy/es/base-ea.md`
- **Entrypoint and include chain**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_tools.mqh`
  - `services/trading_management.mqh`
  - `services/trading_signals.mqh`
  - `services/frontend.mqh`
- **Existing MQL5 configuration, features, trigger, and execution**:
  - `services/core/enums.mqh`
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_management/pivot_fractal_engine_config.mqh`
  - `services/trading_signals/pivot_context_features.mqh`
  - `services/trading_signals/pivot_fractal_engine_state.mqh`
  - `services/trading_signals/pivot_fractal_signal_detection.mqh`
  - `services/trading_signals/pivot_signal_struct.mqh`
  - `services/trading_signals/pivot_signal_state.mqh`
  - `services/trading_signals/execution_lot_math.mqh`
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_broker_reconciliation.mqh`
  - `services/trading_signals/pivot_signal_lifecycle.mqh`
  - `services/trading_signals/pivot_fractal_statistics_export.mqh`
  - `services/frontend/execution_visualization.mqh`
  - `services/utils/broker_constraints_helper.mqh`
- **Planned MQL5 modules**:
  - `services/trading_signals/pivot_trial_matrix_struct.mqh`
  - `services/trading_signals/pivot_trial_matrix_geometry.mqh`
  - `services/trading_signals/pivot_trial_matrix_state.mqh`
  - `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`
- **Python schema and research tooling**:
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/pivot_fractal_audit.py`
  - `tools/deterministic_signal_ml/report_writer.py`
  - `tools/deterministic_signal_ml/model_config.py`
  - `tools/deterministic_signal_ml/feature_encoder.py`
  - `tools/deterministic_signal_ml/validation_splits.py`
  - `tools/deterministic_signal_ml/train_model.py`
  - `tools/deterministic_signal_ml/README.md`
- **Tests and fixtures**:
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_audit.py`
  - `tools/deterministic_signal_ml/tests/fixtures/schema_v11_pivot_trial_matrix/`
  - preserved historical fixtures under
    `tools/deterministic_signal_ml/tests/fixtures/schema_v10_macro_micro_pivot/`
    and `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/`
- **Compile and generated evidence**:
  - `tools/mt5/compile_mt5.py`
  - `logs/compile/agentic-build.log`
  - `PivotFractalV11\runs\<run_id>\` under MT5 Common Files
  - ignored `artifacts/datasets/`, `artifacts/audits/`, and `artifacts/models/`
- **Official MQL5 documentation**:
  - Symbol properties, including stops and freeze levels:
    `https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants`
  - Account margin modes and hedging:
    `https://www.mql5.com/en/docs/constants/environment_state/accountinformation#enum_account_margin_mode`
  - `iBands`:
    `https://www.mql5.com/en/docs/indicators/ibands`
  - `CopyBuffer`:
    `https://www.mql5.com/en/docs/series/copybuffer`
  - `OrderCalcProfit`:
    `https://www.mql5.com/en/docs/trading/ordercalcprofit`
  - `OrderSend`:
    `https://www.mql5.com/en/docs/trading/ordersend`
  - `OnTradeTransaction`:
    `https://www.mql5.com/en/docs/event_handlers/ontradetransaction`
  - Deal properties and reasons:
    `https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties`

## Prerequisites

- Preserve the clean execution baseline
  `d39839c18d6a51af12ad47705193d92458c19a80` as Sprint 1 rollback point.
- During later implementation, read
  `/home/loldlm/.codex/skills/planner/references/execution-state.md`, initialize
  active-plan state before Sprint 1, and update it after every validation,
  commit, blocker, sprint advance, and completion transition.
- Confirm the local `.venv` can run the pinned DuckDB, NumPy, scikit-learn, and
  XGBoost versions before Python sprints.
- Keep the current MetaEditor/Wine and MT5 Common Files paths available for the
  final compile and human real-tick acceptance only.
- Do not run intermediate MetaEditor compilation unless a human explicitly
  changes this plan.
- Do not create MQL5 tests or automated Strategy Tester infrastructure.
- Keep generated V11 runs and artifacts outside Git.

## Sprint 1: Freeze Strict Schema V11 And Fixture Contract

**Goal**: Produce a runnable offline V11 schema validator and deterministic
fixture that defines all table grains, headers, identities, policies, nullability,
and referential-integrity rules before MQL5 emits V11.

**Dependencies**: Execution baseline and accepted decisions in this plan.

**Tracked scope**:
`tools/deterministic_signal_ml/schema_contract.py`,
`tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`,
`tools/deterministic_signal_ml/tests/fixtures/schema_v11_pivot_trial_matrix/`

**Commit**: `feat: define strict pivot trial matrix schema v11`

**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_pivot_fractal_schema.py'`
- Confirm the V11 fixture validates and preserved V9/V10 fixtures fail with an
  explicit unsupported-schema error.
- `git diff --check`

**Rollback point**:
`d39839c18d6a51af12ad47705193d92458c19a80`

### Task 1.1: Define V11 files, columns, manifest, and identities

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Replace the active V10-only contract with active V11-only
  constants for the eight TSV files, exact headers, fixed manifest values,
  table grains, identity columns, policy enums, outcome enums, and allowed nulls.
  Do not add a compatibility dispatch layer.
- **Dependencies**: None.
- **Acceptance criteria**:
  - `SUPPORTED_SCHEMA_VERSION == 11` and the active feature set is exactly
    `schema_v11_pivot_trial_matrix`.
  - V11 requires all eight files and rejects missing, additional, reordered, or
    malformed columns.
  - Fixed manifest values encode matrix percentages, TP multiples, retry cap,
    quote sides, minimum-distance policy, origin-width freeze, capacity policy,
    and separate broker/virtual outcome policies.
  - Identity uniqueness is enforced at window, origin, policy, trial, parity,
    execution-check sequence, and broker position levels.
- **Validation**:
  - Focused unittest assertions for constants, headers, and manifest values.
  - Exact identifier sweep:
    `rg -n 'SUPPORTED_SCHEMA_VERSION|SUPPORTED_FEATURE_SET_ID|RUN_FILES|FIXED_MANIFEST_VALUES' tools/deterministic_signal_ml/schema_contract.py`
- **Rollback**: Revert only the Sprint 1 commit.

### Task 1.2: Validate matrix and chain invariants

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Add fail-closed validation for 16 declared initial cells per
  complete origin, allowed retry indices, no structural retries, one trial per
  policy/index, TP-consumed chain termination, SL-only continuation, boundary
  and expiry terminal statuses, exact integer R geometry, quote-side semantics,
  virtual-vs-broker field separation, and summary reconciliation.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - A valid origin contains exactly four SL policies by four TP multiples at
    `reentry_index=0`, including explicit ineligible cells.
  - Volatility chains cannot skip or duplicate retry indices.
  - A TP-first trial cannot have a later retry in the same policy chain.
  - A retry requires an immediately preceding SL-first outcome and an allowed
    continuation reason.
  - Virtual rows cannot populate broker cost/net fields.
  - Broker rows cannot masquerade as virtual targets.
- **Validation**:
  - Mutation tests for every invariant, including TP-consumed retry rejection,
    retry index gaps, structural retry, mixed outcome sources, duplicate geometry
    identity, and invalid summary counts.
- **Rollback**: Revert only the Sprint 1 commit.

### Task 1.3: Build the deterministic V11 fixture

- **Location**:
  `tools/deterministic_signal_ml/tests/fixtures/schema_v11_pivot_trial_matrix/`,
  `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`
- **Description**: Create a small exact fixture containing at least one valid
  initial 16-cell origin, an ineligible volatility cell, a TP-consumed chain, a
  two-retry SL/SL/TP chain, a boundary-stopped chain, a censored trial, one real
  broker TP/SL outcome, and one parity pair.
- **Dependencies**: Tasks 1.1 and 1.2.
- **Acceptance criteria**:
  - Fixture counts and chain arithmetic are explicit in tests.
  - V9 and V10 fixtures remain byte-for-byte preserved.
  - Active validation rejects V9/V10 without attempting conversion.
- **Validation**:
  - Focused schema unittest.
  - `git diff --exit-code -- tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal tools/deterministic_signal_ml/tests/fixtures/schema_v10_macro_micro_pivot`
- **Rollback**: Remove only the new V11 fixture and revert Sprint 1 changes.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Focused V11 schema tests pass.
- [ ] Preserved V9/V10 fixture diff is empty.
- [ ] `git diff --check` passes.
- [ ] Residual schema questions are recorded rather than deferred silently.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Build Long, Wide, Chain, Calibration, And ML Artifacts

**Goal**: Make the V11 fixture usable by humans, agents, audits, and offline ML
without depending on unfinished MQL5 runtime output.

**Dependencies**: Sprint 1 gate.

**Tracked scope**:
`tools/deterministic_signal_ml/build_dataset.py`,
`tools/deterministic_signal_ml/pivot_fractal_audit.py`,
`tools/deterministic_signal_ml/report_writer.py`,
`tools/deterministic_signal_ml/model_config.py`,
`tools/deterministic_signal_ml/feature_encoder.py`,
`tools/deterministic_signal_ml/validation_splits.py`,
`tools/deterministic_signal_ml/train_model.py`,
`tools/deterministic_signal_ml/tests/`

**Commit**: `feat: build pivot trial matrix research datasets`

**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Build the V11 fixture into a temporary ignored dataset and verify all named
  Parquet outputs and exact row counts.
- Run the audit against the fixture; training may stop at the documented minimum
  support guard rather than fabricating support.
- `git diff --check`

**Rollback point**: Sprint 1 commit SHA.

### Task 2.1: Materialize normalized and human-readable views

- **Location**: `tools/deterministic_signal_ml/build_dataset.py`,
  `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
- **Description**: Replace V10 materialization with typed V11 tables plus
  `origin_matrix_long`, `initial_matrix_wide`, `eligible_virtual_trials`,
  `policy_chains`, `broker_outcomes`, and `broker_virtual_calibration`.
- **Dependencies**: Sprint 1.
- **Acceptance criteria**:
  - Long rows retain every declared cell, including ineligible and censored.
  - Wide rows expose exactly sixteen deterministic initial policy cells with
    clearly namespaced outcome columns and remain human/agent comparison output,
    not the ML training table.
  - Chain rows compute attempts, preceding losses, final retry index, completed
    nominal R, virtual quote gross R, and terminal/censor reason.
  - Calibration joins require explicit parity and broker identifiers.
- **Validation**:
  - DuckDB assertions for grains, joins, counts, and example chain arithmetic.
  - Mutation tests reject orphan outcomes and ambiguous duplicate policy cells.
- **Rollback**: Revert only Sprint 2.

### Task 2.2: Separate virtual and broker audit cohorts

- **Location**: `tools/deterministic_signal_ml/pivot_fractal_audit.py`,
  `tools/deterministic_signal_ml/report_writer.py`,
  `tools/deterministic_signal_ml/tests/test_pivot_fractal_audit.py`
- **Description**: Report origin/trial support, eligibility, censoring, policy
  TP rate, expected nominal R, chain R, virtual gross R, broker performance, and
  parity calibration as distinct sections.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Reports never combine virtual and broker binary targets.
  - Every policy group reports unique origins and row support.
  - Break-even TP rates for 1R/2R/3R/5R are visible as reference facts.
  - Calibration reports terminal agreement and money/time/price deltas with
    exclusions.
  - Low support and multiple-comparison risk are explicit.
- **Validation**:
  - Fixture audit assertions for each section and support count.
- **Rollback**: Revert only Sprint 2.

### Task 2.3: Make training policy-aware and origin-balanced

- **Location**: `tools/deterministic_signal_ml/model_config.py`,
  `tools/deterministic_signal_ml/feature_encoder.py`,
  `tools/deterministic_signal_ml/validation_splits.py`,
  `tools/deterministic_signal_ml/train_model.py`,
  `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
- **Description**: Train only on eligible virtual TP/SL trials, include policy
  descriptors and entry-time retry facts, keep Macro-window chronological
  grouping, purge unavailable outcomes, and normalize total training weight per
  origin.
- **Dependencies**: Tasks 2.1 and 2.2.
- **Acceptance criteria**:
  - Future, broker, calibration, and realized money columns are forbidden from
    features.
  - `reentry_index` and preceding-loss count are allowed only because they are
    known at that retry entry.
  - Rows from one Macro window never cross train/validation boundaries.
  - Per-origin weights sum to one within a fold, within numeric tolerance.
  - Output remains `OFFLINE_RESEARCH_ONLY` with no runtime artifact.
- **Validation**:
  - Split, leakage, feature-set, and sample-weight unit tests.
  - Expected minimum-support training failure on the small fixture.
- **Rollback**: Revert only Sprint 2.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] Full Python unittest discovery passes.
- [ ] Fixture build and audit produce all required V11 artifacts.
- [ ] Training either passes with sufficient synthetic support or fails only at
      the explicit support guard.
- [ ] Leakage and origin-weight assertions pass.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 2 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Add The Virtual Trial Domain And Pure Geometry

**Goal**: Introduce fixed MQL5 policy types, identities, bounded state, and
directionally normalized geometry without connecting them to `OnTick` or
`OrderSend`.

**Dependencies**: Sprint 2 gate.

**Tracked scope**:
`services/core/enums.mqh`,
`services/trading_management/pivot_fractal_engine_config.mqh`,
`services/trading_signals/pivot_trial_matrix_struct.mqh`,
`services/trading_signals/pivot_trial_matrix_geometry.mqh`,
`services/trading_signals/pivot_trial_matrix_state.mqh`,
`services/trading_signals.mqh`

**Commit**: `feat: add deterministic virtual trial matrix domain`

**Demo/Validation**:

- Static identifier/reference sweeps for policy counts, retry cap, state cap,
  quote sides, exact-R geometry, and include order.
- Confirm no `OrderSend`, `OrderCheck`, trade action, position mutation, or new
  public input exists in matrix modules.
- `git diff --check`

**Rollback point**: Sprint 2 commit SHA.

### Task 3.1: Define fixed policy and state types

- **Location**: `services/core/enums.mqh`,
  `services/trading_management/pivot_fractal_engine_config.mqh`,
  `services/trading_signals/pivot_trial_matrix_struct.mqh`
- **Description**: Add enums and structs for SL policy, trial role, eligibility,
  first-touch outcome, chain terminal reason, IDs, origin snapshot, trial entry,
  trial outcome, policy-chain state, and parity link. Use explicit constructors
  and copy methods suitable for MQL5 arrays.
- **Dependencies**: None.
- **Acceptance criteria**:
  - Fixed counts express four SL policies, four TP multiples, retry indices
    `0..3`, sixteen initial cells, and fifty-two maximum trial rows per origin.
  - Structs separate immutable origin facts, current generation state, and
    exported terminal facts.
  - No virtual struct contains mutable broker ownership authority.
- **Validation**:
  - `rg -n 'PIVOT_TRIAL|MICRO_BW|reentry|trial_id|policy_id|parity' services/core services/trading_management services/trading_signals/pivot_trial_matrix_struct.mqh`
- **Rollback**: Revert only Sprint 3.

### Task 3.2: Implement directionally safe tick geometry

- **Location**: `services/trading_signals/pivot_trial_matrix_geometry.mqh`,
  `services/utils/broker_constraints_helper.mqh`
- **Description**: Add pure helpers for executable entry/exit quote sides,
  conversion between price/points/trade ticks, outward stop normalization,
  exact integer-R TP construction, next-pivot boundary lookup, distance
  eligibility, and geometry-equivalence detection.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Buy and sell SL normalization never reduces requested risk.
  - TP is computed from normalized risk ticks and matches 1/2/3/5 exactly.
  - Minimum risk uses spread plus `max(stops, freeze)` plus one trade tick.
  - No helper moves a pivot price or expands a failed policy to pass.
  - Equivalent normalized policies receive an audit equivalence identifier
    without deleting declared rows.
- **Validation**:
  - Static formula review against the official symbol-property contract.
  - Exact sweep for forbidden `stops + freeze` addition.
- **Rollback**: Revert only Sprint 3.

### Task 3.3: Add bounded active-chain storage

- **Location**: `services/trading_signals/pivot_trial_matrix_state.mqh`,
  `services/trading_signals.mqh`
- **Description**: Store only active current generations, remove completed
  chains, track peak state, enforce a fixed internal cap, and expose reset,
  lookup, append, remove, outstanding, and cap-failure helpers. Include modules
  once through the ordered aggregator.
- **Dependencies**: Tasks 3.1 and 3.2.
- **Acceptance criteria**:
  - State is reset deterministically on initialization/deinitialization.
  - Cap exhaustion marks research integrity failure and suppresses new virtual
    declarations without evicting active trials or changing broker execution.
  - The cap is exactly `2048` active trial/parity states and matches the V11
    manifest contract.
  - Lookups use stable IDs and reject duplicates.
  - No include cycle or sibling re-include is introduced.
- **Validation**:
  - `rg -n '^#include' HFT_Grid_AI.mq5 services/*.mqh services/trading_signals/*.mqh`
  - `rg -n 'OrderSend|OrderCheck|TRADE_ACTION|Position' services/trading_signals/pivot_trial_matrix_*.mqh`
  - The second command must show no broker mutation path.
- **Rollback**: Revert only Sprint 3.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] Exact identifier/reference sweeps pass.
- [ ] Include tracing shows one ordered matrix include path and no cycle.
- [ ] Safety review confirms matrix modules cannot send or modify trades.
- [ ] Public input sweep is unchanged.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 3 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Replace The Active Exporter With Strict V11

**Goal**: Make MQL5 emit the exact eight-file V11 contract and remove active
V10 naming, paths, headers, counters, and compatibility behavior.

**Dependencies**: Sprint 3 gate and Sprint 1 schema contract.

**Tracked scope**:
`services/trading_signals/pivot_fractal_statistics_export.mqh`,
`services/trading_signals/pivot_fractal_signal_detection.mqh`,
`services/trading_signals/pivot_signal_struct.mqh`,
`services/trading_signals/execution_controller.mqh`,
`services/trading_signals/pivot_signal_lifecycle.mqh`,
`HFT_Grid_AI.mq5`

**Commit**: `feat: export pivot trial matrix schema v11`

**Demo/Validation**:

- Exact MQL5/Python header column-count parity checks.
- Static references show no active `PivotFractalV10`, `PIVOT_V10`, or
  `schema_v10_macro_micro_pivot_bands` token in MQL5/Python source outside
  preserved fixtures.
- Export path is only `PivotFractalV11`.
- `git diff --check`

**Rollback point**: Sprint 3 commit SHA.

### Task 4.1: Define V11 exporter files, buffers, and manifest

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **Description**: Replace V10 constants and functions with V11-only headers,
  buffers, counters, paths, manifest rows, summary rows, row-count checks, and
  initialization/deinitialization behavior for the eight files.
- **Dependencies**: Sprint 1 and Sprint 3.
- **Acceptance criteria**:
  - Exactly eight TSV files are created under a unique V11 run folder.
  - Existing-folder and malformed-row failures remain fail-closed.
  - Manifest config hashing includes every fixed matrix and calibration policy.
  - Summary includes virtual and broker counts separately plus state peak/cap.
  - No dual writing or V10 compatibility branch remains.
- **Validation**:
  - Static header counts compared with `schema_contract.py` assertions.
  - `rg -n 'V10|PivotFractalV10|schema_v10' HFT_Grid_AI.mq5 services tools/deterministic_signal_ml --glob '*.mq5' --glob '*.mqh' --glob '*.py' --glob '!tests/fixtures/**'`
- **Rollback**: Revert only Sprint 4.

### Task 4.2: Export pivot origins independently of broker admission

- **Location**: `services/trading_signals/pivot_fractal_signal_detection.mqh`,
  `services/trading_signals/pivot_signal_struct.mqh`,
  `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **Description**: Replace one overloaded signal-attempt grain with one
  `signal_origins` row per consumed pivot identity. Keep the real broker signal
  linked but do not let route denial, permission, margin, or send failure erase
  the origin or matrix declaration opportunity.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Origin identity remains exactly one first consumed pivot trigger.
  - Origin feature and frozen-width facts are recorded once.
  - Broker status/link fields are nullable and later reconciled without
    changing origin identity.
  - Missing features remain explicit and never block the real broker route.
- **Validation**:
  - Identity/reference sweep through detection, exporter, and Python schema.
- **Rollback**: Revert only Sprint 4.

### Task 4.3: Rename broker outcome exports without changing execution

- **Location**: `services/trading_signals/execution_controller.mqh`,
  `services/trading_signals/pivot_signal_lifecycle.mqh`,
  `services/trading_signals/pivot_fractal_statistics_export.mqh`,
  `HFT_Grid_AI.mq5`
- **Description**: Route existing real checks and outcomes into
  `execution_checks.tsv` and `broker_outcomes.tsv`, linked to origin IDs. Keep
  all actual request, fill, immutable SL/TP, cost, and reconciliation semantics
  unchanged.
- **Dependencies**: Tasks 4.1 and 4.2.
- **Acceptance criteria**:
  - There remains exactly one real `OrderSend` and one real `OrderCheck` path.
  - FOK, hedging, magic, ticket-first ownership, immutable SL/TP, and no
    `TRADE_ACTION_SLTP` remain intact.
  - Export renaming cannot authorize or deny execution.
- **Validation**:
  - `rg -n 'OrderSend|OrderCheck|ORDER_FILLING_FOK|TRADE_ACTION_SLTP' HFT_Grid_AI.mq5 services`
  - Manual safety-boundary inspection of pre-send freshness and reconciliation.
- **Rollback**: Revert only Sprint 4.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Exact MQL5/Python header parity passes.
- [ ] Active V10 identifier/path sweep is clean outside preserved history.
- [ ] One-send/one-check/FOK/no-SLTP safety sweep passes.
- [ ] Origin identity remains broker-admission independent.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 4 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Track The Initial Sixteen Virtual Trials

**Goal**: On each consumed pivot origin, declare and resolve the fixed 4x4
virtual matrix without re-entry behavior.

**Dependencies**: Sprint 4 gate.

**Tracked scope**:
`services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
`services/trading_signals/pivot_fractal_signal_detection.mqh`,
`services/trading_signals/pivot_context_features.mqh`,
`services/trading_signals/pivot_fractal_statistics_export.mqh`,
`HFT_Grid_AI.mq5`

**Commit**: `feat: track initial pivot sl tp trial matrix`

**Demo/Validation**:

- Static path review proves every origin declares sixteen index-0 rows when
  export is enabled, including explicit ineligible cells.
- Correct Bid/Ask entry and exit-side formulas are present.
- Virtual lifecycle runs before new pivot detection on each tick.
- No virtual code calls `OrderSend` or changes the real route.
- `git diff --check`

**Rollback point**: Sprint 4 commit SHA.

### Task 5.1: Declare the fixed origin matrix

- **Location**: `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
  `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **Description**: After a pivot origin and its shared feature snapshot are
  frozen, enumerate all four SL policies and four TP multiples in deterministic
  order, create stable policy/trial IDs, calculate geometry and hypothetical
  money plans, export every declaration, and store only eligible active trials.
- **Dependencies**: Sprints 3 and 4.
- **Acceptance criteria**:
  - Declaration order is structural 1/2/3/5, BW13 1/2/3/5, BW21 1/2/3/5,
    BW34 1/2/3/5.
  - All sixteen declarations share the same origin tick and frozen origin width.
  - Structural cells can be declared when Micro width is unavailable; volatility
    cells become explicit feature-ineligible facts.
  - Broker denial or send failure does not suppress matrix declaration.
  - Export disabled adds no matrix state.
- **Validation**:
  - Static loop/count/order review and exact constant sweeps.
- **Rollback**: Revert only Sprint 5.

### Task 5.2: Resolve virtual first touch from executable sides

- **Location**: `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
  `HFT_Grid_AI.mq5`
- **Description**: Process existing active trials before new origin discovery.
  Resolve buy trials from Bid and sell trials from Ask, record TP/SL threshold,
  first observed exit quote, gap, duration, nominal R, and virtual quote gross
  P&L, then remove completed one-shot state.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - One observed executable quote cannot produce both TP and SL for valid
    geometry.
  - Gap exits use the observed quote and retain threshold difference.
  - No trial is evaluated for terminal outcome on the same tick it is created.
  - At this sprint, all SL-first volatility trials end without retry; Sprint 6
    will add continuation.
- **Validation**:
  - Static lifecycle-order inspection and quote-side formula sweep.
- **Rollback**: Revert only Sprint 5.

### Task 5.3: Export initial trial and outcome facts

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh`,
  `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`
- **Description**: Append V11 `virtual_trials` and `virtual_outcomes` rows,
  maintain counters, reject duplicate IDs, and censor remaining active trials on
  deinitialization.
- **Dependencies**: Tasks 5.1 and 5.2.
- **Acceptance criteria**:
  - Active, ineligible, TP, SL, and run-end censor counts reconcile.
  - Virtual commission/swap/fee/net columns do not exist or remain strict nulls
    according to the V11 header.
  - Row buffering and flush behavior remain bounded.
- **Validation**:
  - MQL5/Python row/header and enum-token sweep.
- **Rollback**: Revert only Sprint 5.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] Sixteen-cell declaration count/order is exact.
- [ ] Quote-side and no-same-tick-terminal review passes.
- [ ] Virtual rows remain independent of broker admission.
- [ ] No virtual trade mutation path exists.
- [ ] Identifier/reference and include sweeps pass.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 5 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 6 has not started before this gate completes.

## Sprint 6: Add Policy-Specific Re-entry Chains And Boundaries

**Goal**: Continue only losing volatility TP policies through deterministic,
bounded retry indices `1..3` while preventing stale-context and gap-through
entries.

**Dependencies**: Sprint 5 gate.

**Tracked scope**:
`services/trading_signals/pivot_trial_matrix_struct.mqh`,
`services/trading_signals/pivot_trial_matrix_state.mqh`,
`services/trading_signals/pivot_trial_matrix_geometry.mqh`,
`services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
`services/trading_signals/pivot_fractal_signal_detection.mqh`,
`services/trading_signals/pivot_fractal_statistics_export.mqh`

**Commit**: `feat: add bounded pivot trial reentry chains`

**Demo/Validation**:

- Static state-machine review covers TP consumption, SL-only continuation,
  retry cap, next-pivot boundary, origin expiry, one-generation-per-tick, and
  run-end censoring.
- Maximum trial rows per origin is proven as 52.
- `git diff --check`

**Rollback point**: Sprint 5 commit SHA.

### Task 6.1: Continue only the losing TP policy

- **Location**: `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
  `services/trading_signals/pivot_trial_matrix_state.mqh`
- **Description**: On an eligible volatility SL-first outcome, increment only
  that policy chain, preserve its TP multiple, use a fresh executable entry
  quote, retain frozen origin width, and capture fresh entry-time features.
- **Dependencies**: Sprint 5.
- **Acceptance criteria**:
  - TP-first chains are removed permanently.
  - TP1 success cannot reopen when TP2/TP3/TP5 later lose.
  - Retry IDs are contiguous and stable.
  - Fresh retry features never resize the frozen stop distance.
  - A chain creates no more than one new generation on one tick.
- **Validation**:
  - Exact transition and ID-construction review.
- **Rollback**: Revert only Sprint 6.

### Task 6.2: Enforce cap, pivot boundary, gap, and expiry rules

- **Location**: `services/trading_signals/pivot_trial_matrix_geometry.mqh`,
  `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
  `services/trading_signals/pivot_fractal_signal_detection.mqh`
- **Description**: Resolve next outward pivot, require entry and proposed SL to
  stay strictly within the old interval, suppress a retry after context
  gap-through, cap all volatility chains at three retries, and stop new retries
  after the origin Macro window expires.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - Inner buy/sell and PP mappings match the boundary table in this plan.
  - R3/S3 use cap-only behavior.
  - Equality with the next pivot is blocked.
  - An active trial may close after expiry, but an SL after expiry cannot spawn
    another retry.
  - The next pivot trigger remains independently consumable on the same tick.
- **Validation**:
  - Direction-by-level static matrix inspection.
  - Same-tick ordering review: old trial close, retry decision, then new pivot
    discovery.
- **Rollback**: Revert only Sprint 6.

### Task 6.3: Reconcile chain and capacity summaries

- **Location**: `services/trading_signals/pivot_trial_matrix_state.mqh`,
  `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **Description**: Track chain completion reasons, retries created/suppressed,
  active-state peak, capacity failure, and per-reason summary counts. Mark the
  run invalid rather than silently dropping state on capacity exhaustion.
- **Dependencies**: Tasks 6.1 and 6.2.
- **Acceptance criteria**:
  - Maximum possible emitted matrix trials per origin is 52.
  - State cap cannot alter or close a real broker position.
  - Every active chain is either completed or censored at deinit.
  - Summary counts reconcile with trial/outcome tables.
- **Validation**:
  - Static count proof and exporter-counter review.
- **Rollback**: Revert only Sprint 6.

### Sprint 6 Gate

- [ ] All Sprint 6 tasks complete.
- [ ] TP-consumed chain and SL-only retry behavior are exact.
- [ ] Boundary mapping, equality, gap, expiry, and cap review passes.
- [ ] Maximum 52-row-per-origin proof is recorded.
- [ ] Capacity failure is fail-closed for research and inert for real execution.
- [ ] Identifier/reference and safety sweeps pass.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 6 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 7 has not started before this gate completes.

## Sprint 7: Add Broker-Parity Shadows And Money Calibration

**Goal**: Quantify how closely the virtual tick engine represents the one real
broker position without claiming virtual net-profit equivalence.

**Dependencies**: Sprint 6 gate.

**Tracked scope**:
`services/trading_signals/execution_controller.mqh`,
`services/trading_signals/execution_broker_reconciliation.mqh`,
`services/trading_signals/pivot_signal_struct.mqh`,
`services/trading_signals/pivot_trial_matrix_struct.mqh`,
`services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
`services/trading_signals/pivot_fractal_statistics_export.mqh`,
`tools/deterministic_signal_ml/`

**Commit**: `feat: calibrate virtual trials against broker outcomes`

**Demo/Validation**:

- Static review proves parity shadow creation occurs only after an accepted real
  request and uses exact submitted geometry/volume.
- Broker reconciliation remains authoritative and unchanged for actual money.
- Python fixture/tests verify calibration joins and exclusions.
- `git diff --check`

**Rollback point**: Sprint 6 commit SHA.

### Task 7.1: Create the broker-parity shadow

- **Location**: `services/trading_signals/execution_controller.mqh`,
  `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
  `services/trading_signals/pivot_trial_matrix_struct.mqh`
- **Description**: After a real send is accepted, create one non-ML parity
  shadow with the submitted request entry, SL, TP, normalized volume, broker
  signal ID, and independent parity trial ID. Resolve it from subsequent ticks
  with the same virtual first-touch engine.
- **Dependencies**: Sprints 5 and 6.
- **Acceptance criteria**:
  - Denied or failed sends do not create parity shadows.
  - Parity rows are not counted among the sixteen matrix cells or retry chains.
  - Parity geometry exactly copies the accepted request facts and is never
    rebuilt from origin volatility.
  - Parity tracking cannot change or delay `OrderSend`.
- **Validation**:
  - Pre-send/send ordering and exact field-copy static review.
- **Rollback**: Revert only Sprint 7.

### Task 7.2: Preserve actual broker money authority

- **Location**: `services/trading_signals/execution_broker_reconciliation.mqh`,
  `services/trading_signals/pivot_signal_struct.mqh`,
  `services/trading_signals/pivot_fractal_statistics_export.mqh`
- **Description**: Link broker outcomes to parity trials while retaining actual
  broker fill, close, gross profit, commission, swap, fee, net profit, and
  terminal reason as the only broker-confirmed money source.
- **Dependencies**: Task 7.1.
- **Acceptance criteria**:
  - Virtual outcomes contain no broker cost/net values.
  - Broker outcomes retain current deal-history reconciliation and immutable
    protection checks.
  - Manual, mixed, stop-out, expert, other, and censored broker results remain
    excluded from strict TP/SL calibration.
- **Validation**:
  - Ownership and money-source reference sweep.
- **Rollback**: Revert only Sprint 7.

### Task 7.3: Build calibration checks and reports

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`,
  `tools/deterministic_signal_ml/build_dataset.py`,
  `tools/deterministic_signal_ml/pivot_fractal_audit.py`,
  `tools/deterministic_signal_ml/tests/`
- **Description**: Validate parity/broker one-to-one joins and report terminal
  agreement, crossing/close timing, price deltas, virtual gross versus broker
  gross, execution-R deltas, and actual cost distributions.
- **Dependencies**: Tasks 7.1 and 7.2.
- **Acceptance criteria**:
  - Unexplained TP/SL disagreement is an integrity failure, not averaged away.
  - Gap/manual/mixed/other exclusions are explicit.
  - No calibration value enters trigger-time model features.
  - Reports clearly state that virtual gross is counterfactual and virtual net
    is unavailable.
- **Validation**:
  - Full Python tests and fixture calibration assertions.
- **Rollback**: Revert only Sprint 7.

### Sprint 7 Gate

- [ ] All Sprint 7 tasks complete.
- [ ] Parity creation cannot alter send authorization or request geometry.
- [ ] Broker reconciliation remains the sole actual money authority.
- [ ] Calibration joins and exclusions pass Python tests.
- [ ] Virtual and broker naming is unambiguous.
- [ ] One-send/one-check/FOK/no-SLTP safety sweep passes.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 7 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 8 has not started before this gate completes.

## Sprint 8: Integrate Documentation, Tooling, And Static Contracts

**Goal**: Make V11 the sole active documented workflow and complete all static
and Python integration before release-candidate freeze and the Sprint 10 final
compile/acceptance gate.

**Dependencies**: Sprint 7 gate.

**Tracked scope**:
`AGENTS.md`, `README.md`, `docs/`, `tools/deterministic_signal_ml/`, and all
touched MQL5 files

**Commit**: `docs: document pivot trial matrix v11 workflow`

**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- V11 fixture validate/build/audit and expected training support behavior.
- Active documentation/reference sweep is V11-only; V9/V10 references are
  clearly historical.
- Full include, identity, safety, cleanup, and hot-path static review.
- `git diff --check`

**Rollback point**: Sprint 7 commit SHA.

### Task 8.1: Update active architecture and public contracts

- **Location**: `AGENTS.md`, `README.md`,
  `docs/architecture/market-data-broker-executor.md`,
  `docs/workflows/pivot-fractal-statistics-flow.md`,
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`,
  `docs/environment/mt5-agentic-workflows.md`
- **Description**: Document the unchanged one-real-order lane, virtual matrix,
  retry semantics, quote sides, safety formula, eight-file V11 export,
  virtual/broker money separation, calibration workflow, and final human gate.
- **Dependencies**: Sprints 1-7.
- **Acceptance criteria**:
  - Public inputs remain exactly current.
  - Active docs no longer describe V10 as active.
  - Historical V9/V10 documents remain archived and unedited.
  - No text implies virtual P&L is broker-confirmed or authorizes live rollout.
- **Validation**:
  - `rtk grep 'V10|PivotFractalV10|schema_v10' AGENTS.md README.md docs/architecture docs/workflows docs/environment tools/deterministic_signal_ml/README.md`
  - Review every retained result as either removed or explicitly historical.
- **Rollback**: Revert only Sprint 8.

### Task 8.2: Update operator, audit, and product guidance

- **Location**: `tools/deterministic_signal_ml/README.md`,
  `docs/product_copy/en/base-ea.md`, `docs/product_copy/es/base-ea.md`
- **Description**: Add V11 run/build/audit/train commands, explain long/wide/
  chain/calibration outputs, and describe the product as one broker executor plus
  virtual research trials without adding execution claims.
- **Dependencies**: Task 8.1.
- **Acceptance criteria**:
  - Commands use `PivotFractalV11` paths and current artifact names.
  - English and Spanish copy preserve contribution and risk boundaries.
  - No runtime model or live-deployment claim appears.
- **Validation**:
  - Manual command/path and terminology sweep.
- **Rollback**: Revert only Sprint 8.

### Task 8.3: Run full precompile integration review

- **Location**: Entire active source and Python tooling.
- **Description**: Complete exact identifier/reference sweeps, include tracing,
  safety-boundary inspection, state cleanup review, MQL5/Python header parity,
  fixture tests, and dataset/audit smoke before release-candidate freeze.
- **Dependencies**: Tasks 8.1 and 8.2.
- **Acceptance criteria**:
  - Exactly two Bands handles remain, created/released only with export enabled.
  - No per-tick handle creation or full-history scan is introduced.
  - Virtual state is reset and censored on deinit.
  - Frontend continues to display real broker positions only; virtual trials do
    not create chart-object storms.
  - Nonvisual tester remains chart-work free.
  - Python tests and fixture flows pass.
- **Validation**:
  - `rg -n '^#include' HFT_Grid_AI.mq5 services/*.mqh services/trading_signals/*.mqh`
  - `rg -n 'iBands|IndicatorRelease|CopyBuffer|OrderSend|OrderCheck|TRADE_ACTION_SLTP|ObjectCreate' HFT_Grid_AI.mq5 services`
  - `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
  - `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
  - V11 fixture validate/build/audit commands documented in the runbook.
  - `git diff --check`
- **Rollback**: Revert only Sprint 8.

### Sprint 8 Gate

- [ ] All Sprint 8 tasks complete.
- [ ] Active docs and tooling are V11-only.
- [ ] Archived V9/V10 plans, research, and fixtures remain preserved.
- [ ] Full Python compileall/tests/fixture build/audit pass.
- [ ] Include, identity, safety, cleanup, and performance static review passes.
- [ ] No MetaEditor compile has run before this gate unless a human amended the plan.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 8 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 9 has not started before this gate completes.

## Sprint 9: Freeze The Release Candidate And Acceptance Protocol

**Goal**: Complete every non-compiler validation, freeze the exact release
candidate, and prepare reproducible human acceptance evidence without invoking
MetaEditor or Strategy Tester automation.

**Dependencies**: Sprint 8 gate.

**Tracked scope**: Only corrective source/tooling changes required by final
static and Python validation, plus `docs/research/` acceptance preparation and
runbook corrections

**Commit**: `chore: prepare pivot trial matrix v11 acceptance`

**Demo/Validation**:

- Full Python validation and fixture validate/build/audit flows pass.
- Final MQL5 include, identity, quote-side, state, cleanup, and broker-safety
  static reviews pass.
- Precompile `.ex5` timestamp, size, and hash are recorded without compiling.
- Human real-tick, broker, calibration, research, and performance acceptance
  commands/checklists are complete and use no new harness or CI module.

**Rollback point**: Sprint 8 commit SHA.

### Task 9.1: Freeze the release candidate and precompile evidence

- **Location**: Entire active source, `HFT_Grid_AI.ex5`,
  `docs/research/` acceptance preparation.
- **Description**: Resolve final static/Python defects, record the release
  candidate source commit context and current `.ex5` timestamp/size/hash, and
  explicitly confirm that no MetaEditor compile has run.
- **Dependencies**: Sprint 8.
- **Acceptance criteria**:
  - Full Python compileall/tests and fixture flows pass.
  - Exact MQL5/Python header/token parity passes.
  - The source tree contains no unresolved static safety or lifecycle defect.
  - Precompile binary evidence is recorded and remains unchanged in Sprint 9.
- **Validation**:
  - Full Sprint 8 validation set plus binary metadata/hash comparison.
- **Rollback**: Revert only Sprint 9 corrections and preparation evidence.

### Task 9.2: Prepare deterministic virtual-policy acceptance

- **Location**: `docs/environment/mt5-agentic-workflows.md`,
  `docs/research/` acceptance preparation.
- **Description**: Define the manual `Every tick based on real ticks` evidence
  sequence for initial cells, TP-consumed chains, retries, boundaries, gaps,
  expiry, censoring, quote sides, and ineligible rows without creating an
  automated tester harness.
- **Dependencies**: Task 9.1.
- **Acceptance criteria**:
  - The checklist names exact V11 files, identifiers, and row assertions.
  - Market-unreachable cases have an explicit static-evidence fallback.
  - Raw TSV files are inspected through the strict validator, not edited.
- **Validation**:
  - Manual command/path review against V11 headers and state transitions.
- **Rollback**: Revert only Sprint 9 acceptance preparation.

### Task 9.3: Prepare broker, calibration, research, and performance acceptance

- **Location**: `docs/environment/mt5-agentic-workflows.md`,
  `docs/research/` acceptance preparation.
- **Description**: Define the human checks for the unchanged one-order broker
  lane, parity agreement, natural-run dataset/audit behavior, and matched
  export-disabled/export-enabled performance intervals.
- **Dependencies**: Task 9.2.
- **Acceptance criteria**:
  - The checklist preserves FOK, immutable protection, ticket ownership, and
    broker-only money authority.
  - Unexplained strict TP/SL parity disagreement blocks acceptance.
  - Natural-run integrity, origin/trial support, state peak/cap, file growth,
    and elapsed time evidence are named precisely.
  - Commands do not create MQL5 test infrastructure or automate Strategy Tester.
- **Validation**:
  - Manual evidence and command review plus `git diff --check`.
- **Rollback**: Revert only Sprint 9 acceptance preparation.

### Sprint 9 Gate

- [ ] All Sprint 9 tasks complete.
- [ ] Full Python and fixture integration passes.
- [ ] Final static MQL5 safety, lifecycle, cleanup, and parity review passes.
- [ ] Precompile `.ex5` evidence is recorded and unchanged.
- [ ] Human acceptance protocol is complete and reproducible.
- [ ] No MetaEditor compile or automated Strategy Tester run has occurred.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 9 commit is created.
- [ ] Rollback point and commit SHA are recorded.
- [ ] Sprint 10 has not started before this gate completes.

## Sprint 10: Final Compile, Human Acceptance, And Archive

**Goal**: Run the sole real MetaEditor compile, complete human real-tick and V11
acceptance, record final evidence, archive the plan, and leave active
documentation pointing only to the accepted V11 workflow.

**Dependencies**: Sprint 9 gate and human access to MetaEditor/Strategy Tester.

**Tracked scope**: Only compile corrections required by final validation,
`HFT_Grid_AI.ex5`, `logs/compile/agentic-build.log`, final acceptance evidence,
`pivot-sl-tp-reentry-matrix-plan.md`, `docs/plans/README.md`, and new dated
archive folders under `docs/plans/archive/` and `docs/research/archive/`

**Commit**: `build: validate and close out pivot trial matrix v11`

**Demo/Validation**:

- The only real MetaEditor compile reports `0 errors, 0 warnings` and
  regenerates `HFT_Grid_AI.ex5`.
- Human `Every tick based on real ticks` acceptance covers virtual policies,
  unchanged broker execution, parity, natural V11 research, and performance.
- Plan execution ledger lists every sprint commit and rollback point.
- Completed plan and acceptance evidence are archived without modifying older
  archives.
- Active plan index returns to `None` and points to V11 architecture/workflows.

**Rollback point**: Sprint 9 commit SHA.

### Task 10.1: Run the single final MetaEditor compile

- **Location**: `HFT_Grid_AI.mq5`, `HFT_Grid_AI.ex5`,
  `tools/mt5/compile_mt5.py`, `logs/compile/agentic-build.log`
- **Description**: Compare the Sprint 9 precompile binary evidence, run the real
  compile helper once, parse the log, and record postcompile timestamp, size,
  and hash. `/s` syntax mode is not accepted as final proof.
- **Dependencies**: Sprint 9.
- **Acceptance criteria**:
  - Compiler result is exactly `0 errors, 0 warnings`.
  - `.ex5` is regenerated and postcompile evidence differs from the frozen
    precompile binary.
  - Any Wine process-code discrepancy is recorded beside parsed compiler status.
- **Validation**:
  - `python3 tools/mt5/compile_mt5.py --wine --mt5-root "/home/loldlm/mql5_projects/metatrader_5_market_data_framework" --entrypoint "/home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5" --log "logs/compile/agentic-build.log" --mode compile`
- **Rollback**: Revert Sprint 10 source corrections if compilation exposes a
  regression; never delete historical compiler evidence.

### Task 10.2: Complete human runtime, broker, research, and performance acceptance

- **Location**: Human Strategy Tester/chart, V11 Common Files run output,
  ignored dataset/audit/model artifacts, final `docs/research/` evidence.
- **Description**: Execute the Sprint 9 manual protocol using real ticks and
  fixed inputs, validate the natural V11 run, and record broker/parity and
  matched performance evidence without adding an automated harness.
- **Dependencies**: Task 10.1.
- **Acceptance criteria**:
  - One origin shows sixteen index-0 cells and policy-specific retry behavior.
  - Boundary, gap, expiry, censoring, Bid/Ask exits, and ineligible cells are
    verified through human observations or named static fallbacks.
  - The real lane remains one-order, FOK, immutable, ticket-owned, and the sole
    source of broker-confirmed money.
  - Strict parity pairs have no unexplained TP/SL terminal mismatch.
  - Natural V11 validate/build/audit behavior and support guards pass.
  - Export-disabled versus export-enabled overhead, peak state, file growth,
    and elapsed tester time are recorded over the same interval.
- **Validation**:
  - Human timestamped observations and broker history inspection.
  - `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root "$PIVOT_RUNS_ROOT" --run-id "$PIVOT_RUN_ID" --validate-only`
  - `.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root "$PIVOT_RUNS_ROOT" --run-id "$PIVOT_RUN_ID" --dataset-id "$PIVOT_DATASET_ID"`
  - `.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py --dataset-id "$PIVOT_DATASET_ID" --audit-id "$PIVOT_AUDIT_ID" --minimum-group-support 30`
  - `.venv/bin/python tools/deterministic_signal_ml/train_model.py --dataset-id "$PIVOT_DATASET_ID" --model-id <model_id>`
- **Rollback**: Preserve failed evidence and stop closeout if runtime, broker,
  parity, research, or performance acceptance fails.

### Task 10.3: Record the ledger and archive without deleting history

- **Location**: This plan before archival, final acceptance evidence,
  `docs/plans/archive/<v11-topic-date>/`,
  `docs/research/archive/<v11-topic-date>/`, `docs/plans/README.md`
- **Description**: Record every sprint SHA, rollback point, validation result,
  compile and human evidence, calibration findings, performance, and residual
  risks; then move the completed plan/evidence into dated archives and update
  the plan index. Do not edit or remove V9/V10 history or fixtures.
- **Dependencies**: Task 10.2.
- **Acceptance criteria**:
  - No validation is claimed without recorded evidence.
  - Virtual-vs-broker limitations and non-live-rollout restrictions remain
    explicit.
  - Archive links resolve and no duplicate active plan copy remains.
  - Active docs remain V11 and historical docs remain clearly historical.
- **Validation**:
  - Manual ledger/evidence cross-check.
  - `rg -n 'pivot trial matrix|schema V11|Active|Archived' docs/plans README.md AGENTS.md`
  - `git diff --check`
- **Rollback**: Revert only Sprint 10 and restore the accepted plan to active
  status without deleting archive content.

### Sprint 10 Gate

- [ ] All Sprint 10 tasks complete.
- [ ] Sole final MetaEditor compile is `0 errors, 0 warnings` with regenerated `.ex5`.
- [ ] Human real-tick matrix, broker, parity, research, and performance acceptance passes.
- [ ] Execution ledger and final rollback point are complete.
- [ ] Plan and acceptance evidence are archived.
- [ ] Older history remains preserved.
- [ ] Active plan index and documentation links are correct.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 10 commit is created.
- [ ] Active-plan execution state is marked complete only after this gate.

## Testing Strategy

- **MQL5 unit infrastructure**: None added. Repository policy forbids custom
  MQL5 harnesses, test modules, EAs/scripts, CI, or agentic tester automation.
- **Static MQL5 validation per implementation sprint**:
  - exact identifier/reference sweeps;
  - ordered include tracing and cycle review;
  - matrix count and state-transition proofs;
  - Bid/Ask side and price/tick normalization formula review;
  - broker safety-boundary inspection;
  - one `OrderSend`, one `OrderCheck`, FOK-only, no `TRADE_ACTION_SLTP` sweep;
  - handle, file, array, buffer, state-cap, and deinit cleanup review;
  - `git diff --check`.
- **Python unit and contract tests**:
  - strict eight-file headers and manifest;
  - identity, referential integrity, matrix cardinality, retry continuity, TP
    consumption, boundary, censoring, and summary reconciliation;
  - long/wide/chain/calibration materialization;
  - leakage exclusions, Macro-window grouping, purge boundaries, and
    origin-balanced weights;
  - V9/V10 fail-closed rejection and fixture preservation.
- **Integration**:
  - V11 fixture validate/build/audit/train support-guard flow;
  - final natural MQL5 V11 run validate/build/audit/train flow;
  - MQL5/Python exact header/token parity.
- **End-to-end/manual**:
  - Human Strategy Tester with `Every tick based on real ticks` covers pivot
    origin, sixteen cells, independent TP chains, retries, gap/boundary/expiry,
    ineligible rows, broker parity, costs, export lifecycle, and chart behavior.
- **Performance**:
  - Compare export off/on over identical 1-3 market-day runs;
  - record elapsed time, tick count if available, origin/trial/outcome rows,
    peak active state, cap status, and folder bytes;
  - inspect per-tick code for repeated market data, array churn, and logging.
- **Security/safety**:
  - No new secret, account, license, or remote dependency;
  - no virtual path may call trade mutation APIs;
  - export failure and state-cap failure cannot alter broker positions;
  - real pre-send broker facts remain authoritative.
- **Accessibility/frontend**:
  - No new user interaction is planned;
  - verify virtual trials do not clutter charts and the existing bounded real
    position visualization remains legible;
  - verify nonvisual tester performs zero chart work.
- **Migration/compatibility**:
  - No migration or conversion. V11 starts in a new root and active tooling
    rejects V9/V10.
  - Historical runs remain usable only with their historical repository
    revisions.
- **Operational**:
  - Unique run folder creation, buffered flush, natural completion, run-end
    censoring, cap failure, export failure, and cleanup are explicitly checked.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Virtual P&L is mistaken for broker net P&L | False strategy conclusions | Separate naming/tables; no virtual costs/net; parity calibration | Schema rejects mixed fields; reports show separate lanes |
| Matrix rows inflate apparent sample size | Overconfident human/ML results | Report unique-origin support; Macro-window grouping; per-origin sample weights | Audit and split tests |
| TP1 success incorrectly reopens with higher TP chains | Corrupted retry semantics | Policy-specific chain ID; TP terminal prohibits later index | Schema mutation test and human chain observation |
| Stops and freeze are double-counted | Valid small-volatility trials are wrongly denied | Use spread plus `max(stops, freeze)` plus one tick | Formula/static review and manifest policy |
| Tick normalization shrinks intended SL | Immediate/false stop outcomes | Directional outward normalization; exact risk ticks | Geometry inspection and strict ratio validation |
| Gap creates synthetic multiple retries | Optimistic path simulation | Actual observed entry quote; one generation per chain per tick | Gap human test and transition audit |
| Old-context retry overlaps next pivot | Ambiguous identity and double counting | Strict entry/SL boundary and next pivot ownership | Boundary/equality/gap tests |
| Re-entry continues after origin window expiry | Stale pivot context | Active trial may close; no new retry after expiry | Expiry terminal counts |
| Long-lived trials grow hot state | Tick performance or memory pressure | Store current generation only; remove completed; fixed cap; invalidate research on overflow | Peak/cap summary and performance run |
| Export or cap failure changes real execution | Trading regression | Matrix is export-only; failure suppresses research declarations only | Export-failure safety review |
| Sequential real quote differs from origin matrix quote | Misleading broker comparison | Matrix remains origin-frozen; parity shadow copies actual request separately | Calibration tables |
| `OrderCalcProfit` varies from realized gross | Money mismatch | Prefix as virtual quote gross; measure broker delta | Calibration distribution |
| Commission/swap/fee estimates introduce hidden assumptions | Ambiguous net strategy result | Do not create virtual net in V11 | Header and feature checks |
| Different normalized policies collapse to same prices | Duplicate evidence inflation | Keep declared rows, assign geometry equivalence, report/deduplicate support views | Equivalence audit |
| Multi-policy best-cell search overfits | False opportunity selection | Holdout support, uncertainty, multiple-comparison warning, no runtime promotion | Audit/report gate |
| Virtual outcome leaks into entry features | Invalid ML | Explicit future-only columns and tests | Leakage tests |
| Real broker path changes during refactor | Financial risk | Preserve V2 magic/route; one-send/check sweeps; final real-tick acceptance | Static gate, compile, human broker checks |
| Historical data is accidentally deleted | Loss of evidence | Preserve archives/fixtures/artifacts; V11-only active rejection | Historical diff checks |

## Rollback Plan

- Sprint 1 rollback restores the V10 Python contract from baseline while
  removing only the new V11 fixture.
- Sprint 2 rollback removes V11 materializations, audits, and policy-aware
  training while leaving the frozen V11 schema fixture intact.
- Sprint 3 rollback removes only inactive matrix types/helpers/state; broker and
  exporter behavior remain baseline.
- Sprint 4 rollback restores V10 exporter names/files and the prior broker
  export grain. Existing external V11 run folders are preserved as failed or
  experimental evidence, not converted.
- Sprint 5 rollback removes initial virtual lifecycle tracking and restores the
  one-real-order runtime.
- Sprint 6 rollback removes retry continuation while retaining index-0 matrix
  behavior only if the plan is explicitly amended; otherwise roll back through
  Sprint 5 as well to maintain schema/runtime parity.
- Sprint 7 rollback removes parity/calibration while preserving broker history
  and virtual trial facts already generated under the experimental revision.
- Sprint 8 rollback restores prior active documentation/tooling references but
  never edits archived history.
- Sprint 9 rollback returns to the Sprint 8 validated source commit while
  preserving precompile and acceptance-preparation evidence.
- Sprint 10 rollback returns to the Sprint 9 release-candidate commit and
  restores the accepted plan to active status without deleting compiler,
  tester, run, or archive evidence.
- Never use destructive Git reset or delete external datasets to perform a
  rollback. Revert the sprint-specific commit or redeploy the recorded prior
  commit after confirming the exact target.

## Execution Order

1. Read the planner execution-state instructions and initialize active-plan
   state before Sprint 1.
2. Implement Sprint 1 only.
3. Run and record every Sprint 1 validation check.
4. Create exactly one Sprint 1 commit and record its SHA and rollback point.
5. Start Sprint 2 only after the Sprint 1 gate passes.
6. Repeat the complete/validate/one-commit/record-rollback gate for every sprint.
7. Do not run intermediate MetaEditor compilation unless a human explicitly
   amends the plan.
8. Freeze the release candidate and complete all non-compiler acceptance
   preparation in Sprint 9 without invoking MetaEditor.
9. Run the single final real compile and human Strategy Tester gate in Sprint 10.
10. If Sprint 10 discovers behavior requiring source changes beyond local
    compile correction, stop, amend the plan with a corrective sprint, and do
    not archive or claim acceptance.

## Completion Checklist

- [ ] The current structural 1R route remains the only real broker order.
- [ ] All seven pivot origins declare the fixed sixteen-cell matrix when export
      is enabled.
- [ ] Every TP multiple owns an independent policy-specific retry chain.
- [ ] Volatility retries use frozen origin width, fresh entry quotes/features,
      strict distance, next-pivot boundary, and maximum index 3.
- [ ] Virtual first touch uses Bid for buy exits and Ask for sell exits.
- [ ] Ineligible and censored trials remain explicit and unlabeled.
- [ ] Virtual quote gross and actual broker money remain separate.
- [ ] Broker-parity calibration quantifies agreement and unexplained strict
      TP/SL mismatches are resolved.
- [ ] Strict V11 eight-file export validates with zero integrity errors.
- [ ] Long, wide, chain, broker, and calibration artifacts reconcile.
- [ ] Human/ML support counts do not treat correlated trials as independent
      origins.
- [ ] Active tooling accepts V11 only and rejects preserved V9/V10 fixtures.
- [ ] Public inputs and rollout restrictions remain unchanged.
- [ ] Full Python validation passes.
- [ ] Final MetaEditor compile reports `0 errors, 0 warnings` and regenerates
      `.ex5`.
- [ ] Human real-tick, broker, calibration, export, performance, DST, and chart
      acceptance passes.
- [ ] Every sprint has exactly one sprint-specific commit and recorded rollback
      point.
- [ ] Final plan/evidence archive is complete and no implementation remains
      untracked.
