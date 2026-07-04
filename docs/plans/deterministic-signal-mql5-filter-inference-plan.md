# Plan: Deterministic Signal MQL5 Filter Inference

**Generated**: 2026-07-04
**Status**: Approved; implementation in progress
**Estimated Complexity**: High
**Risk Level**: High for Strategy Tester admission behavior; low for default/live
behavior if `ML_INFERENCE_DISABLED` remains the default and `FILTER` is gated to
the approved tester workflow.

## Overview

Implement Phase 6 of the deterministic signal ML roadmap: add `FILTER` mode so
the already-validated MQL5 model scorer can affect deterministic broker
admission in Strategy Tester.

The design must preserve the existing execution safety stack. The model must not
create entries, resize lots, change SL/TP, bypass license/session/spread/margin
guards, override protection controls, or touch broker reconciliation. The filter
may only deny an otherwise admissible deterministic entry after the existing
local broker eligibility checks pass and before the real broker send.

Execution is ordered. Complete, validate, and commit one sprint before starting
the next sprint.

## Recommended Decisions To Confirm

The user approved these recommendations on 2026-07-04. Use them as the
implementation contract.

1. `FILTER` is Strategy Tester only for Phase 6.
   - Recommendation: keep live chart behavior out of scope. If `FILTER` is
     selected outside Strategy Tester, block deterministic ML-filtered entries
     with a clear `filter_not_allowed_outside_tester` reason.
2. `FILTER` blocks only scored `BLOCK` recommendations.
   - Recommendation: allow entries only when the model is available, features are
     valid, classifier scoring succeeds, and `classifier_score >= artifact
     threshold`.
3. `FILTER` should fail closed for model admission.
   - Recommendation: in `FILTER`, missing artifacts, invalid features, failed
     encoding, failed classifier scoring, or unavailable model state should block
     deterministic entries. `SHADOW` remains fail-open.
4. Threshold source remains the artifact.
   - Recommendation: do not add a threshold override input in Phase 6. Threshold
     experiments should produce a new exported artifact so tester results remain
     reproducible.
5. Blocked filter signals produce no broker outcome row.
   - Recommendation: record the prediction/filter decision, close the local
     pending signal with terminal reason `ML_FILTER_BLOCKED`, and do not create a
     broker-confirmed outcome because no broker position existed.

## Prerequisites

- Phase 5 acceptance is `PASS` for Ubuntu/Wine runtime and parity:
  `docs/research/deterministic-signal-mql5-shadow-inference-acceptance.md`.
- Runtime artifact remains available under MT5 `Common\Files`:

```text
Common\Files\DeterministicSignalML\model_exports\xgb_test_1_export_v1
```

- Human explicitly approves that model recommendations may affect broker
  admission in Strategy Tester.
- No custom MQL5 test harness or CI is added. Validation remains MetaEditor
  compile plus human-in-the-loop Strategy Tester/chart verification.
- Final real compile uses the project helper and treats warnings as failures:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework \
  --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 \
  --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase-06-filter-inference.log \
  --mode compile \
  --timeout 180
