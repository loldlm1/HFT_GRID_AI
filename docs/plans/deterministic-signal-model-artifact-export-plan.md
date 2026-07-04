# Plan: Deterministic Signal Model Artifact Export

**Generated**: 2026-07-04
**Estimated Complexity**: Medium-High
**Risk Level**: Low for EA trading behavior; Medium for future inference
correctness if tree export or feature ordering is wrong.

## Overview

Implement Phase 4 of the deterministic signal ML roadmap: export the trained
Phase 3 XGBoost models into a compact, MT5-readable artifact folder.

This phase should remain Python-only plus documentation. It should not load the
model in the EA, add EA inputs, run Strategy Tester inference, call Python from
MQL5, connect to PostgreSQL, or affect broker admission. The purpose is to
create a deterministic file contract that Phase 5 can load during `OnInit`.

Recommended approach:

- Use the Phase 3 model folder as input.
- Use XGBoost `dump_model(..., dump_format="json")` or `get_dump(...,
  dump_format="json")` as the tree source because it is intended for human
  inspection and custom interpretation.
- Keep XGBoost `save_model()` JSON as the Python reload artifact, not as the
  runtime MT5 contract.
- Export simple TSV files for MQL5 parsing, plus optional JSON sidecars for
  Python audit.
- Validate export correctness with a pure-Python artifact scorer before any
  MQL5 loader exists.
- Treat `target_is_win` classifier export as the primary acceptance target.
  Export the regressor only after classifier parity is proven.

## Documentation Basis

- XGBoost `save_model("model.json")` stores a trained model in JSON/UBJSON for
  XGBoost reload.
- XGBoost `dump_model(..., dump_format="json")` produces a more human-readable
  tree dump for visualization/interpretation, but it is not reloadable by
  XGBoost.
- Phase 3 currently saves booster JSON files:
  - `classifier_xgboost.json`
  - `regressor_xgboost.json`
- Phase 3 currently emits deterministic feature order in `feature_encoder.json`
  and `model_manifest.json`.

## Non-Goals

- No MQL5 runtime loader.
- No EA inputs.
- No Strategy Tester inference.
- No trade filtering.
- No Python execution from MQL5.
- No PostgreSQL.
- No generated `.mqh` model.
- No ONNX/CoreML/third-party model runtime.
- No generated model artifacts committed to git.

## Proposed File Layout

Python tooling:

```text
tools/deterministic_signal_ml/
  export_model_artifact.py
  model_artifact_contract.py
  model_artifact_validator.py
```

Generated output:

```text
artifacts/model_exports/<export_id>/
  model_manifest.tsv
  model_manifest.json
  feature_map.tsv
  classifier_trees.tsv
  regressor_trees.tsv
  threshold_policy.tsv
  parity_report.json
  parity_report.md
```

`artifacts/model_exports/` must be ignored by git.

Future MT5 placement, not default for this phase:

```text
Common\Files\DeterministicSignalML\models\<model_id>\
```

## Artifact Contract Recommendation

### `model_manifest.tsv`

Use key/value TSV for MQL5 simplicity:

```text
key	value
artifact_schema_version	1
exporter_version	phase4.model_exporter.v1
model_id	xgb_test_1
dataset_id	test_dataset_1
phase1_schema_version	1
phase2_builder_version	phase2.dataset_builder.v1
phase3_trainer_version	phase3.xgboost_trainer.v1
encoded_feature_count	49
classifier_tree_count	109
classifier_objective	binary:logistic
classifier_base_score	...
threshold_probability	0.60
research_only	true
```

### `feature_map.tsv`

Stable feature order:

```text
encoded_index	encoded_feature_name	source_column	encoding_type	category
0	strategy_id	strategy_id	numeric	
12	strategy_label=S1	strategy_label	one_hot	S1
```

### `classifier_trees.tsv` / `regressor_trees.tsv`

One row per tree node:

```text
model_role	tree_index	node_index	node_type	feature_index	threshold	left_child	right_child	default_left	leaf_value
classifier	0	0	split	4	45.6	1	2	0	
classifier	0	7	leaf					0.013879637
```

Rules:

- `node_type` is `split` or `leaf`.
- `feature_index` references `feature_map.tsv`.
- `default_left` preserves XGBoost missing-value direction.
- Leaf values must be the values used by XGBoost for prediction after learning
  rate application.
