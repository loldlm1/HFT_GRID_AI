# Deterministic Signal XGBoost Training Acceptance

**Date**: 2026-07-04
**Phase**: 3 - Local XGBoost Training And Validation
**Status**: Completed evidence archived on 2026-07-05

## Validation Summary

Phase 3 was implemented as local Python research tooling under
`tools/deterministic_signal_ml/`. It does not modify MQL5, add EA inputs, call
Python from the EA, run Strategy Tester inference, connect to PostgreSQL, or
change trading behavior.

## Environment

- Python: bundled Codex runtime Python 3.12.13
- DuckDB: 1.5.4 installed into local `.venv`
- scikit-learn: 1.9.0 installed into local `.venv`
- XGBoost: 3.1.2 installed into local `.venv`
- Generated model output root: `artifacts/models/`

## Commands Run

```powershell
.\.venv\Scripts\python.exe -m py_compile `
  tools\deterministic_signal_ml\model_config.py `
  tools\deterministic_signal_ml\feature_encoder.py `
  tools\deterministic_signal_ml\validation_splits.py `
  tools\deterministic_signal_ml\training_report.py `
  tools\deterministic_signal_ml\train_model.py
```

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\train_model.py `
  --dataset-id test_dataset_1 `
  --model-id xgb_test_1 `
  --overwrite
```

DuckDB readback was run for:

- `artifacts/models/xgb_test_1/holdout_predictions.parquet`
- `artifacts/models/xgb_test_1/fold_predictions.parquet`

## Accepted Run

- Dataset ID: `test_dataset_1`
- Model ID: `xgb_test_1`
- Source run ID: `test_run_1`
- Config ID: `cfg_16232898657813854669`
- Training matrix rows: 2821
- Encoded feature count: 49
- Split policy: chronological holdout plus walk-forward folds
- Pre-holdout train rows: 2256
- Final holdout rows: 565
- Walk-forward folds: 4
- Out-of-fold prediction rows: 1807

## Holdout Results

- XGBoost classifier ROC AUC: 0.607302
- XGBoost classifier F1 at 0.50 threshold: 0.505133
- XGBoost classifier log loss: 0.677356
- XGBoost regressor RMSE: 1.183497
- XGBoost regressor correlation: 0.171577
- XGBoost regressor directional accuracy: 0.564602

Baseline comparison on the same holdout:

- Majority classifier ROC AUC: 0.500000
- Strategy/direction bucket classifier ROC AUC: 0.516975
- Shallow decision tree classifier ROC AUC: 0.544170
- Global mean regressor RMSE: 1.197858
- Strategy/direction bucket regressor RMSE: 1.198330
- Shallow decision tree regressor RMSE: 1.199688

## Threshold Output

`threshold_report.tsv` selected a research-only candidate at probability
threshold `0.60`:

- Selected rows: 34
- Selected percent: 6.017699%
- Win rate: 67.647059%
- Mean R: 0.346515
- Net R: 11.7815
- Max drawdown-like R proxy: 5.3261

This is not an EA trading rule. It is only a candidate for later shadow
validation.

## Feature Diagnostics

- `macro_d1_live_dir` was flagged as a no-variation encoded feature for this
  short dataset.
- Top classifier feature: `sl_fib_band=61.8_100.0`.
- Top regressor feature: `high_chain_score_5`.

## Notes

- Random split metrics were intentionally not produced.
- XGBoost JSON files are Python booster artifacts, not MT5-readable model files.
- Generated artifacts under `artifacts/models/` are ignored by git.
- No MetaEditor compile was required because Phase 3 did not touch MQL5 files.
