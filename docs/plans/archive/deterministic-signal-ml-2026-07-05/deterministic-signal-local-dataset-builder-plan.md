# Plan: Deterministic Signal Local Dataset Builder

**Generated**: 2026-07-04
**Status**: Completed and archived on 2026-07-05
**Estimated Complexity**: Medium
**Risk Level**: Low for EA trading behavior; Medium for data correctness and
future ML leakage risk.

## Overview

Implement Phase 2 of the deterministic signal ML roadmap: a local Python dataset
builder that consumes Phase 1 TSV exports and produces validated, typed,
ML-ready Parquet datasets plus a compact data quality report.

This phase must not change the EA, run inference, train XGBoost, add
PostgreSQL, or affect Strategy Tester trading behavior. Its job is to prove the
offline data boundary: exported signal statistics can be validated, joined, typed,
queried locally, and converted into stable dataset artifacts.

## Recommended Direction

- Use a minimal Python tool isolated under `tools/deterministic_signal_ml/`.
- Use DuckDB as the initial local engine for TSV reads, joins, schema validation,
  queries, and Parquet writes.
- Do not add Polars or pandas in Phase 2 unless DuckDB alone is insufficient.
- Default generated outputs to `artifacts/datasets/<dataset_id>/` and keep them
  ignored by git.
- Support one or more Phase 1 run folders, but fail closed by default when
  multiple `config_id` values are mixed.
- Preserve all identifiers and timestamps needed for walk-forward validation in
  Phase 3.
- Generate a clear report before any model training exists.

## Non-Goals

- No MQL5 changes.
- No EA inputs.
- No Strategy Tester inference.
- No Python calls from MQL5.
- No XGBoost training.
- No PostgreSQL.
- No dashboard or long-running service.
- No committing generated Parquet datasets.

## Proposed File Layout

```text
tools/deterministic_signal_ml/
  README.md
  requirements.txt
  build_dataset.py
  validate_phase1_run.py
  schema_contract.py
  report_writer.py

artifacts/datasets/<dataset_id>/
  dataset_manifest.json
  features.parquet
  outcomes.parquet
  training_matrix.parquet
  dataset_report.md
  dataset_quality.json
```

`artifacts/datasets/` should be added to `.gitignore` during implementation.

## Input Contract

The builder reads Phase 1 files from one or more run folders:

```text
Common\Files\DeterministicSignalML\runs\<run_id>\run_manifest.tsv
Common\Files\DeterministicSignalML\runs\<run_id>\signal_features.tsv
Common\Files\DeterministicSignalML\runs\<run_id>\signal_outcomes.tsv
Common\Files\DeterministicSignalML\runs\<run_id>\run_summary.tsv
```

Recommended CLI shape:

```powershell
python tools/deterministic_signal_ml/build_dataset.py `
  --runs-root "C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs" `
  --run-id test_run_1 `
  --dataset-id test_dataset_1
```

## Output Contract

### `features.parquet`

Typed copy of `signal_features.tsv` with Phase 1 feature columns and stable
identifiers.

### `outcomes.parquet`

Typed copy of `signal_outcomes.tsv` with terminal result fields.

### `training_matrix.parquet`

Joined table keyed by `signal_id`. It may include target columns, but the
manifest must explicitly separate:

```text
feature_columns
target_columns
identity_columns
audit_columns
excluded_from_training_columns
```

### `dataset_manifest.json`

Machine-readable contract for the dataset:

- dataset ID
- source run IDs
- config IDs
- Phase 1 schema version
- builder version
- row counts
- feature column list
- target column list
- created timestamp
- source folders

### `dataset_report.md`

Human-readable report:

- row counts
- join integrity
- duplicate IDs
- null counts
- target distribution
- terminal reason distribution
- strategy/direction/source distributions
- feature ranges
- simple per-strategy and per-direction outcome summaries
- warnings and rejected rows, if any

## Sprint 1: Tooling Contract And Dependency Boundary

**Goal**: Add the Python tooling boundary without building the full converter.
**Commit**: `docs: define deterministic signal dataset builder plan`
**Demo/Validation**:
- Static review confirms Phase 2 does not modify EA runtime behavior.
- Static review confirms generated datasets are ignored by git.

### Task 1.1: Confirm External Documentation

- **Location**:
  - Implementation notes in `tools/deterministic_signal_ml/README.md`
- **Description**: Before implementation, verify current official DuckDB Python
  and Parquet documentation.
- **Dependencies**: User confirmation of dependency direction.
- **Acceptance Criteria**:
  - DuckDB is confirmed as sufficient for TSV reads and Parquet writes.
  - No unnecessary Python dataframe dependency is introduced.
- **Validation**:
  - Link official docs in the tool README or implementation notes.

### Task 1.2: Add Python Tool Skeleton

- **Location**:
  - `tools/deterministic_signal_ml/`
  - `.gitignore`
- **Description**: Add the isolated tool folder, README, requirements, and
  gitignore entries for generated datasets.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Python dependencies are isolated from EA code.
  - Generated Parquet/report artifacts are not tracked by git.
  - Tool README includes a local Windows command example.
- **Validation**:
  - `git status --short` shows only source/docs/tooling files, no generated
    dataset output.

### Task 1.3: Define Schema Contract Constants

- **Location**:
  - `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Encode expected Phase 1 schema version, file names, required
  columns, numeric columns, categorical columns, identity columns, and target
  columns.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Missing columns fail validation.
  - Extra columns are preserved as audit columns unless explicitly rejected.
  - Outcome fields are not treated as model input features.
