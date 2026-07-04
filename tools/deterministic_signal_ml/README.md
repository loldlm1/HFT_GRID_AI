# Deterministic Signal ML Dataset Builder

Local Python tooling for Phase 2 of the deterministic signal ML roadmap.

This tool consumes Phase 1 TSV exports produced by the EA and builds local,
validated Parquet datasets for later model training. It does not call MT5,
modify the EA, train XGBoost, run inference, or connect to PostgreSQL.

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

## DuckDB References

- DuckDB Python package: https://github.com/duckdb/duckdb-python
- DuckDB CSV import options: https://duckdb.org/docs/current/data/csv/overview.html
- DuckDB COPY statement and Parquet export: https://duckdb.org/docs/current/sql/statements/copy.html