```

## Non-Goals

- No live deployment approval.
- No new model training, threshold tuning, feature changes, or artifact format
  rewrite.
- No Python calls from MQL5 runtime.
- No PostgreSQL or external service dependency.
- No model-controlled exits, lot sizing, SL/TP, take-profit logic, trailing
  behavior, drawdown controls, session controls, or broker reconciliation.
- No behavior change when `ML_Inference_Mode=ML_INFERENCE_DISABLED`.
- No behavior change to `SHADOW` except internal refactors required to share the
  scorer safely.

## Sprint 1: Runtime Contract And Guardrails

**Goal**: Add the Phase 6 public contract without enabling filter behavior yet.
**Commit**: `feat: add ml filter mode contract`
**Demo/Validation**:
- Static search shows enum ordinal compatibility is preserved:
  `ML_INFERENCE_DISABLED=0`, `ML_INFERENCE_SHADOW=1`,
  `ML_INFERENCE_FILTER=2`.
- `ML_Inference_Mode` default remains `ML_INFERENCE_DISABLED`.
- Documentation states `FILTER` is Strategy Tester admission filtering, not live
  deployment.
- No broker-send callsite is changed in this sprint.

### Task 1.1: Add Filter Enum Value

- **Location**: `services/core/enums.mqh`
- **Description**: Add `ML_INFERENCE_FILTER = 2` while preserving existing enum
  numeric values.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Existing `DISABLED` and `SHADOW` ordinals do not change.
  - No removed or legacy strategy vocabulary is introduced.
- **Validation**:
  - `rg -n "ML_INFERENCE_" services/core/enums.mqh services`

### Task 1.2: Update Mode Token Logging

- **Location**: `services/trading_signals/execution_logging.mqh`
- **Description**: Update mode-token helpers and query-debug fields to render
  `ML_INFERENCE_FILTER` clearly.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Query debug and compact logs show `FILTER`.
  - Unknown mode behavior remains explicit.
- **Validation**:
  - `rg -n "ExecutionMLInferenceModeToken|ML_INFERENCE_FILTER|FILTER" services`

### Task 1.3: Add Tester-Only Filter Guard Helper

- **Location**:
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Add helpers that distinguish disabled, shadow, and filter
  behavior. Add a tester-only guard for `FILTER` without changing broker
  admission yet.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - `SHADOW` remains enabled when mode is `ML_INFERENCE_SHADOW`.
  - `FILTER` can initialize model artifacts for scoring but is explicitly
    identifiable as filter mode.
  - Non-tester `FILTER` behavior is routed through one helper and documented as
    pending the approved policy.
- **Validation**:
  - `rg -n "ML_INFERENCE_FILTER|Filter|filter" services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`

### Task 1.4: Document Contract

- **Location**:
  - `README.md`
  - `AGENTS.md`
  - `docs/plans/deterministic-signal-ml-roadmap.md`
- **Description**: Document that Phase 6 may affect Strategy Tester broker
  admission only after existing safety gates pass.
- **Dependencies**: Tasks 1.1 through 1.3.
- **Acceptance Criteria**:
  - Docs say `FILTER` is not a live-deployment approval.
  - Docs say `FILTER` cannot bypass license/session/spread/margin/protection
    controls.
- **Validation**:
  - `rg -n "FILTER|Phase 6|broker admission|Strategy Tester" README.md AGENTS.md docs/plans/deterministic-signal-ml-roadmap.md`

## Sprint 2: Shared ML Decision API

**Goal**: Extract the Phase 5 scorer into a reusable decision API while keeping
`SHADOW` output and parity unchanged.
**Commit**: `refactor: extract ml inference decision scorer`
**Demo/Validation**:
- `SHADOW` still writes prediction/outcome rows with the same required feature
  and score columns.
- `compare_shadow_predictions.py` remains usable against a fresh or existing
  shadow run.
- No filter blocks can occur yet.

### Task 2.1: Introduce Decision Result Struct

- **Location**:
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Add a compact decision struct for model availability, feature
  validity, classifier/regressor scores, threshold, recommendation, reason, and
  whether the model may admit an entry.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Struct has explicit default/copy constructors if stored or assigned in ways
    MQL5 requires.
  - Defaults are safe: not scored, not admitted.
- **Validation**:
  - Static review for MQL5 constructor style and no aggregate initialization.

### Task 2.2: Extract Scoring From Prediction Recording

- **Location**:
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Split scoring from TSV row recording. `SHADOW` recording
  should call the shared scorer, then persist the same row shape as Phase 5.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `DeterministicSignalMLShadowRecordPrediction` still records exactly one
    prediction per deterministic broker-entered signal.
  - Score/recommendation semantics match Phase 5.
  - Invalid feature counters and unavailable counters remain bounded and
    meaningful.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/compare_shadow_predictions.py`
  - Run the comparator against an available Phase 5 shadow run if the generated
    files are still present.

