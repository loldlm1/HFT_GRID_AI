# Plan: Pivot Fractal V12 Signal Features And Offline Research Contract

**Generated**: 2026-08-13
**Status**: Active implementation; execute Sprints 1-6 in order
**Estimated Complexity**: High
**Risk class**: Medium - changes export-only indicator capture, strict TSV schema,
offline datasets, and offline XGBoost inputs; the broker execution lane and virtual
policy lifecycle must remain behaviorally unchanged
**Execution baseline**: `454d907e247b4e82e7ce24032c9afe86b6631c04`
**Downstream dependency**: the Django V12 plan in
`/home/loldlm/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v12-django-cutover-plan.md`
must not execute beyond contract preparation until this plan completes and publishes
the accepted V12 producer commit, validator SHA-256, and type-registry SHA-256.

## Overview

Replace the active strict V11 producer/tooling contract with strict V12 while keeping
the current eight-file virtual-matrix, parity, execution-check, broker-outcome, and
summary model. V12 moves all discovery/model market features to the immutable
`signal_origins.tsv` row so they are captured once at the touched pivot rather than
repeated on every virtual trial or retry.

For both Micro and Macro timeframes, V12 exports shifts `0..5` for Bands `%B`,
Stochastic `MAIN_LINE`, and Stochastic `SIGNAL_LINE`. Those three series each have an
SMA 5, an SMA slope, and a three-way state (`ABOVE`, `BELOW`, `EQUAL`). Bands
`BASE_LINE` exports its raw value and its own one-shift slope in points; it does not
receive a second SMA/state layer. Trigger Micro and Macro Band widths are exported in
raw points at shift `0` only. All features remain research-only: missing data may make
a research row incomplete but cannot authorize, deny, resize, delay, or redirect
broker or virtual policy behavior.

V11 support is removed from active exporter and Python code. Archived plans, archived
research, old raw datasets, and generated artifacts are preserved as historical
evidence; active V12 tooling fails closed on V11 rather than converting it.

## Scope

- **In scope**:
  - Strict schema `12`, feature set `schema_v12_pivot_signal_features`, storage root
    `Common\\Files\\PivotFractalV12\\runs\\<run_id>\\`, and exactly the existing eight
    lowercase TSV basenames.
  - Four cached indicator handles when export is enabled: Macro/Micro `iBands` and
    Macro/Micro `iStochastic`; deterministic partial-init cleanup and deinitialization.
  - Origin-time Bands/Stochastic capture, V12 headers/manifest, strict validator,
    explicit dataset type registry, DuckDB/Parquet builder, audit, and offline XGBoost
    training.
  - Removal of duplicated entry feature columns from `virtual_trials.tsv`; virtual
    rows retain policy, entry, geometry, money, eligibility, continuation, and outcome
    facts and join to their immutable origin for market features.
  - Current virtual matrix, retries, parity calibration, broker execution/checks,
    deterministic time, route/sizing, and one-real-order behavior unchanged.
  - Active architecture/workflow/environment/research documentation updated to V12.
- **Out of scope**:
  - Any runtime model loader, model score, automatic filter, trade authorization,
    pattern playback, live deployment, broker-policy change, virtual-policy change,
    new public input, or configurable indicator parameter.
  - New MQL5 test harnesses, test EAs/scripts, automated Strategy Tester orchestration,
    dual V11/V12 writes, compatibility aliases, or V11-to-V12 conversion.
  - Django models, intake, discovery UI, production database deletion, or deployment;
    those belong to the dependent Django plan.
- **Fixed decisions**:
  - The immutable touched pivot price is the `%B` numerator for both timeframes and
    every shift `0..5`. Shift `n` uses that same price with the shift-`n` Bands
    envelope; shifts `1..5` are not copies of shift `0`.
  - Bands remain period `21`, deviation `2.0`, shift `0`, `MODE_SMA`, and
    `PRICE_WEIGHTED`.
  - Stochastic is `iStochastic(symbol, timeframe, 5, 3, 3, MODE_SMA,
    STO_CLOSECLOSE)` with buffer `0 = MAIN_LINE` and buffer `1 = SIGNAL_LINE`.
  - SMA 5 is the arithmetic mean of the current and previous four values at the same
    observation: `SMA5[shift] = mean(series[shift..shift+4])`.
  - SMA slope is `SMA5[shift] - SMA5[shift+1]`. Therefore the internal causal capture
    horizon is shifts `0..10`, although V12 exports only shifts `0..5`.
  - `%B` and each Stochastic-line state compare the raw series value to its SMA 5 with a documented
    deterministic tolerance, yielding only `ABOVE`, `BELOW`, or `EQUAL`; missing data
    is represented by the existing null/availability contract, not a fourth state.
  - Bands `BASE_LINE` slope is
    `(BASE_LINE[shift] - BASE_LINE[shift+1]) / point_size`.
  - Micro and Macro trigger width is
    `(UPPER_BAND[0] - LOWER_BAND[0]) / point_size`; no V12 normalized-width discovery
    column is required.
  - All listed origin features are captured even if later research chooses only a
    subset. No discovery field is mandatory for a human rule, audit grouping, or
    model ablation.
  - XGBoost remains offline-only and uses origin market features joined to matrix
    policy rows with the current per-origin weighting and leakage-safe splits.
