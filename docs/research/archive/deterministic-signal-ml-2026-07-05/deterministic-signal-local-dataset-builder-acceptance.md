# Deterministic Signal Local Dataset Builder Acceptance

**Date**: 2026-07-04
**Phase**: 2 - Local Dataset Builder
**Status**: Completed evidence archived on 2026-07-05

## Validation Summary

Phase 2 was implemented as local Python tooling under
`tools/deterministic_signal_ml/`. It does not modify MQL5, add EA inputs, train
models, run inference, or use PostgreSQL.

## Environment

- Python: bundled Codex runtime Python 3.12.13
- DuckDB: 1.5.4 installed into local `.venv`
- Generated dataset output root: `artifacts/datasets/`

## Commands Run

```powershell
.\.venv\Scripts\python.exe -m py_compile `
  tools\deterministic_signal_ml\schema_contract.py `
  tools\deterministic_signal_ml\validate_phase1_run.py `
  tools\deterministic_signal_ml\report_writer.py `
  tools\deterministic_signal_ml\build_dataset.py
```

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\build_dataset.py `
  --runs-root $env:TEMP\hft_phase2_fixture\runs `
  --run-id fixture_run_1 `
  --dataset-id fixture_dataset `
  --validate-only
```

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\build_dataset.py `
  --runs-root $env:TEMP\hft_phase2_fixture\runs `
  --run-id fixture_run_1 `
  --dataset-id fixture_dataset `
  --overwrite
```

## Results

- Validation succeeded for a temporary Phase 1-compatible fixture.
- Dataset assembly produced 1 feature row, 1 outcome row, and 1 training matrix
  row.
- Parquet readback confirmed:
  - `features.parquet`: 1 row
  - `outcomes.parquet`: 1 row
  - `training_matrix.parquet`: 1 row
- `dataset_manifest.json`, `dataset_quality.json`, and `dataset_report.md` were
  generated successfully.

## Real Run Availability Note

The previously inspected `test_run_1` Phase 1 run was not present under
`C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs`
during Phase 2 implementation. The builder correctly returned a clear validation
failure for the missing run folder. Re-running the Phase 1 Strategy Tester export
will allow the same Phase 2 command to validate and build the real dataset.