### Task 2.3: Preserve Shadow Outcome Behavior

- **Location**:
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Confirm outcome recording still requires a broker-confirmed
  outcome and does not attempt to synthesize outcomes for untraded signals.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Existing broker-confirmed outcomes still produce outcome rows.
  - Pending canceled signals without broker exposure still do not produce
    broker outcome rows.
- **Validation**:
  - `rg -n "SignalHasBrokerConfirmedOutcome|MLShadowRecordOutcome|ML_FILTER_BLOCKED" services/trading_signals`

## Sprint 3: Broker Admission Split

**Goal**: Create a safe insertion point between existing broker eligibility and
the real broker send.
**Commit**: `refactor: split execution admission from broker send`
**Demo/Validation**:
- `DISABLED` and `SHADOW` behavior remain equivalent to the current flow.
- Existing local broker guardrails still run before any model filter decision.
- No `FILTER` block is enabled yet.

### Task 3.1: Add Trade Admission Context

- **Location**:
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Add a small context or helper return path that packages
  `BrokerExecutionSnapshot`, `BrokerExecutionEligibility`, normalized volume,
  and composed order comment after `EvaluateLocalExecutionLegEligibility`.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Existing spread, stop/freeze, volume, margin, market status, session,
    protection, direction, concurrency, and algo-trading checks remain in the
    same source-of-truth helper.
  - Eligibility failure logging remains `LOCAL_EXECUTION_BLOCK`.
- **Validation**:
  - `rg -n "EvaluateLocalExecutionLegEligibility|LOCAL_EXECUTION_BLOCK|BrokerExecutionEligibility" services/trading_signals`

### Task 3.2: Split Broker Send Application

- **Location**: `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Move the actual `g_position.Buy/Sell` send and post-send
  broker reconciliation into a helper that accepts a previously validated
  admission context.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Broker-send failure behavior, retcode logging, no-money debug stop, and
    `MarketStatusRegisterBrokerFailure` are unchanged.
  - Successful sends still update leg status, entry price, ticket, comment, and
    broker snapshot reconciliation.
- **Validation**:
  - Static diff review around `ExecuteExecutionLegTrade`.
  - `rg -n "BROKER_SEND_FAILED|ResolvePositionTicketFromDeal|ApplyBrokerPositionSnapshotToExecutionLeg" services/trading_signals/execution_lifecycle.mqh`

### Task 3.3: Route Existing Entrypoints Through The Split

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Keep current callsites using the new admission/send split
  without changing admission outcomes.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Deterministic and non-deterministic execution paths still call through one
    execution lifecycle API.
  - No model decision can block in this sprint.
- **Validation**:
  - `rg -n "ExecuteExecutionLegTrade\\(" services/trading_signals`

## Sprint 4: Filter Admission Gate

**Goal**: Enable `FILTER` mode to block deterministic entries after all existing
broker eligibility checks pass and before the broker send.
**Commit**: `feat: gate deterministic entries with ml filter`
**Demo/Validation**:
- In `FILTER`, `ALLOW` proceeds to the existing broker send.
- In `FILTER`, `BLOCK` closes/cancels the pending deterministic signal before
  any broker send.
- In `DISABLED` and `SHADOW`, admission behavior remains unchanged.

### Task 4.1: Add Filter Decision Helper

- **Location**:
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Add `FILTER`-specific helper that evaluates the shared ML
  decision and returns allow/block plus a compact reason.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `ALLOW` requires scored classifier probability greater than or equal to the
    artifact threshold.
  - `BLOCK` reasons distinguish model score below threshold, unavailable model,
    invalid features, failed encoding, failed classifier scoring, and tester-only
    guard violations.
  - `SHADOW` remains fail-open and observational.
- **Validation**:
  - Static review of all returns for fail-open/fail-closed mode separation.

### Task 4.2: Insert Filter Gate Before Broker Send

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
- **Description**: Insert the filter gate only for deterministic entries after
  broker eligibility passes and before the send helper is invoked.
- **Dependencies**: Sprint 3, Task 4.1.
- **Acceptance Criteria**:
  - Existing broker constraints run before the model can make a filter decision.
  - The model cannot make a blocked signal appear broker-confirmed.
  - The model cannot alter lot, price, SL/TP, or broker snapshot data.
- **Validation**:
  - Static review around the deterministic entry block in
    `UpdateDeterministicExecutionLifecycle`.
  - `rg -n "ML_FILTER|ExecuteExecutionLegTrade|EvaluateLocalExecutionLegEligibility" services/trading_signals`

### Task 4.3: Define Filter-Blocked Lifecycle State

- **Location**:
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Close blocked pending signals locally with terminal reason
  `ML_FILTER_BLOCKED` without broker exposure. Preserve broker-confirmed outcome
  requirements.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Filter-blocked signals do not call `g_position.Buy/Sell`.
  - Filter-blocked signals do not write broker outcome rows.
  - Filter-blocked signals are visible in logs and summary counters.
- **Validation**:
  - `rg -n "ML_FILTER_BLOCKED|SignalHasBrokerConfirmedOutcome|g_position\\.Buy|g_position\\.Sell" services`

### Task 4.4: Add Compact Filter Telemetry

- **Location**:
  `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