- **Assumptions**:
  - `%B SMA 5`, `%B slope`, and `%B state` mean smoothing and state of the computed
    shift-indexed `%B` series, not a second price moving average.
  - Stochastic SMA 5, slope, and state are calculated separately for `MAIN_LINE` and
    `SIGNAL_LINE`.
  - The requested “band MA slope” is the built-in Bands `BASE_LINE` slope; V12 exports
    the base-line value so a consumer can reproduce it, but does not add an SMA 5 or
    state for `BASE_LINE`.
  - Existing V9/V10/V11 fixtures and archives remain untouched unless an active test
    explicitly asserts that non-V12 shapes are rejected.

## Named Resources

- **Project instructions**: `AGENTS.md` and repository-local included instructions.
- **Entrypoint and include chain**: `HFT_Grid_AI.mq5`,
  `services/trading_management.mqh`, `services/trading_signals.mqh`.
- **Indicator configuration/lifecycle**:
  `services/trading_management/ea_inputs.mqh`,
  `services/trading_management/pivot_fractal_engine_config.mqh`,
  `services/core/base_structures.mqh`,
  `services/trading_management/indicator_definitions_loader.mqh`.
- **Feature capture and signal ownership**:
  `services/trading_signals/pivot_context_features.mqh`,
  `services/trading_signals/pivot_fractal_signal_detection.mqh`,
  `services/trading_signals/pivot_signal_struct.mqh`,
  `services/trading_signals/pivot_trial_matrix_struct.mqh`,
  `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`.
- **Window/export integration**:
  `services/trading_signals/pivot_fractal_engine_state.mqh`,
  `services/trading_signals/pivot_fractal_statistics_export.mqh`,
  `services/trading_signals/execution_controller.mqh`,
  `services/trading_signals/pivot_signal_lifecycle.mqh`.
- **Offline tooling**: `tools/deterministic_signal_ml/schema_contract.py`,
  `build_dataset.py`, `pivot_fractal_audit.py`, `model_config.py`,
  `feature_encoder.py`, `report_writer.py`, `train_model.py`,
  `validation_splits.py`, `README.md`, and
  `tools/deterministic_signal_ml/tests/`.
- **Active documentation**: `AGENTS.md`, `README.md`, `docs/plans/README.md`,
  `docs/architecture/market-data-broker-executor.md`,
  `docs/environment/mt5-agentic-workflows.md`,
  `docs/workflows/pivot-fractal-statistics-flow.md`,
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`, and
  `docs/research/README.md`.
- **Compile/validation resources**: the `production-engineering-stack`
  MetaEditor MCP (`get_workspace_info`, then `compile_file`),
  `tools/mt5/compile_mt5.py` as fallback, `logs/compile/agentic-build.log`, local
  `.venv`, ignored `artifacts/`, and a human MT5 Strategy Tester/chart session.
- **Official MQL5 documentation**:
  - `https://www.mql5.com/en/docs/indicators/ibands`
  - `https://www.mql5.com/en/docs/indicators/istochastic`
  - `https://www.mql5.com/en/docs/series/copybuffer`

## Prerequisites

- Start execution from a clean or fully understood worktree at the recorded baseline;
  preserve all unrelated user changes and all archived plans/research.
- Keep this file and `docs/plans/README.md` as the canonical active-plan state
  through Sprint 6.
- Keep the current Python research environment available, or recreate it from
  `tools/deterministic_signal_ml/requirements.txt` without changing dependency pins.
- Keep the MetaEditor MCP, MetaEditor/Wine fallback, and MT5 Common Files paths from
  `docs/environment/mt5-agentic-workflows.md` available for the one final compile and
  human acceptance sprint.
- Retain at least one operator-controlled V12 test output folder after the MQL5 runtime
  is implemented; no historical V11 run can prove new trigger-time features.

## Sprint 1: Freeze The Strict V12 Schema And Feature Semantics

**Goal**: Make the new origin-grain contract executable and testable in Python before
changing MQL5 runtime capture.
**Dependencies**: prerequisites only.
**Tracked scope**: `tools/deterministic_signal_ml/schema_contract.py`,
`tools/deterministic_signal_ml/tests/fixtures/schema_v12_pivot_signal_features/`,
`tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`,
`tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`.
**Commit**: `feat: define strict pivot v12 signal feature contract`
**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Expected: the minimal V12 fixture validates, exact eight-file/header/manifest and
  cross-file invariants pass, and V11/non-V12 inputs fail closed.