- Classifier scorer must reproduce XGBoost `predict_proba` for class `1`.
- Regressor scorer must reproduce XGBoost `predict` when regressor export is
  enabled.

### `threshold_policy.tsv`

Research metadata only:

```text
threshold	selected_rows	win_rate	mean_profit_r	net_profit_r	source
0.60	34	0.6764705882	0.3465147059	11.7815	phase3_holdout_research
```

This is not an EA allow/block rule in Phase 4.

## Sprint 1: Export Contract And CLI Boundary

**Goal**: Define the Phase 4 export boundary and add a non-training exporter
skeleton.
**Commit**: `feat: define deterministic signal model export contract`
**Demo/Validation**:
- CLI accepts a Phase 3 model folder and an output export ID.
- Missing model folders fail clearly.
- Generated exports remain ignored by git.

### Task 1.1: Add Artifact Ignore Rule

- **Location**:
  - `.gitignore`
- **Description**: Ignore generated model export folders.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - `artifacts/model_exports/` is ignored.
  - Generated export artifacts cannot be accidentally committed.
- **Validation**:
  - `git check-ignore -v artifacts/model_exports/example/model_manifest.tsv`

### Task 1.2: Add Export Contract Constants

- **Location**:
  - `tools/deterministic_signal_ml/model_artifact_contract.py`
- **Description**: Define artifact schema version, filenames, required manifest
  keys, and required TSV headers.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Contract file has no dependency on XGBoost.
  - Headers are centralized and reused by exporter/validator.
  - Artifact schema version starts at `1`.
- **Validation**:
  - Python syntax compile.

### Task 1.3: Add Exporter Skeleton

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
- **Description**: Add CLI parsing and input checks.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Accepts `--model-id` or `--model-path`.
  - Accepts `--model-root`, defaulting to `artifacts/models`.
  - Accepts `--export-id`.
  - Accepts `--output-root`, defaulting to `artifacts/model_exports`.
  - Accepts `--overwrite`.
  - Fails if `model_manifest.json`, `feature_encoder.json`, or
    `classifier_xgboost.json` are missing.
- **Validation**:
  - Run `--help`.
  - Run against missing model folder and confirm clear nonzero error.
  - Run against `artifacts/models/xgb_test_1` and confirm input summary.

## Sprint 2: Feature Map And Manifest Export

**Goal**: Export the deterministic feature contract and runtime manifest without
tree conversion yet.
**Commit**: `feat: export deterministic signal feature map`
**Demo/Validation**:
- `xgb_test_1` produces `model_manifest.tsv`, `model_manifest.json`, and
  `feature_map.tsv`.
- Feature count and order match Phase 3 exactly.

### Task 2.1: Export Feature Map

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
  - `tools/deterministic_signal_ml/model_artifact_contract.py`
- **Description**: Convert `feature_encoder.json` into a stable TSV map.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Numeric passthrough features preserve their original order.
  - One-hot category features preserve the Phase 3 encoded feature order.
  - Missing category policy is recorded when present.
  - Feature indices are contiguous from `0`.
- **Validation**:
  - Compare exported feature names to Phase 3 `encoded_feature_names`.

### Task 2.2: Export Runtime Manifest

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
- **Description**: Create MQL5-readable key/value manifest TSV and Python audit
  JSON.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Includes model ID, dataset ID, source run IDs, config IDs, schema versions,
    exporter version, feature count, model role availability, and research-only
    flag.
  - Includes the selected research threshold from Phase 3 when present.
  - Does not mark artifact as live-trading approved.
- **Validation**:
  - Manifest values match Phase 3 `model_manifest.json`.
  - `research_only` is `true`.

## Sprint 3: Classifier Tree Export And Parity

**Goal**: Export the classifier trees to TSV and prove Python artifact scoring
matches XGBoost.
**Commit**: `feat: export deterministic signal classifier trees`
**Demo/Validation**:
- `classifier_trees.tsv` is generated.
- Pure-Python artifact scorer reproduces classifier probabilities on
  `test_dataset_1` holdout within a strict tolerance.