- **Validation**:
  - Run schema validation against `test_run_1`.

## Sprint 2: Phase 1 Run Validation

**Goal**: Validate one or more Phase 1 run folders before conversion.
**Commit**: `feat: validate deterministic signal export runs`
**Demo/Validation**:
- `test_run_1` passes validation with row counts matching Phase 1 summary.
- Invalid or incomplete run folders fail with actionable messages.

### Task 2.1: Discover Run Folders

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/validate_phase1_run.py`
- **Description**: Accept `--runs-root` plus one or more `--run-id` values.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Missing run folder fails clearly.
  - Missing required TSV file fails clearly.
  - Absolute and relative paths are supported where practical.
- **Validation**:
  - Run against existing `test_run_1`.

### Task 2.2: Validate Manifest And Summary

- **Location**:
  - `tools/deterministic_signal_ml/validate_phase1_run.py`
- **Description**: Parse `run_manifest.tsv` and `run_summary.tsv`.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `schema_version` must match supported schema.
  - `run_id` in files must match folder/input run ID.
  - `export_status` must be `OK` unless explicitly allowed for audit mode.
  - Feature/outcome row counts must match actual TSV rows.
  - Config IDs are collected for later mixed-config validation.
- **Validation**:
  - Use `test_run_1`, expecting 2821 features and 2821 outcomes.

### Task 2.3: Validate Feature And Outcome TSVs

- **Location**:
  - `tools/deterministic_signal_ml/validate_phase1_run.py`
  - `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Validate headers, column counts, null tokens, duplicate IDs,
  and join integrity.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Feature rows have unique `signal_id`.
  - Outcome rows have unique `signal_id`.
  - Every outcome joins to a feature.
  - Every feature has an outcome for Phase 2 supervised datasets.
  - Invalid numeric tokens are normalized from `\N` to null.
- **Validation**:
  - `test_run_1` reports zero duplicate IDs and zero missing joins.

## Sprint 3: Typed Dataset Assembly

**Goal**: Convert validated TSV rows into typed in-memory tables and a joined
training matrix.
**Commit**: `feat: assemble deterministic signal training matrix`
**Demo/Validation**:
- The builder creates typed feature, outcome, and training matrix tables from
  `test_run_1`.

### Task 3.1: Read TSV With DuckDB

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Use DuckDB to read Phase 1 TSV files with explicit delimiter,
  headers, null token, and expected types.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Numeric fields are stored as numeric types, not strings.
  - Timestamps are parsed or preserved in a consistently sortable format.
  - Categorical fields remain strings.
  - Bad casts fail validation instead of silently coercing.
- **Validation**:
  - Type inspection query after loading `test_run_1`.

### Task 3.2: Build Feature And Outcome Tables

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/schema_contract.py`
- **Description**: Materialize typed tables for features and outcomes.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - `features` includes Phase 1 feature columns and identifiers.
  - `outcomes` includes terminal outcome fields.
  - Feature leakage guard prevents outcome columns from entering
    `feature_columns`.
- **Validation**:
  - Check generated manifest column groups.

### Task 3.3: Build Training Matrix

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Join features and outcomes by `signal_id`.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - One row per joined signal.
  - Adds recommended targets:
    - `target_is_win`
    - `target_profit_r`
    - `target_terminal_reason`
  - Preserves `entry_time` and `terminal_time` for Phase 3 time splits.
  - Does not shuffle rows by default.
- **Validation**:
  - Row count equals validated join count.
  - TP rows have positive `target_profit_r`; SL rows have negative
    `target_profit_r`.

## Sprint 4: Parquet Outputs And Data Quality Report

**Goal**: Write durable local dataset artifacts and a human-readable report.
**Commit**: `feat: write deterministic signal parquet datasets`
**Demo/Validation**:
- Running the builder writes all expected files under
  `artifacts/datasets/<dataset_id>/`.

### Task 4.1: Write Parquet Files

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Write `features.parquet`, `outcomes.parquet`, and
  `training_matrix.parquet`.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Output folder is created safely.
  - Existing dataset folder is not overwritten unless `--overwrite` is passed.
  - Parquet files can be read back by DuckDB.
- **Validation**:
  - Query each Parquet file with DuckDB after writing.

### Task 4.2: Write Dataset Manifest

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Write `dataset_manifest.json`.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Manifest lists source run IDs, config IDs, row counts, output paths, schema
    version, feature columns, target columns, and excluded columns.
  - Manifest is enough for Phase 3 training to know what to load and what not
    to train on.
- **Validation**:
  - Manual review of manifest for `test_run_1`.

### Task 4.3: Write Dataset Report

- **Location**:
  - `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Produce `dataset_report.md` and `dataset_quality.json`.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Report includes join integrity, duplicate counts, null counts, feature
    ranges, target balance, and per-strategy/direction/source outcome summaries.
  - Quality JSON contains machine-readable validation status and warnings.
  - Report remains compact enough to inspect manually.
