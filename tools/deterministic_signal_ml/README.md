# Deterministic Signal ML Tooling

Local Python tooling for the deterministic signal ML workflow.

The Phase 2 builder consumes Phase 1 TSV exports produced by the EA and builds
validated Parquet datasets. The Phase 3 trainer consumes those datasets and
trains local research XGBoost models. These tools do not call MT5, modify the
EA, run EA inference, filter trades, or connect to PostgreSQL.

## Setup

Use a local virtual environment:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tools\deterministic_signal_ml\requirements.txt
```

On Ubuntu:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
```

If `py -3.12` or `python3` is unavailable, use the Python 3.12 executable you
normally use for local research. The OS-specific Common Files and artifact
workflow is documented in `docs/environment/mt5-agentic-workflows.md`.

Dependency versions are pinned in `requirements.txt` for reproducibility across
the current Ubuntu/Wine workstation and Windows. Do not loosen the pins without
rerunning imports, dataset build, training, export, and artifact validation.

## Phase 1 Input

Expected source folder:

```text
C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs\<run_id>
```

Ubuntu/Wine observed source root on this workstation:

```text
/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs/<run_id>
```

Each run must contain:

- `run_manifest.tsv`
- `signal_features.tsv`
- `signal_outcomes.tsv`
- `run_summary.tsv`

## Planned Build Command

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\build_dataset.py `
  --runs-root "C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs" `
  --run-id test_run_1 `
  --dataset-id test_dataset_1
```

Ubuntu:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs" \
  --run-id test_run_1 \
  --dataset-id test_dataset_1
```

Generated datasets are written under `artifacts/datasets/<dataset_id>/` and are
ignored by git.

## Validate Only

Use `--validate-only` before building larger datasets:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\build_dataset.py `
  --runs-root "C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs" `
  --run-id test_run_1 `
  --dataset-id test_dataset_1 `
  --validate-only
```

Ubuntu:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/DeterministicSignalML/runs" \
  --run-id test_run_1 \
  --dataset-id test_dataset_1 \
  --validate-only
```

The command exits nonzero when a run is missing required files, has a bad
header, mismatched row counts, duplicate `signal_id` values, missing
feature/outcome joins, non-OK export status, or inconsistent TP/SL signs.

## Outputs

Each dataset folder contains:

- `features.parquet`: typed Phase 1 feature rows.
- `outcomes.parquet`: typed terminal outcome rows.
- `training_matrix.parquet`: joined table with `target_is_win`,
  `target_profit_r`, and `target_terminal_reason`.
- `dataset_manifest.json`: column groups, source runs, config IDs, and output
  paths.
- `dataset_quality.json`: machine-readable quality summary.
- `dataset_report.md`: compact human-readable report.

Existing dataset folders are not overwritten unless `--overwrite` is passed.
Multiple `--run-id` values are supported, but mixed `config_id` values fail by
default unless `--allow-mixed-config` is passed.

## Phase 3 Training

Train local research models from a Phase 2 dataset:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\train_model.py `
  --dataset-id test_dataset_1 `
  --model-id xgb_test_1 `
  --overwrite
```

Generated model outputs are written under `artifacts/models/<model_id>/` and
are ignored by git. The trainer uses deterministic one-hot encoding, a final
chronological holdout, and walk-forward folds over the earlier data. Random
train/test splits are intentionally not used because they can leak future market
regime information into the validation result.

Model outputs include:

- `model_manifest.json`: dataset/model IDs, feature contract, split policy,
  validation summary, and research-only artifact links.
- `feature_encoder.json`: deterministic encoded feature order.
- `classifier_xgboost.json` and `regressor_xgboost.json`: Python XGBoost
  booster JSON artifacts, not MT5-readable model files yet.
- `validation_metrics.json` and `validation_report.md`: baseline, XGBoost,
  fold, holdout, and feature diagnostics.
- `threshold_report.tsv`: research-only probability thresholds with selected
  rows, win rate, mean/net R, and drawdown-like R proxy.
- `holdout_predictions.parquet` and `fold_predictions.parquet`: analysis
  predictions readable by DuckDB.

Phase 3 is research-only. It does not add EA inputs, does not run Python from
MQL5, and does not change strategy entry/exit behavior.

## Phase 4 Model Export

Export a Phase 3 model folder into MT5-readable TSV artifacts:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\export_model_artifact.py `
  --model-id xgb_test_1 `
  --dataset-id test_dataset_1 `
  --export-id xgb_test_1_export_v1 `
  --overwrite
```