**Rollback point**: execution baseline `454d907`.

### Task 1.1: Define V12 identifiers, manifest, headers, and grains

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`.
- **Description**: replace the active V11 constants with schema `12`, engine
  `PIVOT_FRACTAL_V2`, feature set `schema_v12_pivot_signal_features`, and the existing
  eight basenames. Keep identity/outcome/summary facts required by current virtual and
  broker integrity, but remove Macro window Band feature columns and remove every
  `entry_*` signal-feature duplicate from `virtual_trials.tsv`. Define all new
  `origin_micro_*` and `origin_macro_*` feature columns on `signal_origins.tsv`.
- **Dependencies**: none.
- **Acceptance criteria**:
  - `signal_origins.tsv` is the sole source table for new indicator features.
  - `virtual_trials.tsv` joins by `origin_id` and carries no duplicated Bands,
    Stochastic, SMA, slope, state, or feature-completeness fields.
  - Exact file order and null token remain frozen.
- **Validation**: contract unit tests comparing all headers, file order, column count,
  and source grains.
- **Rollback**: revert this sprint commit; no runtime or raw data exists yet.

### Task 1.2: Encode exact feature formulas and validation invariants

- **Location**: `tools/deterministic_signal_ml/schema_contract.py` and V12 fixture.
- **Description**: validate shifts `0..5`, finite unbounded `%B`, `%B`/Stochastic SMA 5
  formulas, slopes and states, base-line raw values/slopes in points, trigger widths in
  points, and availability consistency. Validate Stochastic manifest pins and require buffer-semantic tokens
  `MAIN_LINE` and `SIGNAL_LINE` only.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - A fixture mutation of any formula, state, shift, width, or indicator pin is
    rejected with a bounded diagnostic.
  - `ABOVE/BELOW/EQUAL` is accepted only when the corresponding raw and SMA values
    exist and reconcile under the frozen tolerance.
- **Validation**: focused fixture-mutation tests plus full unit discovery.
- **Rollback**: revert fixture and validator changes together.

### Task 1.3: Preserve virtual/broker integrity while rejecting V11

- **Location**: `tools/deterministic_signal_ml/schema_contract.py` and schema tests.
- **Description**: port the eight-file V11 matrix/retry/parity/broker arithmetic and
  referential checks to the V12 column layout; keep V9/V10/V11 rejection tests and
  remove active V11 feature-set acceptance.
- **Dependencies**: Tasks 1.1-1.2.
- **Acceptance criteria**:
  - Sixteen index-0 cells, retry continuity, parity links, first-touch, money lanes,
    summary counts, causal timestamps, and completion rules retain current semantics.
  - V11 is rejected; it is never silently upgraded or combined with V12.
- **Validation**: full schema suite and exact identifier/reference sweeps.
- **Rollback**: revert Sprint 1.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] V12 fixture and mutation tests pass; V11 rejection is explicit.
- [ ] No `.mq5`/`.mqh`, broker behavior, raw evidence, or generated artifact changed.
- [ ] `git diff --check` and exact V11/V12 reference review pass.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] Rollback point and commit SHA are recorded before Sprint 2.

## Sprint 2: Add Bounded Macro/Micro Indicator Lifecycle And Feature Math

**Goal**: Capture one causal, immutable origin feature snapshot with four cached
handles and no effect on execution authorization.
**Dependencies**: Sprint 1 gate.
**Tracked scope**: `services/trading_management/ea_inputs.mqh`,
`services/trading_management/pivot_fractal_engine_config.mqh`,
`services/core/base_structures.mqh`,
`services/trading_management/indicator_definitions_loader.mqh`,
`services/trading_signals/pivot_context_features.mqh`,
`services/trading_signals/pivot_fractal_engine_state.mqh`,
`services/trading_signals/pivot_fractal_signal_detection.mqh`.
**Commit**: `feat: capture causal macro micro v12 indicators`
**Demo/Validation**:

- Static include tracing from `HFT_Grid_AI.mq5` through the ordered aggregators.
- Exact sweeps for handle creation/release, `CopyBuffer`, buffer indexes, capture
  horizons, shift bounds, point conversion, and all call sites.
- `git diff --check`; no intermediate MetaEditor compile.

**Rollback point**: Sprint 1 commit.

### Task 2.1: Own and lifecycle four cached indicator handles

- **Location**: `services/core/base_structures.mqh`,
  `services/trading_management/indicator_definitions_loader.mqh`, and fixed constants
  in `services/trading_management/ea_inputs.mqh` /
  `services/trading_management/pivot_fractal_engine_config.mqh`.
- **Description**: add Macro/Micro Stochastic handle ownership beside Bands; create all
  handles only when `Enable_Signal_Feature_Export` is true, check each handle, tolerate
  partial initialization, release every acquired handle on reinit/deinit, and keep
  tester indicator hide mode balanced.
- **Dependencies**: Sprint 1.
- **Acceptance criteria**:
  - Export disabled creates no feature indicator handle or feature buffer work.
  - Export enabled owns exactly two Bands plus two Stochastic handles.
  - Stochastic parameters and buffer meanings match the official contract.
- **Validation**: identifier/reference sweeps and lifecycle review.
- **Rollback**: revert handle additions; the broker path remains unchanged.

### Task 2.2: Replace V11 snapshots with V12 origin-series snapshots

- **Location**: `services/trading_signals/pivot_context_features.mqh`.
- **Description**: model availability separately for Bands envelopes/base values,
  Stochastic lines, derived SMA/slope/state arrays, base-line slopes, and two shift-0
  widths. Copy bounded buffer ranges once per timeframe/indicator snapshot where local
  conventions allow, validate causal current-bar visibility, and derive exported
  shifts from the internal history horizon. Remove the old Micro weighted-price
  history path.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Both Micro and Macro `%B[0..5]` use the candidate's immutable touched pivot.
  - `SMA5[5]` and its slope can be calculated because raw values through shift `10`
    are captured causally.
  - Missing data records precise invalid reasons without changing execution.
  - Per-trigger work is bounded and does not create handles or scan full history.
- **Validation**: manual formula walk-through for every feature family and shift,
  bounds review, fallible-call review, and hot-path review.
- **Rollback**: revert snapshot structures/helpers and restore the prior compileable
  capture path.

### Task 2.3: Bind candidate-specific touched pivots without same-tick leakage

- **Location**: `services/trading_signals/pivot_fractal_signal_detection.mqh` and
  `services/trading_signals/pivot_fractal_engine_state.mqh`.
- **Description**: capture the common indicator buffers once for a same-tick candidate
  batch, then derive each candidate's Micro/Macro `%B` using that candidate's pivot.
  Remove active V11 Macro shift-1 Band telemetry from window state if no runtime
  virtual calculation still requires it; preserve the frozen Micro shift-0 raw price
  width used by the existing virtual volatility policies.
- **Dependencies**: Task 2.2.
- **Acceptance criteria**:
  - Multiple same-tick pivot candidates share buffer reads but keep distinct `%B`.
  - Window refresh, trigger order, identity consumption, route, and broker behavior do
    not change.
  - Virtual volatility cells still freeze the trigger Micro full width in price units.
- **Validation**: call-graph review, same-tick path-order review, and broker/virtual
  safety-boundary diff inspection.
- **Rollback**: revert Sprint 2.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] Handle lifecycle, causal series, formulas, shift bounds, and cleanup pass static
  review.
- [ ] Execution, route/sizing, virtual policy, parity, and broker ownership diffs are
  absent or proven behavior-preserving.
- [ ] No intermediate MetaEditor compile or new MQL5 harness is run.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 2 commit is created; rollback point is recorded.

## Sprint 3: Replace The MQL5 Exporter With Strict V12 Origin Features

**Goal**: Emit a self-consistent V12 run under a new storage root without any active
V11 write path or trial-level feature duplication.
**Dependencies**: Sprint 2 gate.
**Tracked scope**: `services/trading_signals/pivot_fractal_statistics_export.mqh`,
`services/trading_signals/pivot_signal_struct.mqh`,
`services/trading_signals/pivot_trial_matrix_struct.mqh`,
`services/trading_signals/pivot_trial_matrix_lifecycle.mqh`,
`services/trading_signals/execution_controller.mqh`,
`services/trading_signals/pivot_signal_lifecycle.mqh`,
`services/trading_signals/pivot_fractal_signal_detection.mqh`, `HFT_Grid_AI.mq5`.
**Commit**: `feat: replace pivot v11 export with strict v12`
**Demo/Validation**:

- Exact header/append-order comparison between MQL5 constants and Python
  `TABLE_COLUMNS`.
- Exact sweeps require no active `PIVOT_V11`, `PivotV11`, or
  `PivotFractalV11` references outside archives.
- `git diff --check`; no intermediate MetaEditor compile.

**Rollback point**: Sprint 2 commit.

### Task 3.1: Rename and pin the active exporter contract

- **Location**: `services/trading_signals/pivot_fractal_statistics_export.mqh` and all
  active callers.
- **Description**: replace V11 identifiers/functions/globals with V12, storage root
  `PivotFractalV12`, schema `12`, the V12 feature set, manifest formulas/parameters,
  and the exact same eight filenames. Do not retain aliases or dual-write logic.
- **Dependencies**: Sprint 2.
- **Acceptance criteria**:
  - Active source initializes and flushes only V12 folders/files.
  - Existing failure, buffering, referential, summary, and run-completion behavior is
    preserved under V12 names.
- **Validation**: active-reference sweep, config-payload review, path-safety review.
- **Rollback**: revert Sprint 3 to the compileable pre-export state.

### Task 3.2: Serialize signal features once on origins

- **Location**: origin header/row builders in
  `services/trading_signals/pivot_fractal_statistics_export.mqh`.
- **Description**: append Micro then Macro groups in one fixed readable order: width
  points at shift `0`; Bands `%B` raw/SMA5/SMA-slope/state for shifts `0..5`;
  Stochastic `MAIN_LINE` raw/SMA5/slope/state; Stochastic `SIGNAL_LINE`
  raw/SMA5/slope/state; Bands `BASE_LINE` raw value and slope points only. Preserve nulls and
  one bounded invalid-reason field for incomplete origin feature evidence.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Each consumed origin writes exactly one feature vector.
  - Header order exactly matches Python V12 and no feature is clipped.
  - Width and slope units are explicitly points; raw `%B` and Stochastic values retain
    their natural units.
- **Validation**: append-count/header parity checks and manual row reconstruction.
- **Rollback**: revert origin header and serializer atomically.

### Task 3.3: Remove feature duplication from trial/retry rows

- **Location**: `PivotTrialEntry` ownership and virtual-trial serialization in
  `services/trading_signals/pivot_trial_matrix_struct.mqh`,
  `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`, and exporter.
- **Description**: remove trial entry feature snapshots and retry-time feature buffer
  capture. Keep only the immutable origin Micro price width required for volatility
  geometry. Change virtual binary feature eligibility and offline joins to origin
  feature completeness without making feature completeness a virtual execution gate.
- **Dependencies**: Task 3.2.
- **Acceptance criteria**:
  - Retries do not recapture market features.
  - Virtual eligibility remains geometry/money/policy based; missing discovery
    features affect labels/research cohort only, not whether an otherwise valid
    virtual cell is declared and observed.
  - Parity, retries, active-state bounds, and summary counts retain current semantics.
- **Validation**: lifecycle and outcome-eligibility review; trial header/row parity;
  search proving all `entry_*feature*` columns and storage are gone.
- **Rollback**: revert Sprint 3.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] MQL5 and Python V12 headers match exactly.
- [ ] V11 active exporter names, paths, aliases, and dual-write behavior are absent.
- [ ] New features occur only on origins; trials retain no duplicate feature vector.
- [ ] Broker/virtual behavior-preservation and include/reference sweeps pass.
- [ ] No intermediate MetaEditor compile is run; `git diff --check` passes.
- [ ] Exactly one Sprint 3 commit is created; rollback point is recorded.

## Sprint 4: Upgrade V12 Dataset Builder, Audit, And Offline XGBoost

**Goal**: Produce typed V12 research artifacts and train offline candidates from
origin-grain features joined to unchanged policy/outcome grains.
**Dependencies**: Sprint 3 gate.
**Tracked scope**: `tools/deterministic_signal_ml/build_dataset.py`,
`pivot_fractal_audit.py`, `model_config.py`, `feature_encoder.py`,
`report_writer.py`, `train_model.py`, `validation_splits.py`,
`tools/deterministic_signal_ml/tests/`, and V12 fixture.
**Commit**: `feat: build audit and train pivot v12 datasets`
**Demo/Validation**:

- `.venv/bin/python -m compileall -q tools/deterministic_signal_ml`
- `.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`
- Fixture V12 validate/build/audit and expected training support guard.

**Rollback point**: Sprint 3 commit.

### Task 4.1: Freeze an exhaustive V12 type registry and typed load

- **Location**: `tools/deterministic_signal_ml/build_dataset.py` and contract tests.
- **Description**: replace the V11 explicit type registry with an exhaustive V12
  registry and fail on missing, duplicate, or stale columns. Update typed DuckDB loads
  and raw Parquet copies without fallback inference.
- **Dependencies**: Sprint 3 header freeze.
- **Acceptance criteria**:
  - Every unique V12 column has exactly one `VARCHAR`, `TIMESTAMP`, `BOOLEAN`,
    `BIGINT`, or `DOUBLE` type.
  - No active code accepts V11 or guesses a new column type.
- **Validation**: registry exactness tests and fixture build.
- **Rollback**: revert Sprint 4.

### Task 4.2: Rebuild long/wide/chain/calibration artifacts around origin joins

- **Location**: `tools/deterministic_signal_ml/build_dataset.py` and builder tests.
- **Description**: keep the current raw eight tables plus
  `origin_matrix_long.parquet`, `initial_matrix_wide.parquet`,
  `eligible_virtual_trials.parquet`, `policy_chains.parquet`, and
  `broker_virtual_calibration.parquet`. Join V12 origin features to policy rows by
  `(run_id, origin_id)` and prove retry rows do not duplicate independent origin
  support or introduce future columns.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Output grains/counts reconcile with strict source rows.
  - Origin market features are identical across a chain because they are joined from
    one origin record, not copied at each retry.
  - Ineligible/censored rows remain present and unlabeled.
- **Validation**: artifact schema/count/grain tests and leakage-column sweeps.
- **Rollback**: revert Sprint 4.

### Task 4.3: Define ordered V12 ablations and keep training offline-only

- **Location**: `model_config.py`, `feature_encoder.py`, `train_model.py`,
  `pivot_fractal_audit.py`, `report_writer.py`, and tests.
- **Description**: retain policy/level/direction/time and causal geometry ratios as the
  base; add width points; then separate Micro and Macro Bands groups; then Micro and
  Macro Stochastic groups. Include `%B`/Stochastic SMA, slope, and state plus raw
  `BASE_LINE` and `BASE_LINE` slope in their matching group. State is categorical,
  continuous values remain continuous, and the
  complete ablation order must exactly reconstruct the frozen V12 feature set.
- **Dependencies**: Task 4.2.
- **Acceptance criteria**:
  - XGBoost training still uses purged chronological holdout, walk-forward folds,
    fixed seeds, and weights summing to `1.0` per origin.
  - Audit reports per-feature availability and support without declaring an edge or
    requiring every feature in human discovery.
  - Model manifest remains `OFFLINE_RESEARCH_ONLY` with no runtime artifact.
- **Validation**: ablation reconstruction tests, encoder state tests, leakage tests,
  fixture audit, and expected insufficient-support training failure.
- **Rollback**: revert Sprint 4.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Full Python suite and deterministic V12 fixture pipeline pass.
- [ ] V12 type registry is exhaustive and disjoint; V11 is rejected.
- [ ] Artifact grains, joins, weights, leakage bounds, and offline-only state pass.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 4 commit is created; rollback point is recorded.

## Sprint 5: Documentation, Static Release Review, And Downstream Handoff

**Goal**: Make V12 the sole active documented contract and freeze a reviewable release
candidate for compilation and human evidence.
**Dependencies**: Sprint 4 gate.
**Tracked scope**: `AGENTS.md`, `README.md`, `docs/plans/README.md`,
`docs/architecture/market-data-broker-executor.md`,
`docs/environment/mt5-agentic-workflows.md`,
`docs/workflows/pivot-fractal-statistics-flow.md`,
`docs/workflows/pivot-fractal-offline-research-boundaries.md`,
`docs/research/README.md`, `tools/deterministic_signal_ml/README.md`.
**Commit**: `docs: publish pivot v12 research workflow`
**Demo/Validation**:

- Active-document and code sweeps for `V11`, `PivotFractalV11`, and obsolete feature
  names; historical archives are excluded from replacement.
- Include tracing, exact identifier/reference sweeps, broker safety-boundary review,
  Python suite, and `git diff --check`.

**Rollback point**: Sprint 4 commit.

### Task 5.1: Update active architecture, workflow, and environment contracts

- **Location**: named active documentation files.
- **Description**: document exact V12 formulas, units, indicator handles, storage path,
  origin feature grain, eight files, validation/build/audit/train commands, offline
  boundaries, and human reproduction matrix. Preserve historical archive text.
- **Dependencies**: Sprint 4.
- **Acceptance criteria**:
  - No active document describes V11 as supported.
  - The docs clearly distinguish trigger-time origin features from virtual/broker
    outcomes and state that features never filter execution.
- **Validation**: link/path/command review and active-reference sweep.
- **Rollback**: revert Sprint 5 docs.

### Task 5.2: Freeze producer handoff pins for Django

- **Location**: `tools/deterministic_signal_ml/schema_contract.py`, generated or
  documented registry evidence, and active research docs.
- **Description**: record the accepted upstream commit SHA and calculate the exact V12
  validator and type-registry SHA-256 values only after Sprint 4 source is final. State
  the exact vendorable files and fixture directory for Django.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - Django can pin one immutable V12 validator source, source commit, and exhaustive
    type registry without copying V11 compatibility code.
  - Changing a pin requires a deliberate future schema plan.
- **Validation**: independent SHA-256 calculation and fixture provenance review.
- **Rollback**: revert the handoff documentation with Sprint 5.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] Active code/docs are V12-only; archives and old datasets remain preserved.
- [ ] Static MQL5 and full Python gates pass with no compile claimed.
- [ ] Django handoff commit/hash/fixture resources are named and frozen.
- [ ] `git diff --check` passes.
- [ ] Exactly one Sprint 5 commit is created; rollback point is recorded.

## Sprint 6: Final MetaEditor Compile And Human V12 Acceptance

**Goal**: Prove the committed V12 producer compiles cleanly and emits a natural,
strict, reproducible V12 run suitable for Django intake.
**Dependencies**: Sprint 5 gate and human access to MetaEditor/MT5 Strategy Tester.
**Tracked scope**: committed source, regenerated untracked/ignored `HFT_Grid_AI.ex5`,
`logs/compile/agentic-build.log`, a fresh
`Common\\Files\\PivotFractalV12\\runs\\<run_id>\\` folder, ignored offline artifacts,
and a new V12 acceptance record under `docs/research/`.
**Commit**: `docs: record pivot v12 producer acceptance`
**Demo/Validation**:

- Final real compile via MetaEditor MCP `compile_file`, after
  `get_workspace_info`, with `0 errors, 0 warnings` and generated `.ex5`
  metadata. Use `python3 tools/mt5/compile_mt5.py ... --mode compile` only as a
  documented fallback.
- Human `Every tick based on real ticks` run; strict V12 validate/build/audit/train
  pipeline; manual feature reproduction and export-on/off comparison.

**Rollback point**: Sprint 5 commit and its previously known-good binary metadata.

### Task 6.1: Run the single final real MetaEditor compile

- **Location**: `HFT_Grid_AI.mq5`, compile helper/log, and `.ex5` metadata.
- **Description**: compile the committed Sprint 5 source through the MetaEditor MCP
  using the environment runbook; record workspace/compiler metadata, compiler status,
  and generated `.ex5` output metadata. Use the local runner only if MCP compilation
  is unavailable, recording the fallback reason and any Wine process-code discrepancy.
- **Dependencies**: Sprint 5.
- **Acceptance criteria**:
  - Compiler reports exactly `0 errors, 0 warnings`.
  - `.ex5` regeneration is evidenced; `/s` alone is not accepted.
- **Validation**: parsed compile log and artifact metadata.
- **Rollback**: return source to Sprint 5 rollback point and preserve compile evidence.

### Task 6.2: Perform human causal feature and behavior acceptance

- **Location**: Strategy Tester/chart and fresh V12 Common Files run.
- **Description**: verify Macro/Micro causal bar visibility; touched-pivot `%B` for
  shifts `0..5`; `%B` SMA/slope/state; Stochastic `MAIN_LINE`/`SIGNAL_LINE` raw,
  SMA/slope/state; base-line slopes; shift-0 width points; null/incomplete behavior;
  PP/support/resistance same-tick identities; virtual matrix/retries/parity; immutable
  broker SL/TP; DST; and no chart work in nonvisual mode.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - Selected rows reproduce against MT5 indicator values and exact formulas.
  - A natural run ends with `export_status=OK`, zero integrity errors, and strict V12
    validation success.
  - Export disabled versus enabled over the same 1-3 market days records elapsed time,
    peak state, row counts, and folder bytes without signal/order divergence.
- **Validation**: human checklist plus preserved compact evidence; no automated MQL5
  harness substitutes for it.
- **Rollback**: retain failed evidence, correct in a newly authorized sprint, and do not
  hand an unaccepted producer to Django.

### Task 6.3: Build, audit, train, and publish the downstream handoff

- **Location**: fresh V12 run, ignored `artifacts/datasets`, `artifacts/audits`,
  `artifacts/models`, and V12 acceptance record.
- **Description**: run strict validation, build all raw/derived artifacts, audit virtual
  and broker lanes, and run offline XGBoost or its explicit support guard. Record
  counts, sizes, timings, memory where practical, validator/registry pins, final source
  commit, and the fixture/source package Django must vendor.
- **Dependencies**: Task 6.2.
- **Acceptance criteria**:
  - V12 pipeline completes or fails only at a documented support threshold after valid
    build/audit.
  - No runtime model artifact or live authorization is emitted.
  - The downstream Django plan has all immutable prerequisites.
- **Validation**: commands from the updated workflow and hash verification.
- **Rollback**: do not advance Django; preserve the V12 run and artifacts for diagnosis.

### Sprint 6 Gate

- [ ] Final compile is `0 errors, 0 warnings` with regenerated `.ex5`.
- [ ] Human Strategy Tester/chart V12 acceptance passes.
- [ ] Strict validate/build/audit and offline training/support guard pass.
- [ ] Producer commit, validator pin, registry pin, fixture provenance, counts, and
  residual risks are recorded.
- [ ] Exactly one Sprint 6 acceptance commit is created; rollback point is recorded.
- [ ] Only after this gate may the dependent Django plan consume V12 as authoritative.

## Testing Strategy

- **MQL5 static**: exact identifier/reference sweeps, ordered include tracing, handle
  ownership/cleanup, `CopyBuffer` count/index checks, causal bar visibility, shift
  horizon math, state tolerance, point conversions, bounded tick work, broker and
  virtual safety-boundary diff review, and `git diff --check` every sprint.
- **Python unit/contract**: strict V12 headers, formulas, availability/null semantics,
  exhaustive type registry, file set, cross-file integrity, mutation rejection,
  V11 rejection, leakage fields, dataset grains, sample weights, splits, encoder, and
  ablation reconstruction.
- **Integration**: fixture validate/build/audit/train-support flow followed by one
  natural MQL5-produced V12 run through the same pipeline.
- **End-to-end/manual**: one final real MetaEditor compile and human real-tick Strategy
  Tester/chart matrix. Compilation and Python fixtures do not replace runtime
  causality, indicator parity, order lifecycle, DST, export, performance, or visual
  acceptance.
- **Performance/reliability**: compare export off/on over identical 1-3 day inputs;
  record runtime, folder growth, active-state peak, and confirm no per-tick handle
  creation, full-history scan, unbounded log, or extra work when export is disabled.
- **Security/privacy**: keep account IDs, credentials, broker secrets, raw private TSV
  rows, full logs, and model contents out of commits/chat; report compact hashes,
  counts, paths, and first useful failures only.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Touched-pivot Micro `%B` is accidentally implemented with trigger Bid or historical prices | Research semantics diverge from the fixed decision | Candidate-specific derivation uses one immutable pivot for both timeframes | Manual row reproduction for shifts `0..5` |
| SMA slope shift `5` lacks enough history | Null or incorrect tail features | Capture raw series through shift `10`; export only `0..5` | Fixture formulas and buffer-bound review |
| Stochastic buffer meanings are reversed | Discovery/model features are mislabeled | Pin official `0=MAIN_LINE`, `1=SIGNAL_LINE`; explicit names only | Mutated-buffer fixture and human MT5 comparison |
| Floating equality produces unstable states | Non-deterministic `EQUAL` classification | Freeze one scale-aware tolerance in MQL5 and Python | Boundary mutation tests and manual equal case |
| Trial feature removal changes virtual declaration or outcomes | Research refactor affects policy behavior | Keep origin Micro price width for volatility geometry and separate research completeness from trial activation | Static lifecycle review and human matrix parity |
| More indicator history slows the tick path | Tester/export regression | Four cached handles, bounded bulk copies per candidate batch, no work export-off | Export off/on measurement and hot-path review |
| V11 names remain active in a caller or doc | Mixed contract and wrong folders | No aliases/dual writes; active-reference sweeps excluding archives | Zero active V11 matches after Sprint 5 |
| New features leak future/outcome facts into XGBoost | Inflated offline results | Origin-time only source, explicit future-field denylist, purged splits | Leakage and partition tests |
| Python fixture passes but MQL5 row order differs | Real runs fail strict validation | Freeze Python first; exact MQL5 header/append parity gate | Natural V12 validation succeeds |
| Final V12 run has insufficient model support | Training cannot produce a useful candidate yet | Treat support guard as valid outcome; do not weaken thresholds | Valid build/audit plus explicit support diagnostic |

## Rollback Plan

- Roll back code one sprint at a time to the recorded prior commit; never use a broad
  destructive Git command and never delete historical raw runs or artifacts.
- Before Sprint 6, rollback is source-only because no accepted V12 production evidence
  is authoritative. Preserve any failed compile/tester/export evidence for diagnosis.
- After V12 producer acceptance, a rollback to V11 is a repository/runtime rollback
  only; V12 raw runs remain historical evidence and are not relabeled or converted.
  The dependent Django V12 cutover must not proceed until the producer is restored and
  reaccepted.
- If indicator capture is wrong, stop before Django handoff, revert to the last
  compileable sprint, and create a new corrective sprint; do not patch raw TSVs.
- If the offline builder/audit/trainer is wrong, keep the immutable raw V12 run and
  rebuild derived ignored artifacts after correction.

## Execution Order

1. Initialize active-plan state and implement Sprint 1 only.
2. Validate Sprint 1, create exactly one sprint-specific commit, and record its SHA and
   rollback point.
3. Repeat the complete gate for Sprints 2-5 without running MetaEditor in intermediate
   sprints.
4. Freeze the Sprint 5 release candidate, then run the one final real compile and human
   acceptance in Sprint 6.
5. Create exactly one Sprint 6 acceptance commit and publish the immutable V12 handoff.
6. Start the dependent Django plan only after all Sprint 6 gates pass.

## Completion Checklist

- [ ] Strict V12 replaces active V11 exporter/tooling support.
- [ ] Origin-grain Micro/Macro Bands and Stochastic features match frozen formulas.
- [ ] Virtual trials contain no duplicate signal feature vector.
- [ ] Existing virtual, parity, broker, timing, route, and sizing behavior is preserved.
- [ ] V12 validator, builder, audit, and offline XGBoost flow pass.
- [ ] Active documentation is V12-only while archives and old datasets are preserved.
- [ ] Every sprint has exactly one validated commit and recorded rollback point.
- [ ] Final compile and human Strategy Tester acceptance pass.
- [ ] Accepted producer pins and fixture are ready for the Django cutover plan.