- **Validation**:
  - Compare report counts against `test_run_1` TSV counts.

## Sprint 5: Operator Workflow And Regression Guard

**Goal**: Make Phase 2 repeatable for local research runs.
**Commit**: `docs: document deterministic signal dataset builder`
**Demo/Validation**:
- A user can run one command against `test_run_1` and inspect the generated
  dataset/report.

### Task 5.1: Document Local Workflow

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `README.md`
- **Description**: Document setup, command examples, output files, and common
  validation failures.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - Instructions are Windows/MT5 Common Files friendly.
  - Documentation states that generated datasets are local artifacts.
  - Documentation states that Phase 2 does not train or infer.
- **Validation**:
  - Manual run from a clean shell using the documented command.

### Task 5.2: Add A Lightweight Self-Check Command

- **Location**:
  - `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Add `--validate-only` to run all validations without writing
  Parquet outputs.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - `--validate-only` exits nonzero on invalid source data.
  - Normal build mode writes outputs only after validation succeeds.
  - Validation output is concise and actionable.
- **Validation**:
  - Run `--validate-only` against `test_run_1`.

### Task 5.3: Record Phase 2 Acceptance Evidence

- **Location**:
  - `docs/plans/deterministic-signal-local-dataset-builder-plan.md`
  - Optional run note under `docs/research/` if a human wants preserved
    evidence.
- **Description**: Capture the accepted command and key counts from the first
  successful dataset build.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Evidence includes source run ID, dataset ID, row counts, output folder, and
    validation status.
  - No generated Parquet files are committed.
- **Validation**:
  - `git status --short` shows no generated dataset artifacts.

## Testing Strategy

- No MT5 compile is required because Phase 2 does not touch MQL5.
- No Strategy Tester run is required for implementation validation if an
  existing Phase 1 run folder is available.
- Validate with the already generated `test_run_1` folder:

```powershell
python tools/deterministic_signal_ml/build_dataset.py `
  --runs-root "C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs" `
  --run-id test_run_1 `
  --dataset-id test_dataset_1
```

- Expected first-run checks from current evidence:
  - 2821 feature rows.
  - 2821 outcome rows.
  - 2821 joined rows.
  - 0 duplicate signal IDs.
  - 0 missing joins.
  - 0 invalid Phase 1 rows.
  - TP/SL target signs remain coherent.

## Potential Risks And Gotchas

- **Feature leakage**: The training matrix can accidentally expose outcome data
  as input features. Mitigation: manifest column groups must explicitly separate
  feature, target, identity, audit, and excluded columns.
- **Mixed configs**: Combining runs from different `config_id` values can create
  noisy datasets. Mitigation: fail closed unless an explicit override is added.
- **Time leakage**: Random splits in Phase 3 can overstate performance.
  Mitigation: preserve `entry_time` and leave split policy for Phase 3.
- **Dependency sprawl**: Adding pandas, Polars, PyArrow, and DuckDB at once makes
  the first local tool heavier than needed. Mitigation: start with DuckDB only.
- **Generated data churn**: Parquet files can become large and should not be
  committed. Mitigation: default output root is ignored.
- **Locale issues**: Windows shell locale can format decimals differently, but
  TSV data uses dot-decimal strings from MQL5. Mitigation: parse explicitly and
  validate numeric casts.
- **Manual run ID reuse**: A repeated Phase 1 run ID overwrites Phase 1 TSVs by
  design. Mitigation: Phase 2 records source folder timestamps and manifest
  values in the dataset manifest.

## Open Questions With Recommendations

1. **Output location**
   - **Recommendation**: use repo-local `artifacts/datasets/<dataset_id>/` and
     add it to `.gitignore`.
   - **Alternative**: write datasets beside MT5 Common Files outputs.

2. **Multi-run policy**
   - **Recommendation**: support multiple run IDs, but fail by default if more
     than one `config_id` is present.
   - **Alternative**: allow mixed configs immediately for exploratory analysis.

3. **Dependency scope**
   - **Recommendation**: use only Python plus DuckDB in Phase 2.
   - **Alternative**: add Polars/PyArrow now for richer dataframe workflows.

## Rollback Plan

- Delete `tools/deterministic_signal_ml/` if the local builder direction changes.
- Remove generated `artifacts/datasets/` output.
- Revert `.gitignore` entries added for Phase 2 artifacts.
- No EA rollback is needed because Phase 2 should not modify MQL5 runtime code.
