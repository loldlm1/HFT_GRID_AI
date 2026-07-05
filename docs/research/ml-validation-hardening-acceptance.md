# ML Validation Hardening Acceptance

**Date**: 2026-07-05
**Roadmap Phase**: Phase 1 - ML Validation Hardening
**Status**: Accepted for tooling smoke validation; real research run pending

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
- Dataset grade: `smoke_only`
- Training matrix rows: `2834`
- Encoded features: `49`
- Export threshold probability: `0.55`

This baseline was generated from about one month of data and must not be used to
approve new feature sets, production-like thresholds, cross-symbol claims, or
dynamic target behavior.

## Smoke Validation Commands

```bash
.venv/bin/python tools/deterministic_signal_ml/model_validation_config.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --export-id xgb_test_1_export_v1
```

```bash
.venv/bin/python tools/deterministic_signal_ml/validate_model_robustness.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --export-id xgb_test_1_export_v1 \
  --output-path artifacts/models/xgb_test_1/robustness
```

```bash
.venv/bin/python tools/deterministic_signal_ml/model_validation_config.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --export-id xgb_test_1_export_v1 \
  --write-candidate-manifest artifacts/models/xgb_test_1/robustness/baseline_candidate_manifest.json

.venv/bin/python tools/deterministic_signal_ml/compare_model_candidates.py \
  --baseline-manifest artifacts/models/xgb_test_1/robustness/baseline_candidate_manifest.json \
  --candidate-manifest artifacts/models/xgb_test_1/robustness/baseline_candidate_manifest.json \
  --output-path artifacts/models/xgb_test_1/robustness/comparison
```

## Acceptance Evidence

Generated ignored outputs:

- `artifacts/models/xgb_test_1/robustness/robustness_metrics.json`
- `artifacts/models/xgb_test_1/robustness/robustness_report.md`
- `artifacts/models/xgb_test_1/robustness/threshold_selection.tsv`
- `artifacts/models/xgb_test_1/robustness/segment_metrics.tsv`
- `artifacts/models/xgb_test_1/robustness/overfit_warnings.tsv`
- `artifacts/models/xgb_test_1/robustness/baseline_candidate_manifest.json`
- `artifacts/models/xgb_test_1/robustness/comparison/candidate_comparison.json`
- `artifacts/models/xgb_test_1/robustness/comparison/candidate_comparison.md`

Smoke results:

- Baseline inventory: `smoke_only`, `2834` rows, `49` encoded features,
  threshold `0.55`.
- Robustness status: `WARN`, expected for smoke evidence.
- Split policy: train core `1415`, early-stopping validation `283`,
  threshold-selection `569`, final holdout `567`.
- Threshold-selection source: `walk_forward_oof_pre_final_holdout`, source rows
  `1809`, selected threshold `0.55`, selected rows `59`.
- Final holdout evaluation at threshold `0.55`: rows `567`, selected rows `45`,
  mean R `0.27456`, net R `12.3552`.
- Warnings: `6` total:
  `dataset_has_smoke_only_row_count`, `short_dataset`,
  `legacy_export_threshold_uses_holdout`, `no_variation_features_present`,
  `rare_bucket_importance`, `segment_support_warnings`.
- Segment diagnostics: `18` rows, `7` warning-status segments due to low
  support.
- Feature diagnostics: `1` no-variation encoded feature and `8` rare-bucket
  warnings.
- Candidate comparison smoke result: `NO_MATERIAL_IMPROVEMENT` for baseline
  versus itself, with `0` comparability warnings and `0` segment regressions.

Phase result:

- Tooling is accepted for smoke validation.
- The current model is not promoted beyond the previously accepted Strategy
  Tester `FILTER` scope.
- The current dataset cannot approve new features, thresholds, multi-symbol
  claims, dynamic targets, ONNX work, live rollout, or signal arbitration.

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

Real-run checklist:

- Use `docs/environment/mt5-agentic-workflows.md` for MT5/Wine paths, Common
  Files placement, and generated artifact handling.
- Generate raw deterministic signal features and closed outcomes with ML mode
  disabled unless a future plan intentionally studies `ML_INFERENCE_FILTER`
  behavior.
- Use a documented one-to-two-year date range, symbol, broker environment,
  spread/cost assumptions, strategy inputs, run ID, and config ID.
- Keep strategy configuration stable throughout the data generation run.
- Export enough closed signals for train core, early-stopping validation,
  threshold selection, final holdout, walk-forward folds, and per-segment
  diagnostics.
- Do not tune features or thresholds on the final holdout.
- Re-run the hardened robustness command and candidate comparison before any
  feature or threshold is accepted.