### Task 3.1: Create XGBoost Dump Parser

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
- **Description**: Use XGBoost booster dump JSON as input and normalize split
  and leaf nodes into flat rows.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Reads classifier booster from `classifier_xgboost.json`.
  - Uses the booster dump JSON, not the internal save-model JSON, as the primary
    export source.
  - Preserves tree index, node index, split feature index, threshold, left child,
    right child, default/missing direction, and leaf value.
  - Fails clearly for unsupported categorical split types.
- **Validation**:
  - Export row count equals total nodes from the dumped classifier trees.
  - Feature indices are within `feature_map.tsv`.

### Task 3.2: Add Pure-Python Artifact Scorer

- **Location**:
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
- **Description**: Score rows from exported TSV artifacts without calling
  XGBoost prediction APIs.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Loads `model_manifest.tsv`, `feature_map.tsv`, and
    `classifier_trees.tsv`.
  - Applies the same one-hot feature encoding contract as Phase 3.
  - Applies classifier objective transform for `binary:logistic`.
  - Handles missing values according to exported default direction.
- **Validation**:
  - Syntax compile.
  - Unit-like validation through a small in-memory tree fixture inside the
    validator module or a temporary script, without adding MQL5 test harnesses.

### Task 3.3: Add Classifier Parity Report

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
- **Description**: Rebuild holdout features from the Phase 2 dataset and compare
  artifact scorer probabilities to XGBoost probabilities.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Export command accepts `--dataset-id` or `--dataset-path` for parity
    validation.
  - Reports max absolute probability error, mean absolute probability error,
    row count, and threshold decision agreement.
  - Fails export if max absolute error exceeds tolerance.
  - Recommended initial tolerance: `1e-6`; relax only with documented evidence.
- **Validation**:
  - Run export against `xgb_test_1` and `test_dataset_1`.
  - Confirm `parity_report.json` status is `OK`.

## Sprint 4: Regressor Export And Threshold Policy

**Goal**: Export secondary regressor trees and threshold policy after classifier
export is proven.
**Commit**: `feat: export deterministic signal regressor trees`
**Demo/Validation**:
- `regressor_trees.tsv` is generated when regressor artifact exists.
- Regressor parity is reported separately from classifier parity.
- Threshold metadata is exported as research-only.

### Task 4.1: Export Regressor Trees

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
- **Description**: Reuse the tree export format for `regressor_xgboost.json`.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Missing regressor file can fail clearly or be disabled through an explicit
    flag, but cannot silently produce partial artifacts.
  - Regressor tree rows use `model_role=regressor`.
  - Regressor scoring uses direct summed prediction, not logistic transform.
- **Validation**:
  - Run export against `xgb_test_1`.
  - Confirm regressor max absolute prediction error is within tolerance.

### Task 4.2: Export Threshold Policy

- **Location**:
  - `tools/deterministic_signal_ml/export_model_artifact.py`
- **Description**: Export Phase 3 threshold recommendation as metadata only.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - `threshold_policy.tsv` includes probability threshold, selected rows, win
    rate, mean/net R, source, and `research_only=true`.
  - Export fails if threshold policy is missing unless an explicit
    `--allow-missing-threshold` flag is used.
  - Manifest states that threshold is not active in the EA.
- **Validation**:
  - `xgb_test_1` exports the `0.60` research threshold from Phase 3.

## Sprint 5: Readback, Documentation, And Acceptance Evidence

**Goal**: Produce a complete export folder that is ready for Phase 5 MQL5 loader
planning.
**Commit**: `docs: document deterministic signal model artifact export`
**Demo/Validation**:
- Export command produces a complete artifact folder.
- Validator reads the folder back independently.
- Documentation clearly states no EA inference exists yet.

### Task 5.1: Add Artifact Readback Command

- **Location**:
  - `tools/deterministic_signal_ml/model_artifact_validator.py`
- **Description**: Add a CLI or callable validator that checks generated files
  without reading the original XGBoost model.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Validates required files and headers.
  - Validates feature count, tree row consistency, child references, and
    manifest keys.
  - Validates parity report status if present.
- **Validation**:
  - Run validator against the generated `xgb_test_1` export.

### Task 5.2: Document Operator Workflow

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `README.md`
- **Description**: Document export command, output files, validation, and
  limitations.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Explains that Phase 4 is artifact export only.
  - Explains that TSV artifacts are intended for future MQL5 loading.
  - Explains that Python booster JSON remains separate from MT5-readable TSV.
  - States no Strategy Tester inference or trade filtering exists yet.
