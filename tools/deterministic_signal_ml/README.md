# Deterministic Signal ML Tooling

Local Python tooling for the deterministic signal ML roadmap.

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

If `py -3.12` is unavailable, use the Python executable you normally use for
local research.

## Phase 1 Input

Expected source folder:

```text
C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs\<run_id>
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

## DuckDB References

- DuckDB Python package: https://github.com/duckdb/duckdb-python
- DuckDB CSV import options: https://duckdb.org/docs/current/data/csv/overview.html
- DuckDB COPY statement and Parquet export: https://duckdb.org/docs/current/sql/statements/copy.html
