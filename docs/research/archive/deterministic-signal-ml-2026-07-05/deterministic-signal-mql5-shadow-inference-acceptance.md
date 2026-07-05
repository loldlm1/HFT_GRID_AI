# Deterministic Signal MQL5 Shadow Inference Acceptance

**Date**: 2026-07-04
**Phase**: 5 - MQL5 Shadow Inference
**Status**: PASS for Ubuntu/Wine Phase 5 runtime and parity; archived on 2026-07-05. Windows compile remained human-in-the-loop validation.

## Validation Summary

Phase 5 loads the MT5-readable model export in MQL5 and records shadow scores
without changing broker admission, entries, exits, lot sizing, SL/TP, license
checks, session gates, spread checks, margin checks, protection controls, magic
number scope, or broker reconciliation.

## Accepted Scope

- Runtime mode: `ML_INFERENCE_DISABLED | ML_INFERENCE_SHADOW`.
- Default mode: `ML_INFERENCE_DISABLED`.
- Runtime export ID: `xgb_test_1_export_v1`.
- Runtime artifact root:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/model_exports/xgb_test_1_export_v1`
- Shadow output root:
  `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/shadow_runs`
- Failure policy: fail open for trading, fail visible through compact diagnostics.

## Compile Evidence

### Ubuntu/Wine

- Command: `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase-05-shadow-inference-final.log --mode compile --timeout 180`
- Helper result: `PASS`
- MetaEditor log status: `Result: 0 errors, 0 warnings, 38077 ms elapsed, cpu='X64 Regular'`
- Wine process return code reported by helper: `1`
- `.ex5` timestamp after real compile: `2026-07-04 17:26:36 -0400`
- Compile log: `logs/compile/phase-05-shadow-inference-final.log`

### Ubuntu/Wine Parity Fix Compile

- Command: `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase-05-shadow-inference-parity-fix.log --mode compile --timeout 180`
- Helper result: `PASS`
- MetaEditor log status: `Result: 0 errors, 0 warnings, 38036 ms elapsed, cpu='X64 Regular'`
- Wine process return code reported by helper: `1`
- Compile log: `logs/compile/phase-05-shadow-inference-parity-fix.log`

### Windows

Pending human-in-the-loop validation on Windows.

## Artifact Evidence

- Export ID: `xgb_test_1_export_v1`
- Model ID: `xgb_test_1`
- Dataset ID: `test_dataset_1`
- Validator status: `model artifact validation ok`
- Encoded features: 49
- Classifier trees: 31
- Regressor trees: 30
- `mt5_runtime_ready`: `true`
- `research_only`: `true`

## Shadow Runtime Evidence

### `shadow_test_run_1`

- Path: `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/shadow_runs/shadow_test_run_1`
- Files present:
  - `shadow_manifest.tsv`: 413 bytes, updated `2026-07-04 18:31:43 -0400`
  - `shadow_predictions.tsv`: 940171 bytes, updated `2026-07-04 18:34:29 -0400`
  - `shadow_outcomes.tsv`: 572464 bytes, updated `2026-07-04 18:34:29 -0400`
  - `shadow_summary.tsv`: 265 bytes, updated `2026-07-04 18:34:29 -0400`
- Row counts:
  - predictions: 2834
  - outcomes: 2834
  - summary rows: 1
  - header rows per file: 1
- Summary:
  - `prediction_rows=2834`
  - `outcome_rows=2834`
  - `invalid_feature_rows=0`
  - `unavailable_events=0`
  - `export_status=OK`
- Manifest:
  - `shadow_run_id=shadow_test_run_1`
  - `export_id=xgb_test_1_export_v1`
  - `model_id=xgb_test_1`
  - `dataset_id=test_dataset_1`
  - `available=true`
  - `encoded_feature_count=49`
  - `classifier_tree_count=31`
  - `regressor_tree_count=30`
  - `threshold_probability=0.55000000`
- Prediction distribution:
  - `ALLOW=268`
  - `BLOCK=2566`
  - `classifier_score_gte_threshold=268`
  - `classifier_score_lt_threshold=2566`

This shadow run ID was reused for a fresh Strategy Tester execution after the
MQL5 parity fix. The row files are initialized with header-only writes before
rows are appended, and this rerun has exactly one header per TSV, so there is no
observed duplicate or stale-row ambiguity.

Expected files:

```text
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_manifest.tsv
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_predictions.tsv
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_outcomes.tsv
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_summary.tsv
```

## Parity Evidence

### `shadow_test_run_1`

- Command: `.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py --export-id xgb_test_1_export_v1 --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/shadow_test_run_1"`
- Result: `PASS`
- Rows compared: 2834
- Classifier max absolute error: `4.99940822074e-09`
- Classifier mean absolute error: `2.42345073069e-09`
- Threshold decision agreement: `1`
- Regressor max absolute error: `4.998299996117339e-09`

Conclusion: runtime file generation, artifact loading, feature encoding, tree
scoring, classifier threshold decisions, and regressor telemetry match the
Python artifact scorer within the accepted tolerance. Phase 5 runtime parity is
`PASS` for the Ubuntu/Wine validation scope.

Validator command shape:

```bash
.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py \
  --export-id xgb_test_1_export_v1 \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

Acceptance tolerances:

- Classifier max absolute error: `<= 1e-6`.
- Regressor max absolute error: `<= 1e-6` when regressor scores are present.
- Threshold decision agreement: `1.0`.

## Phase 6 Readiness

Phase 6 `FILTER` mode was approved after this Phase 5 evidence passed and is
tracked separately in
`docs/research/deterministic-signal-mql5-filter-inference-acceptance.md`.
This file remains the Phase 5 shadow/runtime parity evidence only.

Before accepting filter behavior, require:

- clean final Phase 6 compile,
- successful artifact load in `FILTER`,
- nonzero filter prediction rows,
- parity validator `PASS`,
- compact filter run summary `PASS`,
- human review of Strategy Tester behavioral delta.
