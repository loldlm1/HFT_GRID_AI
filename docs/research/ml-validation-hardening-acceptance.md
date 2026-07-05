# ML Validation Hardening Acceptance

**Date**: 2026-07-05
**Roadmap Phase**: Phase 1 - ML Validation Hardening
**Status**: Draft, implementation in progress

## Scope

This phase hardens deterministic signal ML validation before new features,
signal arbitration, ONNX, multi-symbol research, or dynamic `1:n` targets are
implemented.

Accepted implementation scope:

- Python research tooling only.
- Compact documentation and acceptance evidence only.
- No MQL5 runtime behavior changes.
- No MetaEditor compile requirement.
- No Strategy Tester run required for this phase's tooling smoke validation.

## Smoke Baseline

The current short baseline is accepted only for tooling smoke validation:

- Dataset ID: `test_dataset_1`
- Model ID: `xgb_test_1`
- Export ID: `xgb_test_1_export_v1`
- Dataset grade: smoke-only until verified by robustness tooling

This baseline was generated from about one month of data and must not be used to
approve new feature sets, production-like thresholds, cross-symbol claims, or
dynamic target behavior.

## Planned Baseline Command

```bash
.venv/bin/python tools/deterministic_signal_ml/model_validation_config.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --export-id xgb_test_1_export_v1
```

Planned robustness command after implementation:

```bash
.venv/bin/python tools/deterministic_signal_ml/validate_model_robustness.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --export-id xgb_test_1_export_v1 \
  --output-path artifacts/models/xgb_test_1/robustness
```

## Acceptance Evidence

Pending implementation:

- Baseline inventory summary.
- Split policy summary.
- Threshold-selection source.
- Final holdout status.
- Segment diagnostics.
- Feature concentration warnings.
- Candidate comparison smoke result.
- Real one-to-two-year run checklist.

## Future Feature Acceptance Gate

Future feature sets, including Feature Schema V2 candidates, must satisfy this
gate before they can be treated as accepted research evidence:

- Threshold selection must come from threshold-selection rows or pre-final
  holdout out-of-fold rows, never from final holdout rows.
- Final holdout must remain approval evidence only.
- Candidate comparison must show material improvement versus the frozen
  baseline, not merely equal smoke performance.
- No critical segment regression may remain unresolved across strategy,
  direction, source type, symbol, strategy-direction, or score-bucket views.
- Overall selected rows and important segment selected rows must clear minimum
  support guards.
- Leakage, final-holdout reuse, no-gap-when-required, rare-bucket dominance,
  and no-variation feature warnings must be resolved or explicitly accepted as
  non-blocking before feature approval.
- One-month smoke datasets cannot approve feature additions, production-like
  thresholds, cross-symbol claims, or dynamic target work.

## Real Run Requirement

A fresh one-to-two-year Strategy Tester run is required after this phase passes
and before any of the following are accepted:

- Feature Schema V2 additions.
- New thresholds as more than smoke/research evidence.
- Symbol-specific versus multi-symbol model claims.
- Dynamic `1:n` target modeling.
- Future live rollout planning.