- **Description**: Add filter counters and logs without dumping full features or
  artifact data.
- **Dependencies**: Task 4.3.
- **Acceptance Criteria**:
  - Summary distinguishes prediction rows, outcome rows, filter allow rows,
    filter block rows, invalid feature blocks, unavailable blocks, and export
    status.
  - Query debug has compact `ML_FILTER_ALLOW` and `ML_FILTER_BLOCK` events.
  - Existing `compare_shadow_predictions.py` can still read prediction rows.
- **Validation**:
  - Static review of TSV headers and optional-column compatibility.

## Sprint 5: Validation Tooling And Operator Runbook

**Goal**: Provide compact tooling and documentation to validate filter runs
without reading full TSVs or Strategy Tester logs.
**Commit**: `test: add ml filter run validation`
**Demo/Validation**:
- Python tooling can summarize a filter run and verify score parity for scored
  predictions.
- Runbook explains the exact Strategy Tester sequence for `DISABLED`,
  `SHADOW`, and `FILTER` comparisons.

### Task 5.1: Extend Prediction Comparator Compatibility

- **Location**: `tools/deterministic_signal_ml/compare_shadow_predictions.py`
- **Description**: Keep the existing command working while tolerating optional
  Phase 6 columns such as runtime mode, admission action, and filter reason.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Existing Phase 5 shadow runs still compare.
  - Phase 6 filter runs with prediction rows compare against the same Python
    artifact scorer.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/compare_shadow_predictions.py`

### Task 5.2: Add Filter Run Summarizer

- **Location**: `tools/deterministic_signal_ml/`
- **Description**: Add a compact Python script, or extend existing tooling, to
  summarize filter allow/block counts, unavailable blocks, invalid feature
  blocks, broker-confirmed outcomes, and header duplication.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Script exits nonzero when required files are missing, row counts are
    inconsistent, duplicate headers exist, or summary counters disagree with row
    data.
  - Script prints only compact counts and final status.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`

### Task 5.3: Document Filter Tester Workflow

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `docs/environment/mt5-agentic-workflows.md`
  - `README.md`
- **Description**: Document how to copy artifacts, enable `FILTER`, run Strategy
  Tester, compare prediction parity, summarize filter decisions, and interpret
  blocked signals.
- **Dependencies**: Tasks 5.1 and 5.2.
- **Acceptance Criteria**:
  - Docs explicitly say `FILTER` is not approved for live deployment.
  - Docs say full TSVs, model JSON, and full tester logs must not be pasted into
    chat.
  - Docs name the expected Common Files paths and validation commands.
- **Validation**:
  - `rg -n "ML_INFERENCE_FILTER|filter run|compare_shadow_predictions|Strategy Tester" README.md tools/deterministic_signal_ml/README.md docs/environment/mt5-agentic-workflows.md`

