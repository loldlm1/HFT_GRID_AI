# Deterministic Signal Model Artifact Export Acceptance

**Date**: 2026-07-04
**Phase**: 4 - Model Artifact Export

## Validation Summary

Phase 4 was implemented as local Python export tooling under
`tools/deterministic_signal_ml/`. It converts Phase 3 XGBoost booster artifacts
into deterministic TSV files intended for future MQL5 loading.

This phase does not modify MQL5, add EA inputs, load models in `OnInit`, run
Strategy Tester inference, call Python from the EA, connect to PostgreSQL, or
change trading behavior.

## Environment

- Python: bundled Codex runtime Python 3.12.13
- XGBoost: 3.1.2 installed into local `.venv`
- Export output root: `artifacts/model_exports/`

## Commands Run

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

## Accepted Export

- Dataset ID: `test_dataset_1`
- Model ID: `xgb_test_1`
- Export ID: `xgb_test_1_export_v1`
- Encoded feature count: 49
- Classifier effective tree count: 84
- Classifier TSV node rows: 1168
- Regressor effective tree count: 47
- Regressor TSV node rows: 683
- Threshold probability: 0.60
- `research_only`: `true`
- `mt5_runtime_ready`: `true`

Generated files:

- `model_manifest.tsv`
- `model_manifest.json`
- `feature_map.tsv`
- `classifier_trees.tsv`
- `regressor_trees.tsv`
- `threshold_policy.tsv`
- `parity_report.json`
- `parity_report.md`

## Parity Results

Classifier parity against XGBoost holdout predictions:

- Rows: 565
- Tolerance: `1e-6`
- Max absolute probability error: `6.885893089059181e-08`
- Mean absolute probability error: `2.0779019137875427e-08`
- Threshold decision agreement at 0.60: `1.0`

Regressor parity against XGBoost holdout predictions:

- Rows: 565
- Tolerance: `1e-6`
- Max absolute prediction error: `7.749070718432449e-08`
- Mean absolute prediction error: `9.686476310122758e-09`

## Notes

- The exporter uses the effective tree count from XGBoost early stopping:
  `best_iteration + 1`.
- Classifier base score is exported as raw margin for binary logistic scoring.
- Tree split comparisons are validated with float32-compatible behavior to
  match XGBoost threshold handling.
- Generated export artifacts under `artifacts/model_exports/` are ignored by
  git.
- No MetaEditor compile was required because no MQL5 files were touched.
