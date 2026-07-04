# Deterministic Signal MQL5 Filter Inference Acceptance

**Date**: 2026-07-04
**Phase**: 6 - MQL5 Filter Inference
**Status**: IMPLEMENTATION PASS for Ubuntu/Wine compile and static validation;
Strategy Tester `FILTER` runtime validation is pending a human-in-the-loop run.

## Validation Summary

Phase 6 adds `ML_INFERENCE_FILTER` for Strategy Tester broker admission filtering
only. The default remains `ML_INFERENCE_DISABLED`. Live deployment remains out
of scope.

The filter gate is placed after existing local broker/risk eligibility checks
and before the broker send. It cannot create trades, resize lots, alter SL/TP,
bypass license/session/spread/margin/protection controls, change magic-number
scope, or overwrite broker reconciliation.

## Accepted Scope

- Runtime modes: `ML_INFERENCE_DISABLED | ML_INFERENCE_SHADOW |
  ML_INFERENCE_FILTER`.
- Default mode: `ML_INFERENCE_DISABLED`.
- Filter scope: deterministic Strategy Tester broker admission only.
- Runtime export ID: `xgb_test_1_export_v1`.
- Threshold source: artifact `threshold_policy.tsv`.
- Filter failure policy: fail closed for model admission.
- Shadow failure policy: fail open and observational.

## Compile Evidence

### Ubuntu/Wine

- Command: `python3 tools/mt5/compile_mt5.py --wine --mt5-root /home/loldlm/mql5_projects/metatrader_5_market_data_framework --entrypoint /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5 --log /home/loldlm/mql5_projects/metatrader_5_market_data_framework/MQL5/Experts/HFT_Grid_AI/logs/compile/phase-06-filter-inference.log --mode compile --timeout 180`
- Helper result: `PASS`
- MetaEditor log status: `Result: 0 errors, 0 warnings, 39076 ms elapsed, cpu='X64 Regular'`
- Wine process return code reported by helper: `1`
- `.ex5` timestamp after real compile: `2026-07-04 19:17:49 -0400`
- Compile log: `logs/compile/phase-06-filter-inference.log`

### Windows

Pending human-in-the-loop validation on Windows.

## Static Safety Evidence

- `ML_INFERENCE_DISABLED=0`, `ML_INFERENCE_SHADOW=1`, and
  `ML_INFERENCE_FILTER=2`.
- `ML_Inference_Mode` default remains `ML_INFERENCE_DISABLED`.
- `PrepareExecutionLegTradeAdmission` runs existing local broker/risk
  eligibility before `DeterministicSignalMLFilterAllowsEntry`.
- `ApplyExecutionLegTradeAdmission` is the only helper that calls
  `g_position.Buy` or `g_position.Sell`.
- Filter-blocked deterministic signals are closed locally with terminal reason
  `ML_FILTER_BLOCKED` and no broker ticket.
- Broker outcomes remain guarded by `SignalHasBrokerConfirmedOutcome`.

## Tooling Evidence

- `python3 -m py_compile tools/deterministic_signal_ml/*.py`: `PASS`
- Existing Phase 5 shadow run summary:
  - Command: `.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py --shadow-run-path /home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/shadow_runs/shadow_test_run_1`
  - Result: `PASS`
  - predictions: 2834
  - outcomes: 2834
  - scored: 2834
  - recommendation `ALLOW`: 268
  - recommendation `BLOCK`: 2566
  - admission `ALLOW`: 0
  - admission `BLOCK`: 0
  - export status: `OK`
- Existing Phase 5 shadow parity regression:
  - Command: `.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py --export-id xgb_test_1_export_v1 --shadow-run-path /home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/shadow_runs/shadow_test_run_1`
  - Result: `PASS`
  - rows compared: 2834
  - classifier max absolute error: `4.99940822074e-09`
  - classifier mean absolute error: `2.42345073069e-09`
  - threshold decision agreement: `1`
  - regressor max absolute error: `4.998299996117339e-09`

## Runtime Filter Evidence

Pending. A human must run Strategy Tester with:

```text
ML_Inference_Mode = ML_INFERENCE_FILTER
ML_Model_Export_Id = xgb_test_1_export_v1
```

Expected validation commands after the run:

```bash
.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"

.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py \
  --export-id xgb_test_1_export_v1 \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

## Acceptance Gate

Phase 6 runtime acceptance remains pending until all are true:

- Strategy Tester `FILTER` run produces nonzero scored prediction rows.
- Filter run summary is `PASS`.
- Prediction comparator is `PASS`.
- `BLOCK` decisions do not create broker positions.
- `ALLOW` decisions still respect broker/risk gates and normal broker-send
  failure handling.
- Human reviews the Strategy Tester behavioral delta.