## Sprint 6: Final Compile, Tester Evidence, And Handoff

**Goal**: Validate Phase 6 end to end and record acceptance evidence.
**Commit**: `docs: record ml filter inference acceptance`
**Demo/Validation**:
- Final MetaEditor compile passes with `0 errors, 0 warnings`.
- Human-in-the-loop Strategy Tester produces a `FILTER` run with nonzero scored
  prediction rows and expected allow/block counters.
- Comparator passes against scored prediction rows.
- Filter run summary passes.
- Evidence doc states PASS or remaining blockers.

### Task 6.1: Run Final Static Sweeps

- **Location**: repository root
- **Description**: Search for stale shadow-only wording, accidental live-filter
  claims, and any route where ML can bypass broker/risk controls.
- **Dependencies**: Sprints 1 through 5.
- **Acceptance Criteria**:
  - `FILTER` docs and code do not imply live approval.
  - No removed legacy strategy terms are reintroduced.
  - Broker/risk safety controls remain the source of truth.
- **Validation**:
  - `rg -n "FILTER|ML_FILTER|ML_INFERENCE|shadow-only|broker admission|live" README.md AGENTS.md docs services`

### Task 6.2: Run Final MetaEditor Compile

- **Location**:
  - `HFT_Grid_AI.mq5`
  - `logs/compile/phase-06-filter-inference.log`
- **Description**: Run the preferred real compile helper on Ubuntu/Wine.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Helper result is `PASS`.
  - MetaEditor log reports `0 errors, 0 warnings`.
  - `.ex5` timestamp changes.
- **Validation**:
  - Preferred compile command from this plan.

### Task 6.3: Run Shadow Regression

- **Location**:
  - MT5 Common Files `DeterministicSignalML/shadow_runs/<shadow_run_id>`
  - `tools/deterministic_signal_ml/compare_shadow_predictions.py`
- **Description**: Run `ML_INFERENCE_SHADOW` after the refactor and validate
  Python parity did not regress.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Nonzero prediction and outcome rows.
  - `invalid_feature_rows=0` unless explicitly documented.
  - Comparator result is `PASS`.
- **Validation**:
  - `compare_shadow_predictions.py --export-id xgb_test_1_export_v1 --shadow-run-path <shadow_run_path>`

### Task 6.4: Run Filter Tester Validation

- **Location**:
  - MT5 Common Files `DeterministicSignalML/<filter-run-root>/<filter_run_id>`
  - `tools/deterministic_signal_ml/`
- **Description**: Run Strategy Tester with `ML_INFERENCE_FILTER`, summarize
  filter decisions, and compare scored predictions against Python.
- **Dependencies**: Task 6.3.
- **Acceptance Criteria**:
  - Nonzero scored prediction rows.
  - Both allow/block counts are reported, or a one-sided distribution is
    explicitly explained by the data.
  - No `BLOCK` decision creates a broker position.
  - `ALLOW` decisions still require existing broker/risk gates and may still be
    blocked by broker send failures.
  - Comparator result is `PASS`.
- **Validation**:
  - Filter run summarizer result is `PASS`.
  - Comparator result is `PASS`.
  - Human reviews Strategy Tester summary for expected behavioral delta.

### Task 6.5: Record Acceptance Evidence

- **Location**:
  `docs/research/deterministic-signal-mql5-filter-inference-acceptance.md`
- **Description**: Record compact evidence for compile, shadow regression,
  filter run counters, parity, and remaining Windows/live limitations.
- **Dependencies**: Task 6.4.
- **Acceptance Criteria**:
  - Evidence includes paths, counts, status lines, and selected failure lines
    only.
  - Evidence states whether Phase 6 is `PASS` for Ubuntu/Wine Strategy Tester.
  - Evidence states Windows validation and live deployment status separately.
- **Validation**:
  - `rg -n "Phase 6|FILTER|PASS|FAIL|shadow|parity|0 errors, 0 warnings" docs/research/deterministic-signal-mql5-filter-inference-acceptance.md`

