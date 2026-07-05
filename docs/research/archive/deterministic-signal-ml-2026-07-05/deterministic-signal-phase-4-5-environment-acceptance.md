# Deterministic Signal Phase 4.5 Environment Acceptance

**Date**: 2026-07-04
**Phase**: 4.5 - Agentic Environment Portability And Artifact Restoration
**Status**: Completed evidence archived on 2026-07-05

## Validation Summary

Phase 4.5 makes the Windows and Ubuntu/Wine workflows reproducible for Codex
agents before Phase 5 MQL5 Shadow Inference. It does not add EA inference,
change trading behavior, run Strategy Tester automation, or commit generated
datasets/models/logs.

## Environment Inventory

| Item | Status | Value |
| --- | --- | --- |
| Ubuntu MT5 root | PASS | `/home/loldlm/mql5_projects/metatrader_5_market_data_framework` |
| Ubuntu Common Files | PASS | `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files` |
| Windows MT5 root | Pending human validation | `C:\Program Files\MetaTrader 5-1` |
| Windows Common Files | Pending human validation | `%APPDATA%\MetaQuotes\Terminal\Common\Files` |
| Phase 1 run ID | PASS | `test_run_1` |
| Dataset ID | PASS | `test_dataset_1` |
| Model ID | PASS | `xgb_test_1` |
| Export ID | PASS | `xgb_test_1_export_v1` |

## Compile Evidence

### Ubuntu/Wine

- Command: `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-build.log --mode compile --timeout 180`
- Helper result: `PASS`
- MetaEditor log status: `Result: 0 errors, 0 warnings, 30528 ms elapsed, cpu='X64 Regular'`
- Wine process return code reported by helper: `1`
- `.ex5` timestamp after real compile: `2026-07-04 16:29:16 -0400`
- Compile log: `logs/compile/agentic-build.log`

### Windows

Pending human-in-the-loop validation on Windows. The Windows command shape is
documented in `docs/environment/mt5-agentic-workflows.md`.

## Artifact Evidence

### Phase 1 Run

- Root: `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs`
- Run ID: `test_run_1`
- Files:
  - `run_manifest.tsv`: 449 bytes
  - `run_summary.tsv`: 234 bytes
  - `signal_features.tsv`: 682529 bytes
  - `signal_outcomes.tsv`: 510275 bytes
- Validation: `validation ok | runs=1 | features=2834 | outcomes=2834 | joined=2834`

### Phase 2 Dataset

- Command: `build_dataset.py --run-id test_run_1 --dataset-id test_dataset_1 --overwrite`
- Result: `assembly ok | features=2834 | outcomes=2834 | training_matrix=2834`
- Dataset path: `artifacts/datasets/test_dataset_1`
- Parquet row counts:
  - `features.parquet`: 2834
  - `outcomes.parquet`: 2834
  - `training_matrix.parquet`: 2834
- Dataset quality: `OK`
- Config ID: `cfg_16232898657813854669`

### Phase 3 Model

- Command: `train_model.py --dataset-id test_dataset_1 --model-id xgb_test_1 --overwrite`
- Result: `encoding ok | trainer=phase3.xgboost_trainer.v1 | dataset=test_dataset_1 | model_id=xgb_test_1 | rows=2834 | encoded_features=49 | holdout_rows=567 | folds=4 | xgboost=trained | threshold_candidate=True`
- Python stack:
  - `duckdb`: 1.5.4
  - `numpy`: 2.3.3
  - `scikit-learn`: 1.9.0
  - `xgboost`: 3.1.2
- Target counts:
  - `target_is_win=0`: 1451
  - `target_is_win=1`: 1383
- Threshold recommendation:
  - threshold: `0.55`
  - selected rows: 45
  - win rate: 0.6444444444444445
  - mean profit R: 0.27456
  - net profit R: 12.3552
  - max drawdown-like R: 7.6133
  - status: `research_only_candidate`

### Phase 4 Export

- Command: `export_model_artifact.py --model-id xgb_test_1 --dataset-id test_dataset_1 --export-id xgb_test_1_export_v1 --overwrite`
- Export path: `artifacts/model_exports/xgb_test_1_export_v1`
- Validator result: `model artifact validation ok | export_id=xgb_test_1_export_v1 | model_id=xgb_test_1 | dataset_id=test_dataset_1 | encoded_features=49 | classifier_trees=31 | regressor_trees=30 | mt5_runtime_ready=true | research_only=true`
- Export manifest:
  - encoded features: 49
  - classifier trees: 31
  - regressor trees: 30
  - threshold probability: 0.55
  - `mt5_runtime_ready`: `true`
  - `research_only`: `true`
- Parity:
  - status: `OK`
  - classifier max abs error: `6.733366786360051e-08`
  - regressor max abs error: `6.888626119527785e-08`

## Phase 5 Readiness Gate

| Check | Status |
| --- | --- |
| Ubuntu real compile clean | PASS |
| Windows real compile clean or explicitly accepted as pending | Pending human validation |
| Common Files path confirmed | PASS for Ubuntu/Wine |
| `test_run_1` available | PASS |
| Dataset build validated | PASS |
| XGBoost training completed or restored | PASS |
| Model export validated | PASS |
| Generated artifacts remain ignored | PASS |
| No EA runtime inference added | PASS |

**Readiness**: PASS for Ubuntu/Wine Phase 5 planning; Windows compile remains
pending human-in-the-loop validation before claiming cross-platform completion.

Phase 5 may be planned from `xgb_test_1_export_v1` on Ubuntu/Wine. Before
claiming Windows parity, run the documented Windows compile command and update
this file.