- **Validation**:
  - Documentation review.

### Task 5.3: Record Acceptance Evidence

- **Location**:
  - `docs/research/deterministic-signal-model-artifact-export-acceptance.md`
- **Description**: Record accepted export run details.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Includes dataset ID, model ID, export ID, row counts, feature count, tree
    counts, parity tolerances, max/mean errors, and generated files.
  - States no MetaEditor compile was required unless MQL5 files were touched.
  - Confirms generated export artifacts are ignored by git.
- **Validation**:
  - `git status --short` shows no generated artifact files.

## Testing Strategy

No MT5 compile is required if Phase 4 remains Python-only. If a later decision
adds any MQL5 loader stub in this phase, MetaEditor compile becomes mandatory at
phase end.

Required validation:

```powershell
.\.venv\Scripts\python.exe -m py_compile `
  tools\deterministic_signal_ml\model_artifact_contract.py `
  tools\deterministic_signal_ml\model_artifact_validator.py `
  tools\deterministic_signal_ml\export_model_artifact.py
```

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\export_model_artifact.py `
  --model-id xgb_test_1 `
  --dataset-id test_dataset_1 `
  --export-id xgb_test_1_export_v1 `
  --overwrite
```

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\model_artifact_validator.py `
  --export-id xgb_test_1_export_v1
```

Additional checks:

- Generated TSV headers match contract constants.
- Feature map order exactly matches Phase 3 encoded feature order.
- Classifier parity report is `OK`.
- Regressor parity report is `OK` when regressor export is enabled.
- `artifacts/model_exports/` is ignored by git.
- No generated export artifacts are committed.

## Potential Risks And Gotchas

- **Tree format drift**: XGBoost save-model JSON is not the same as dump JSON.
  Mitigation: export from `dump_model/get_dump` JSON and record XGBoost version.
- **Base score ambiguity**: Binary logistic probability parity depends on the
  correct base score/raw margin handling.
  Mitigation: compare artifact scorer against XGBoost output margins and
  probabilities before accepting the export.
- **Feature order drift**: A single feature index mismatch invalidates all
  predictions.
  Mitigation: feature map must be derived only from Phase 3
  `feature_encoder.json`; parity validation must fail on mismatch.
- **Missing/default direction**: XGBoost missing-value direction must be
  preserved.
  Mitigation: export `default_left` and validate rows with explicit missing
  values where practical.
- **Unsupported split type**: Native categorical splits would complicate MQL5
  inference.
  Mitigation: fail export if any categorical split is detected; Phase 3 uses
  deterministic one-hot encoding.
- **Regressor scope creep**: Regressor export is useful but not required for the
  first Strategy Tester allow/block shadow flow.
  Mitigation: classifier parity is the release gate; regressor parity is
  secondary.
- **Artifact placement confusion**: Local artifacts under `artifacts/` are not
  automatically available to MT5.
  Mitigation: keep Phase 4 local by default and let Phase 5 decide Common Files
  loading/copy workflow.
- **Threshold overfitting**: The Phase 3 threshold was selected on a short
  holdout.
  Mitigation: export it as `research_only=true`; do not treat it as production
  policy.

## Rollback Plan

- Remove Phase 4 Python files from `tools/deterministic_signal_ml/`.
- Remove `artifacts/model_exports/` from `.gitignore`.
- Remove Phase 4 documentation and acceptance evidence.
- Keep Phase 1-3 artifacts and tooling unchanged.

## Open Questions With Recommendations

1. **Should Phase 4 export classifier only or classifier plus regressor?**
   - **Recommendation**: make classifier export mandatory and regressor export
     secondary in Sprint 4. Phase 5 can start with classifier-only shadow
     inference even if regressor is available.

2. **Should the exporter copy artifacts to MT5 Common Files now?**
   - **Recommendation**: no automatic copy in Phase 4. Keep output under
     `artifacts/model_exports/`; Phase 5 should decide exact Common Files
     placement when the MQL5 loader is implemented.

3. **Should runtime manifest be TSV, JSON, or both?**
   - **Recommendation**: both. Use `model_manifest.tsv` as the future MQL5
     runtime contract and `model_manifest.json` as a richer Python audit
     sidecar.