Validate the generated export without calling XGBoost:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\model_artifact_validator.py `
  --export-id xgb_test_1_export_v1
```

Generated exports are written under `artifacts/model_exports/<export_id>/` and
are ignored by git. The export includes:

- `model_manifest.tsv`: simple key/value runtime manifest for MQL5 loading.
- `model_manifest.json`: Python audit sidecar.
- `feature_map.tsv`: encoded feature index and one-hot mapping.
- `classifier_trees.tsv`: flattened classifier tree nodes.
- `regressor_trees.tsv`: flattened regressor tree nodes.
- `threshold_policy.tsv`: research-only threshold metadata.
- `parity_report.json` and `parity_report.md`: Python parity evidence.

The exporter writes only the effective XGBoost trees used by prediction after
early stopping. For `xgb_test_1`, that is 84 classifier trees and 47 regressor
trees. Export remains an offline Python step; MT5 runtime loading and
Strategy Tester inference use the copied artifact under Common Files.

## Phase 5 Runtime Copy

MQL5 shadow inference reads from MT5 `Common\Files`, not from the repository
`artifacts/model_exports` folder. Validate the export before copying:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\model_artifact_validator.py `
  --export-id xgb_test_1_export_v1
```

Ubuntu:

```bash
.venv/bin/python tools/deterministic_signal_ml/model_artifact_validator.py \
  --export-id xgb_test_1_export_v1

export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
mkdir -p "$MT5_COMMON_FILES/DeterministicSignalML/model_exports"
cp -a artifacts/model_exports/xgb_test_1_export_v1 \
  "$MT5_COMMON_FILES/DeterministicSignalML/model_exports/"
```

Windows PowerShell:

```powershell
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$dest = Join-Path $MT5_COMMON_FILES "DeterministicSignalML\model_exports"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force artifacts\model_exports\xgb_test_1_export_v1 $dest
```

The EA input surface is intentionally small:

```text
ML_Inference_Mode = ML_INFERENCE_DISABLED
ML_Model_Export_Id = xgb_test_1_export_v1
```

`ML_INFERENCE_SHADOW` is observational. It records scores and diagnostics only;
it must not filter trades, change Strategy Tester broker admission, or alter
entry/exit behavior.

Compare MQL5 shadow scores against the Python artifact scorer after a Strategy
Tester run produces a shadow run folder:

```bash
.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py \
  --export-id xgb_test_1_export_v1 \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

The comparison prints only row counts, max/mean errors, threshold-decision
agreement, and a few failure examples. It does not dump full prediction files.

## Phase 6 Filter Validation

`ML_INFERENCE_FILTER` is Strategy Tester only. It may block deterministic broker
admission after existing broker/risk eligibility passes and before broker send.
It is not approved for live deployment.

After a Strategy Tester run with `ML_INFERENCE_FILTER`, summarize the run before
inspecting any larger artifact:

```bash
.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

Then compare scored prediction rows against the Python artifact scorer:

```bash
.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py \
  --export-id xgb_test_1_export_v1 \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

The summarizer checks required TSV files, duplicate headers, row-count
consistency, filter allow/block counters, unavailable blocks, invalid-feature
blocks, and export status. It prints compact counts only.

## Validation Hardening

Phase 1 of the ML robustness roadmap adds Python-only validation hardening
before new features or runtime behavior changes. The current short baseline is
usable for tooling smoke checks only:

```bash
.venv/bin/python tools/deterministic_signal_ml/model_validation_config.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --export-id xgb_test_1_export_v1
```

The hardened validation flow must separate threshold selection from final
holdout approval, report segment diagnostics, flag overfit risks, and compare
future candidate models against a frozen baseline.

A fresh one-to-two-year Strategy Tester run is required before accepting new
feature sets, production-like thresholds, cross-symbol claims, dynamic `1:n`
target behavior, or any future live rollout evidence.

## Agentic Evidence Policy

Do not paste full TSV, Parquet, model JSON, or tree TSV files into chat.
For Codex handoff, record only paths, sizes, row counts, model/export IDs,
threshold metadata, parity status, and final validator status. The compact
active workflow reference is
`docs/workflows/deterministic-signal-ml-inference-flows.md`; completed detailed
evidence is archived under
`docs/research/archive/deterministic-signal-ml-2026-07-05/`.

## DuckDB References

- DuckDB Python package: https://github.com/duckdb/duckdb-python
- DuckDB CSV import options: https://duckdb.org/docs/current/data/csv/overview.html
- DuckDB COPY statement and Parquet export: https://duckdb.org/docs/current/sql/statements/copy.html
