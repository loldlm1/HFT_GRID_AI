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

Pending final Sprint 6 compile evidence.

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

Pending human-in-the-loop Strategy Tester run.

Expected files:

```text
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_manifest.tsv
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_predictions.tsv
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_outcomes.tsv
Common\Files\DeterministicSignalML\shadow_runs\<shadow_run_id>\shadow_summary.tsv
```

## Parity Evidence

Pending shadow run output.

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