## Testing Strategy

- Per sprint: use focused static search, diff review, and Python syntax checks
  for changed Python tooling.
- Phase-end: run one real MetaEditor compile through `tools/mt5/compile_mt5.py`
  and treat warnings as failures.
- Runtime: use human-in-the-loop Strategy Tester for:
  - `DISABLED` baseline sanity.
  - `SHADOW` regression parity.
  - `FILTER` behavioral validation.
- Python parity: use `compare_shadow_predictions.py` against prediction rows
  from shadow/filter runs.
- Filter summary: use compact tooling to verify row counts, allow/block counts,
  unavailable/invalid counters, and duplicate-header absence.

## Acceptance Gate

Phase 6 passes only if all of the following are true:

- `ML_Inference_Mode` default remains `ML_INFERENCE_DISABLED`.
- `DISABLED` and `SHADOW` behavior are preserved.
- `FILTER` can affect deterministic Strategy Tester broker admission only.
- Existing license, session, spread, broker constraints, volume normalization,
  margin, drawdown/protection, direction, concurrency, magic-number scope, and
  broker reconciliation controls remain in force.
- Model `BLOCK` decisions occur after existing local broker eligibility checks
  and before real broker send.
- Model `ALLOW` never bypasses broker send failure handling.
- Missing/invalid model state follows the approved filter policy.
- Prediction parity against Python passes within Phase 5 tolerances.
- Filter summary evidence is compact and internally consistent.
- Ubuntu/Wine compile is clean.
- Windows status is documented separately.

## Potential Risks And Gotchas

- **Unsafe insertion point**: Filtering before broker eligibility can make model
  metrics look better by blocking signals that broker/risk controls would have
  blocked anyway. Mitigation: split broker admission and place ML after
  eligibility, before send.
- **False unfiltered tester runs**: Fail-open in `FILTER` can silently produce
  baseline results when the artifact is missing. Mitigation: recommended
  fail-closed policy for `FILTER`; `SHADOW` remains fail-open.
- **Live-mode ambiguity**: A user could select `FILTER` on a live chart.
  Mitigation: keep Phase 6 tester-only and require a clear non-tester guard.
- **Outcome interpretation**: Model-blocked signals have no broker-confirmed
  outcome, so per-signal realized P/L cannot be known from the filtered run.
  Mitigation: analyze filter behavior through tester result deltas and keep
  blocked decisions separate from broker outcomes.
- **Schema drift**: Adding filter columns could break parity tooling if the
  script expects exact headers. Mitigation: only add optional columns or keep the
  required Phase 5 columns stable.
- **Function naming drift**: The current module name says shadow inference even
  though Phase 6 adds filter behavior. Mitigation: prefer minimal API additions
  during Phase 6; document the broader runtime role or schedule a separate
  naming cleanup if the implementation becomes confusing.
- **Hot-path cost**: Filtering adds scoring before entry. Mitigation: load model
  once on init, score only at deterministic entry admission, and keep logs
  compact.
- **Reconciliation risk**: A blocked signal must not appear as broker-confirmed.
  Mitigation: close pending local state without ticket/volume and keep broker
  outcome export guarded by `SignalHasBrokerConfirmedOutcome`.

## Rollback Plan

- Revert Phase 6 enum/input/logging changes:
  - `services/core/enums.mqh`
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_signals/execution_logging.mqh`
- Revert shared scorer/filter gate changes:
  - `services/trading_signals/deterministic_signal_ml_shadow_inference.mqh`
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lifecycle.mqh`
  - `services/trading_signals/execution_broker_context.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
- Revert Phase 6 Python tooling under `tools/deterministic_signal_ml/`.
- Revert Phase 6 docs and acceptance evidence.
- Because Phase 6 only filters before broker send, rollback should not require
  broker-state repair. Any open broker positions from prior `ALLOW` decisions
  remain normal EA-managed positions and must be handled by existing lifecycle
  and broker reconciliation.
