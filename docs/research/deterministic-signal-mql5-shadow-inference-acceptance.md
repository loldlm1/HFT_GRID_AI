# Deterministic Signal MQL5 Shadow Inference Acceptance

**Date**: 2026-07-04
**Phase**: 5 - MQL5 Shadow Inference

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
  - `shadow_manifest.tsv`: 413 bytes
  - `shadow_predictions.tsv`: 940171 bytes
  - `shadow_outcomes.tsv`: 572464 bytes
  - `shadow_summary.tsv`: 265 bytes
- Row counts:
  - predictions: 2834
  - outcomes: 2834
  - summary rows: 1
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

This run was generated before the MQL5 parity fix that rounds `sl_fib_raw` and
`entry_fib_raw` to the same one-decimal feature contract used by Phase 1 TSVs
and Python training. Regenerate a fresh shadow run before declaring Phase 5
runtime parity `PASS`.

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
- Result: `FAIL`
- Rows compared: 2834
- Classifier max absolute error: `0.121349416736`
- Classifier mean absolute error: `0.000834777201806`
- Threshold decision agreement: `0.99647141849`
- Regressor max absolute error: `0.2599792984193`

Conclusion: runtime file generation and artifact loading worked, but parity did
not pass for this run. The mismatch exposed a feature-contract bug: MQL5 scored
raw Fibonacci percentages at full precision while the model was trained from
Phase 1 TSV values rounded to one decimal. The MQL5 encoder has been corrected;
a new Strategy Tester shadow run is required for final PASS.

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

Phase 6 `FILTER` mode is not approved by this file. Before planning or
implementing filter behavior, require:

- clean final Phase 5 compile,
- successful artifact load in `SHADOW`,
- nonzero shadow prediction rows,
- parity validator `PASS`,
- enough closed outcomes for human review,
- explicit human approval that model recommendations may affect broker
  admission in Strategy Tester.
